import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:url_launcher/url_launcher.dart';

import '../application/reader_content_session.dart';

class ReaderAudioViewModel {
  const ReaderAudioViewModel({
    required this.contentSession,
  });

  final ReaderContentSession contentSession;
}

class ReaderAudioView extends StatefulWidget {
  const ReaderAudioView({super.key, required this.model});

  final ReaderAudioViewModel model;

  @override
  State<ReaderAudioView> createState() => _ReaderAudioViewState();
}

class _ReaderAudioViewState extends State<ReaderAudioView> {
  late final AudioPlayer _player;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Object>? _errorSubscription;

  bool _isPreparing = true;
  bool _isReady = false;
  bool _isPlaying = false;
  bool _hasCompleted = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  String? _errorText;
  String? _preparedUrl;

  ReaderContentSession get _session => widget.model.contentSession;

  String get _title =>
      (_session.chapterTitle?.trim().isNotEmpty ?? false)
          ? _session.chapterTitle!.trim()
          : _session.bookTitle;

  String? get _audioUrl {
    final preferred = _session.audioUrl?.trim();
    if (preferred != null && preferred.isNotEmpty) {
      return preferred;
    }
    final manifest = _session.audioManifestUrl?.trim();
    if (manifest != null && manifest.isNotEmpty) {
      return manifest;
    }
    return null;
  }

  bool get _isManifest =>
      (_session.audioManifestUrl?.trim().isNotEmpty ?? false) &&
      _session.audioManifestUrl?.trim() == _audioUrl;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _bindPlayerStreams();
    unawaited(_prepareAudio());
  }

  @override
  void didUpdateWidget(covariant ReaderAudioView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previousUrl = _normalizedAudioUrl(oldWidget.model.contentSession);
    final nextUrl = _normalizedAudioUrl(widget.model.contentSession);
    final previousHeaders = oldWidget.model.contentSession.audioHeaders;
    final nextHeaders = widget.model.contentSession.audioHeaders;
    if (previousUrl != nextUrl || !_sameHeaders(previousHeaders, nextHeaders)) {
      unawaited(_prepareAudio());
    }
  }

  @override
  void dispose() {
    unawaited(_playerStateSubscription?.cancel());
    unawaited(_durationSubscription?.cancel());
    unawaited(_positionSubscription?.cancel());
    unawaited(_errorSubscription?.cancel());
    unawaited(_player.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final url = _audioUrl;
    final durationMs = _duration.inMilliseconds;
    final positionMs = _position.inMilliseconds.clamp(
      0,
      durationMs <= 0 ? 0 : durationMs,
    );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.78,
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '听书模式',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(_title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    _session.bookTitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildStatusChip(theme),
                  const SizedBox(height: 16),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 8,
                      ),
                    ),
                    child: Slider(
                      value: positionMs.toDouble(),
                      max: durationMs <= 0 ? 1 : durationMs.toDouble(),
                      onChanged:
                          _isReady
                              ? (value) => setState(() {
                                _position = Duration(
                                  milliseconds: value.round(),
                                );
                              })
                              : null,
                      onChangeEnd:
                          _isReady
                              ? (value) => _seek(
                                Duration(milliseconds: value.round()),
                              )
                              : null,
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(_position),
                        style: theme.textTheme.bodySmall,
                      ),
                      Text(
                        _formatDuration(_duration),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      FilledButton.icon(
                        onPressed:
                            (_isReady || _hasCompleted) ? _togglePlayback : null,
                        icon: Icon(
                          _isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                        ),
                        label: Text(_isPlaying ? '暂停' : '播放'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _isReady ? _restart : null,
                        icon: const Icon(Icons.replay_rounded),
                        label: const Text('重播'),
                      ),
                      OutlinedButton.icon(
                        onPressed:
                            url == null ? null : () => _openExternal(context, url),
                        icon: const Icon(Icons.open_in_new_rounded),
                        label: const Text('外部打开'),
                      ),
                      OutlinedButton.icon(
                        onPressed:
                            url == null ? null : () => _copyToClipboard(context, url),
                        icon: const Icon(Icons.copy_rounded),
                        label: const Text('复制地址'),
                      ),
                    ],
                  ),
                  if (_errorText != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _errorText!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                  if (url != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _isManifest ? 'Manifest URL' : 'Audio URL',
                      style: theme.textTheme.labelLarge,
                    ),
                    const SizedBox(height: 6),
                    SelectableText(url, style: theme.textTheme.bodySmall),
                  ],
                  if (_session.audioHeaders.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text('请求头', style: theme.textTheme.labelLarge),
                    const SizedBox(height: 6),
                    SelectableText(
                      _session.audioHeaders.entries
                          .map((entry) => '${entry.key}: ${entry.value}')
                          .join('\n'),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(ThemeData theme) {
    final (label, color) = switch ((_errorText, _isPreparing, _isPlaying, _hasCompleted)) {
      (String _, _, _, _) => ('播放失败', theme.colorScheme.error),
      (_, true, _, _) => ('准备中', theme.colorScheme.tertiary),
      (_, _, true, _) => ('播放中', theme.colorScheme.primary),
      (_, _, _, true) => ('已播放完成', theme.colorScheme.secondary),
      _ => ('已暂停', theme.colorScheme.outline),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  void _bindPlayerStreams() {
    _playerStateSubscription = _player.playerStateStream.listen((state) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isPlaying = state.playing;
        _hasCompleted = state.processingState == ProcessingState.completed;
        _isPreparing = state.processingState == ProcessingState.loading ||
            state.processingState == ProcessingState.buffering;
      });
    });

    _durationSubscription = _player.durationStream.listen((duration) {
      if (!mounted || duration == null) {
        return;
      }
      setState(() {
        _duration = duration;
      });
    });

    _positionSubscription = _player.positionStream.listen((position) {
      if (!mounted) {
        return;
      }
      setState(() {
        _position = position;
      });
    });

    _errorSubscription = _player.errorStream.listen((error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = '播放器初始化失败: $error';
        _isReady = false;
        _isPreparing = false;
      });
    });
  }

  Future<void> _prepareAudio() async {
    final url = _audioUrl;
    if (!mounted) {
      return;
    }

    setState(() {
      _isPreparing = true;
      _isReady = false;
      _errorText = null;
      _hasCompleted = false;
      _position = Duration.zero;
      _duration = Duration.zero;
    });

    await _player.stop();

    if (url == null) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isPreparing = false;
        _errorText = '当前章节未提供可播放的音频地址。';
      });
      return;
    }

    final headers = _session.audioHeaders;
    try {
      final uri = Uri.parse(url);
      await _player.setUrl(
        uri.toString(),
        headers: headers.isEmpty ? null : headers,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _preparedUrl = url;
        _isReady = true;
        _isPreparing = false;
        _errorText = null;
        _duration = _player.duration ?? Duration.zero;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = '音频加载失败: $error';
        _isReady = false;
        _isPreparing = false;
      });
    }
  }

  Future<void> _togglePlayback() async {
    if (!_isReady && !_hasCompleted) {
      return;
    }
    if (_hasCompleted) {
      await _restart();
      return;
    }
    if (_isPlaying) {
      await _player.pause();
      return;
    }
    await _player.play();
  }

  Future<void> _restart() async {
    if (!_isReady && _preparedUrl == null) {
      return;
    }
    await _player.seek(Duration.zero);
    await _player.play();
  }

  Future<void> _seek(Duration position) async {
    if (!_isReady) {
      return;
    }
    await _player.seek(position);
  }

  Future<void> _openExternal(BuildContext context, String rawUrl) async {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null) {
      _showSnackBar(context, '音频地址无效');
      return;
    }
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      _showSnackBar(context, '外部打开失败');
    }
  }

  Future<void> _copyToClipboard(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      _showSnackBar(context, '已复制音频地址');
    }
  }

  void _showSnackBar(BuildContext context, String text) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(text)));
  }

  String? _normalizedAudioUrl(ReaderContentSession session) {
    final preferred = session.audioUrl?.trim();
    if (preferred != null && preferred.isNotEmpty) {
      return preferred;
    }
    final manifest = session.audioManifestUrl?.trim();
    if (manifest != null && manifest.isNotEmpty) {
      return manifest;
    }
    return null;
  }

  bool _sameHeaders(Map<String, String> left, Map<String, String> right) {
    if (identical(left, right)) {
      return true;
    }
    if (left.length != right.length) {
      return false;
    }
    for (final entry in left.entries) {
      if (right[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }

  String _formatDuration(Duration value) {
    final totalSeconds = value.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

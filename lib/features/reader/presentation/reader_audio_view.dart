import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../application/audio_reading_mode.dart';
import '../application/reader_audio_controller.dart';
import '../application/reader_content_session.dart';

class ReaderAudioViewModel {
  const ReaderAudioViewModel({
    required this.controller,
    required this.contentSession,
    this.initialPosition,
    this.initialSpeed = 1.0,
    this.autoPlay = false,
    this.seekStepSeconds = 15,
    this.canGoPreviousChapter = false,
    this.canGoNextChapter = false,
    this.onPreviousChapter,
    this.onNextChapter,
  });

  final ReaderAudioControllerHandle controller;
  final ReaderContentSession contentSession;
  final Duration? initialPosition;
  final double initialSpeed;
  final bool autoPlay;
  final int seekStepSeconds;
  final bool canGoPreviousChapter;
  final bool canGoNextChapter;
  final Future<bool> Function()? onPreviousChapter;
  final Future<bool> Function()? onNextChapter;
}

class ReaderAudioView extends StatefulWidget {
  const ReaderAudioView({super.key, required this.model});

  final ReaderAudioViewModel model;

  @override
  State<ReaderAudioView> createState() => _ReaderAudioViewState();
}

class _ReaderAudioViewState extends State<ReaderAudioView> {
  ReaderAudioControllerHandle get _controller => widget.model.controller;

  @override
  void initState() {
    super.initState();
    _configureController();
  }

  @override
  void didUpdateWidget(covariant ReaderAudioView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.model.contentSession != widget.model.contentSession ||
        oldWidget.model.initialPosition != widget.model.initialPosition ||
        oldWidget.model.controller != widget.model.controller) {
      _configureController();
    }
  }

  void _configureController() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.configure(
        session: widget.model.contentSession,
        initialPosition: widget.model.initialPosition,
        initialSpeed: widget.model.initialSpeed,
        autoPlay: widget.model.autoPlay,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final theme = Theme.of(context);
        final state = _controller.state;
        final session = state.session ?? widget.model.contentSession;
        final playback = state.playbackState;
        final audioUrl = state.audioUrl;
        final totalDuration = playback.totalDuration ?? Duration.zero;
        final totalMs = totalDuration.inMilliseconds;
        final positionMs = playback.currentPosition.inMilliseconds.clamp(
          0,
          totalMs <= 0 ? 0 : totalMs,
        );
        final chapterTitle =
            (session.chapterTitle?.trim().isNotEmpty ?? false)
                ? session.chapterTitle!.trim()
                : session.bookTitle;
        final chapterIndex =
            session.chapterIndex == null ? null : session.chapterIndex! + 1;

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
              child: Card(
                elevation: 0,
                color: theme.colorScheme.surfaceContainerHigh.withValues(
                  alpha: 0.9,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer
                                  .withValues(alpha: 0.72),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              Icons.graphic_eq_rounded,
                              color: theme.colorScheme.onPrimaryContainer,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  chapterTitle,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  chapterIndex == null
                                      ? session.bookTitle
                                      : '第 $chapterIndex 章 · ${session.bookTitle}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _buildStatusChip(theme, playback.status),
                        ],
                      ),
                      const SizedBox(height: 18),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 5,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 8,
                          ),
                        ),
                        child: Slider(
                          value: positionMs.toDouble(),
                          max: totalMs <= 0 ? 1 : totalMs.toDouble(),
                          onChanged:
                              state.isReady
                                  ? (value) async {
                                    await _controller.seekTo(
                                      Duration(milliseconds: value.round()),
                                    );
                                  }
                                  : null,
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDuration(playback.currentPosition),
                            style: theme.textTheme.bodySmall,
                          ),
                          Text(
                            _formatDuration(totalDuration),
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed:
                                  widget.model.canGoPreviousChapter
                                      ? () async {
                                        await widget.model.onPreviousChapter
                                            ?.call();
                                      }
                                      : null,
                              icon: const Icon(Icons.skip_previous_rounded),
                              label: const Text('上一章'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed:
                                  state.isReady
                                      ? () => _controller.seekRelative(
                                        Duration(
                                          seconds:
                                              -widget.model.seekStepSeconds,
                                        ),
                                      )
                                      : null,
                              icon: const Icon(Icons.replay_10_rounded),
                              label: const Text('快退'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed:
                                  state.isReady ||
                                          playback.status ==
                                              AudioPlaybackStatus.completed
                                      ? _controller.togglePlayback
                                      : null,
                              icon: Icon(
                                playback.isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                              ),
                              label: Text(playback.isPlaying ? '暂停' : '播放'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed:
                                  state.isReady
                                      ? () => _controller.seekRelative(
                                        Duration(
                                          seconds: widget.model.seekStepSeconds,
                                        ),
                                      )
                                      : null,
                              icon: const Icon(Icons.forward_30_rounded),
                              label: const Text('快进'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed:
                                  widget.model.canGoNextChapter
                                      ? () async {
                                        await widget.model.onNextChapter
                                            ?.call();
                                      }
                                      : null,
                              icon: const Icon(Icons.skip_next_rounded),
                              label: const Text('下一章'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '倍速',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [0.75, 1.0, 1.25, 1.5, 2.0]
                            .map(
                              (speed) => ChoiceChip(
                                label: Text('${speed}x'),
                                selected:
                                    (playback.speed - speed).abs() < 0.001,
                                onSelected:
                                    state.isReady
                                        ? (_) => _controller.setSpeed(speed)
                                        : null,
                              ),
                            )
                            .toList(growable: false),
                      ),
                      if (playback.errorMessage != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.errorContainer.withValues(
                              alpha: 0.42,
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                playback.errorMessage!,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onErrorContainer,
                                ),
                              ),
                              const SizedBox(height: 10),
                              FilledButton.tonalIcon(
                                onPressed: _controller.retry,
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('重试'),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: EdgeInsets.zero,
                        title: Text(
                          '更多操作',
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        children: [
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              OutlinedButton.icon(
                                onPressed:
                                    state.isReady ? _controller.restart : null,
                                icon: const Icon(Icons.replay_rounded),
                                label: const Text('重播'),
                              ),
                              OutlinedButton.icon(
                                onPressed:
                                    audioUrl == null
                                        ? null
                                        : () =>
                                            _openExternal(context, audioUrl),
                                icon: const Icon(Icons.open_in_new_rounded),
                                label: const Text('外部打开'),
                              ),
                              OutlinedButton.icon(
                                onPressed:
                                    audioUrl == null
                                        ? null
                                        : () =>
                                            _copyToClipboard(context, audioUrl),
                                icon: const Icon(Icons.copy_rounded),
                                label: const Text('复制地址'),
                              ),
                            ],
                          ),
                          if (audioUrl != null) ...[
                            const SizedBox(height: 14),
                            Text(
                              state.isManifest ? 'Manifest URL' : 'Audio URL',
                              style: theme.textTheme.labelLarge,
                            ),
                            const SizedBox(height: 6),
                            SelectableText(
                              audioUrl,
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                          if (session.audioHeaders.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            Text('请求头', style: theme.textTheme.labelLarge),
                            const SizedBox(height: 6),
                            SelectableText(
                              session.audioHeaders.entries
                                  .map(
                                    (entry) => '${entry.key}: ${entry.value}',
                                  )
                                  .join('\n'),
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusChip(ThemeData theme, AudioPlaybackStatus status) {
    final (label, color) = switch (status) {
      AudioPlaybackStatus.error => ('播放失败', theme.colorScheme.error),
      AudioPlaybackStatus.buffering => ('准备中', theme.colorScheme.tertiary),
      AudioPlaybackStatus.playing => ('播放中', theme.colorScheme.primary),
      AudioPlaybackStatus.completed => ('已播放完成', theme.colorScheme.secondary),
      AudioPlaybackStatus.paused => ('已暂停', theme.colorScheme.outline),
      AudioPlaybackStatus.idle => ('待播放', theme.colorScheme.outline),
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
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

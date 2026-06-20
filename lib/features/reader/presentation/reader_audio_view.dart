import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/app_component_theme_tokens.dart';
import '../../../app/widgets/foundation/foundation.dart';
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
        final componentTokens = appComponentThemeTokensOf(context);
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

        return LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 420;
            final horizontalPadding = isCompact ? 14.0 : 20.0;
            final panelPadding = isCompact ? 16.0 : 20.0;

            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  20,
                  horizontalPadding,
                  28,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: AppSurface(
                    padding: EdgeInsets.zero,
                    borderRadius: BorderRadius.all(
                      Radius.circular(componentTokens.overlay.radius),
                    ),
                    borderColor: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.55,
                    ),
                    backgroundColor: theme.colorScheme.surfaceContainerHigh
                        .withValues(alpha: 0.9),
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        panelPadding,
                        panelPadding,
                        panelPadding,
                        16,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeader(
                            theme: theme,
                            session: session,
                            chapterTitle: chapterTitle,
                            chapterIndex: chapterIndex,
                            status: playback.status,
                          ),
                          const SizedBox(height: 20),
                          _buildProgress(
                            theme: theme,
                            isReady: state.isReady,
                            positionMs: positionMs.toDouble(),
                            totalMs: totalMs,
                            currentPosition: playback.currentPosition,
                            totalDuration: totalDuration,
                          ),
                          const SizedBox(height: 20),
                          _buildControlStrip(
                            theme: theme,
                            isCompact: isCompact,
                            state: state,
                            playback: playback,
                          ),
                          const SizedBox(height: 18),
                          _buildSpeedSelector(
                            theme: theme,
                            isReady: state.isReady,
                            speed: playback.speed,
                          ),
                          if (playback.errorMessage != null) ...[
                            const SizedBox(height: 16),
                            _buildErrorBanner(
                              theme: theme,
                              rawMessage: playback.errorMessage!,
                            ),
                          ],
                          const SizedBox(height: 8),
                          _buildMoreActions(
                            theme: theme,
                            state: state,
                            audioUrl: audioUrl,
                            session: session,
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
      },
    );
  }

  Widget _buildHeader({
    required ThemeData theme,
    required ReaderContentSession session,
    required String chapterTitle,
    required int? chapterIndex,
    required AudioPlaybackStatus status,
  }) {
    final componentTokens = appComponentThemeTokensOf(context);
    return Row(
      children: [
        SizedBox(
          width: 48,
          height: 48,
          child: AppSurface(
            padding: EdgeInsets.zero,
            borderRadius: BorderRadius.all(
              Radius.circular(componentTokens.selection.chipRadius),
            ),
            backgroundColor: theme.colorScheme.primaryContainer.withValues(
              alpha: 0.72,
            ),
            borderColor: theme.colorScheme.outlineVariant.withValues(
              alpha: 0.18,
            ),
            child: Center(
              child: Icon(
                Icons.graphic_eq_rounded,
                color: theme.colorScheme.onPrimaryContainer,
                size: 26,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
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
                  height: 1.18,
                ),
              ),
              const SizedBox(height: 5),
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
        const SizedBox(width: 10),
        _buildStatusChip(theme, status),
      ],
    );
  }

  Widget _buildProgress({
    required ThemeData theme,
    required bool isReady,
    required double positionMs,
    required int totalMs,
    required Duration currentPosition,
    required Duration totalDuration,
  }) {
    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
          ),
          child: Slider(
            value: positionMs,
            max: totalMs <= 0 ? 1 : totalMs.toDouble(),
            onChanged:
                isReady
                    ? (value) async {
                      await _controller.seekTo(
                        Duration(milliseconds: value.round()),
                      );
                    }
                    : null,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(currentPosition),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                _formatDuration(totalDuration),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildControlStrip({
    required ThemeData theme,
    required bool isCompact,
    required ReaderAudioControllerState state,
    required AudioPlaybackState playback,
  }) {
    final smallSize = isCompact ? 42.0 : 46.0;
    final playSize = isCompact ? 58.0 : 64.0;
    final canToggle =
        state.isReady || playback.status == AudioPlaybackStatus.completed;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildRoundAction(
              theme: theme,
              tooltip: '上一章',
              icon: Icons.skip_previous_rounded,
              size: smallSize,
              onPressed:
                  widget.model.canGoPreviousChapter
                      ? () async {
                        await widget.model.onPreviousChapter?.call();
                      }
                      : null,
            ),
            _buildRoundAction(
              theme: theme,
              tooltip: '快退 ${widget.model.seekStepSeconds} 秒',
              icon: Icons.replay_10_rounded,
              size: smallSize,
              onPressed:
                  state.isReady
                      ? () => _controller.seekRelative(
                        Duration(seconds: -widget.model.seekStepSeconds),
                      )
                      : null,
            ),
            _buildRoundAction(
              theme: theme,
              tooltip: playback.isPlaying ? '暂停' : '播放',
              icon:
                  playback.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
              size: playSize,
              iconSize: isCompact ? 34 : 38,
              emphasized: true,
              onPressed: canToggle ? _controller.togglePlayback : null,
            ),
            _buildRoundAction(
              theme: theme,
              tooltip: '快进 ${widget.model.seekStepSeconds} 秒',
              icon: Icons.forward_30_rounded,
              size: smallSize,
              onPressed:
                  state.isReady
                      ? () => _controller.seekRelative(
                        Duration(seconds: widget.model.seekStepSeconds),
                      )
                      : null,
            ),
            _buildRoundAction(
              theme: theme,
              tooltip: '下一章',
              icon: Icons.skip_next_rounded,
              size: smallSize,
              onPressed:
                  widget.model.canGoNextChapter
                      ? () async {
                        await widget.model.onNextChapter?.call();
                      }
                      : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoundAction({
    required ThemeData theme,
    required String tooltip,
    required IconData icon,
    required double size,
    required VoidCallback? onPressed,
    bool emphasized = false,
    double? iconSize,
  }) {
    final componentTokens = appComponentThemeTokensOf(context);
    final controlRadius = BorderRadius.all(
      Radius.circular(componentTokens.selection.chipRadius),
    );
    final button =
        emphasized
            ? IconButton.filled(
              onPressed: onPressed,
              tooltip: tooltip,
              icon: Icon(icon, size: iconSize),
              style: IconButton.styleFrom(
                fixedSize: Size.square(size),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: controlRadius),
              ),
            )
            : IconButton.outlined(
              onPressed: onPressed,
              tooltip: tooltip,
              icon: Icon(icon, size: iconSize),
              style: IconButton.styleFrom(
                fixedSize: Size.square(size),
                padding: EdgeInsets.zero,
                foregroundColor: theme.colorScheme.onSurface,
                disabledForegroundColor: theme.colorScheme.onSurface.withValues(
                  alpha: 0.34,
                ),
                side: BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.75,
                  ),
                ),
                shape: RoundedRectangleBorder(borderRadius: controlRadius),
              ),
            );

    return Semantics(
      button: true,
      label: tooltip,
      enabled: onPressed != null,
      child: SizedBox.square(dimension: size, child: button),
    );
  }

  Widget _buildSpeedSelector({
    required ThemeData theme,
    required bool isReady,
    required double speed,
  }) {
    final componentTokens = appComponentThemeTokensOf(context);
    final chipRadius = BorderRadius.all(
      Radius.circular(componentTokens.selection.chipRadius),
    );
    const speeds = [0.75, 1.0, 1.25, 1.5, 2.0];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '倍速',
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: speeds
              .map((item) {
                final selected = (speed - item).abs() < 0.001;
                return ChoiceChip(
                  label: Text(_formatSpeed(item)),
                  selected: selected,
                  showCheckmark: false,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(borderRadius: chipRadius),
                  onSelected:
                      isReady ? (_) => _controller.setSpeed(item) : null,
                );
              })
              .toList(growable: false),
        ),
      ],
    );
  }

  Widget _buildErrorBanner({
    required ThemeData theme,
    required String rawMessage,
  }) {
    final componentTokens = appComponentThemeTokensOf(context);
    return SizedBox(
      width: double.infinity,
      child: AppSurface(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        borderRadius: BorderRadius.all(
          Radius.circular(componentTokens.selection.chipRadius),
        ),
        backgroundColor: theme.colorScheme.errorContainer.withValues(
          alpha: 0.42,
        ),
        borderColor: theme.colorScheme.error.withValues(alpha: 0.18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  color: theme.colorScheme.error,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '播放失败',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _friendlyAudioError(rawMessage),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: _controller.retry,
                  tooltip: '重试',
                  icon: const Icon(Icons.refresh_rounded),
                  style: IconButton.styleFrom(
                    fixedSize: const Size.square(36),
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(
                        Radius.circular(componentTokens.selection.chipRadius),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Divider(
              height: 1,
              color: theme.colorScheme.error.withValues(alpha: 0.14),
            ),
            const SizedBox(height: 8),
            Text(
              '错误详情',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onErrorContainer.withValues(
                  alpha: 0.72,
                ),
              ),
            ),
            const SizedBox(height: 4),
            SelectableText(
              rawMessage,
              maxLines: 3,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onErrorContainer.withValues(
                  alpha: 0.84,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoreActions({
    required ThemeData theme,
    required ReaderAudioControllerState state,
    required String? audioUrl,
    required ReaderContentSession session,
  }) {
    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        title: Text(
          '更多操作',
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        children: [
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: state.isReady ? _controller.restart : null,
                icon: const Icon(Icons.replay_rounded),
                label: const Text('重播'),
              ),
              OutlinedButton.icon(
                onPressed:
                    audioUrl == null
                        ? null
                        : () => _openExternal(context, audioUrl),
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('外部打开'),
              ),
              OutlinedButton.icon(
                onPressed:
                    audioUrl == null
                        ? null
                        : () => _copyToClipboard(context, audioUrl),
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
            SelectableText(audioUrl, style: theme.textTheme.bodySmall),
          ],
          if (session.audioHeaders.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text('请求头', style: theme.textTheme.labelLarge),
            const SizedBox(height: 6),
            SelectableText(
              session.audioHeaders.entries
                  .map((entry) => '${entry.key}: ${entry.value}')
                  .join('\n'),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusChip(ThemeData theme, AudioPlaybackStatus status) {
    final componentTokens = appComponentThemeTokensOf(context);
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
        borderRadius: BorderRadius.all(
          Radius.circular(componentTokens.selection.chipRadius),
        ),
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

  String _friendlyAudioError(String message) {
    final lower = message.toLowerCase();
    if (message.contains('-11850') || lower.contains('operation stopped')) {
      return '播放器停止了本次加载，可能是音频地址、格式或网络中断导致。请重试，仍失败时可复制详情反馈。';
    }
    if (message.contains('未提供')) {
      return message;
    }
    return '音频加载失败，请重试或换源。详细异常已保留，方便反馈排查。';
  }

  String _formatSpeed(double value) {
    if (value == value.roundToDouble()) {
      return '${value.toStringAsFixed(0)}x';
    }
    return '${value}x';
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
    AppFeedback.showSnackBar(context, message: text);
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

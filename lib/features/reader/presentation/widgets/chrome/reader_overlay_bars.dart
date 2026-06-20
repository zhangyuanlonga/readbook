import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../../../../app/motion/app_motion.dart';
import '../../../../../app/widgets/foundation/foundation.dart';
import '../../reader_chrome_action_presenter.dart';
import '../../reader_page_support_models.dart';

typedef ReaderOverlayTransitionBuilder = Widget Function(Widget child);
typedef ReaderToolbarActionCallback =
    Future<void> Function(BuildContext context);

const double _readerChromeBarBlurSigma = 8;
const double _readerChromeFloatingBlurSigma = 8;

class ReaderTopOverlayBar extends StatelessWidget {
  const ReaderTopOverlayBar({
    super.key,
    required this.colors,
    required this.overlayVisible,
    required this.animation,
    required this.fadeProgress,
    required this.transitionBuilder,
    required this.chapterTitle,
    required this.chapterLine,
    required this.useDesktopChrome,
    required this.autoReadAction,
    required this.dayNightAction,
    required this.onBack,
    required this.onCatalog,
    required this.onAutoRead,
    required this.onToggleDayNight,
    required this.onInterfaceSettings,
    required this.onOpenDetail,
    required this.onMore,
    required this.onActionPointerDown,
  });

  final ReaderThemeColors colors;
  final bool overlayVisible;
  final Animation<double> animation;
  final double fadeProgress;
  final ReaderOverlayTransitionBuilder transitionBuilder;
  final String chapterTitle;
  final String chapterLine;
  final bool useDesktopChrome;
  final ReaderChromeActionData autoReadAction;
  final ReaderChromeActionData dayNightAction;
  final VoidCallback onBack;
  final VoidCallback onCatalog;
  final VoidCallback onAutoRead;
  final VoidCallback onToggleDayNight;
  final VoidCallback onInterfaceSettings;
  final VoidCallback onOpenDetail;
  final VoidCallback onMore;
  final VoidCallback onActionPointerDown;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: IgnorePointer(
        ignoring: !overlayVisible,
        child: AnimatedBuilder(
          animation: animation,
          builder: (context, _) {
            return transitionBuilder(
              ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: _readerChromeBarBlurSigma,
                    sigmaY: _readerChromeBarBlurSigma,
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          colors.overlay.withValues(alpha: 0.94),
                          colors.overlay.withValues(alpha: 0.84),
                        ],
                      ),
                      border: Border(
                        bottom: BorderSide(
                          color: colors.divider.withValues(alpha: 0.22),
                        ),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: 0.05 * fadeProgress,
                          ),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      bottom: false,
                      child: SizedBox(
                        height: 78,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(6, 6, 10, 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              ReaderTopChromeActionButton(
                                icon: Icons.arrow_back_ios_new,
                                tooltip: '返回',
                                onPressed: onBack,
                                colors: colors,
                                emphasizeHitArea: true,
                                onPointerDown: onActionPointerDown,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: _ReaderTopTitleBlock(
                                  colors: colors,
                                  title: chapterTitle,
                                  subtitle: chapterLine,
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (useDesktopChrome) ...[
                                ReaderTopChromeActionButton(
                                  icon: Icons.list_alt_outlined,
                                  tooltip: '目录',
                                  onPressed: onCatalog,
                                  colors: colors,
                                  emphasizeHitArea: true,
                                  onPointerDown: onActionPointerDown,
                                ),
                                const SizedBox(width: 2),
                                ReaderTopChromeActionButton(
                                  icon: autoReadAction.icon,
                                  tooltip: autoReadAction.tooltip,
                                  onPressed: onAutoRead,
                                  colors: colors,
                                  emphasizeHitArea: true,
                                  onPointerDown: onActionPointerDown,
                                ),
                                const SizedBox(width: 2),
                                ReaderTopChromeActionButton(
                                  icon: dayNightAction.icon,
                                  tooltip: dayNightAction.tooltip,
                                  onPressed: onToggleDayNight,
                                  colors: colors,
                                  emphasizeHitArea: true,
                                  onPointerDown: onActionPointerDown,
                                ),
                                const SizedBox(width: 2),
                                ReaderTopChromeActionButton(
                                  icon: Icons.palette_outlined,
                                  tooltip: '界面设置',
                                  onPressed: onInterfaceSettings,
                                  colors: colors,
                                  emphasizeHitArea: true,
                                  onPointerDown: onActionPointerDown,
                                ),
                                const SizedBox(width: 8),
                              ],
                              ReaderTopChromeActionButton(
                                icon: Icons.auto_stories_rounded,
                                tooltip: '书籍详情',
                                onPressed: onOpenDetail,
                                colors: colors,
                                emphasizeHitArea: true,
                                onPointerDown: onActionPointerDown,
                              ),
                              const SizedBox(width: 2),
                              ReaderTopChromeActionButton(
                                icon: Icons.more_vert_rounded,
                                tooltip: '更多',
                                onPressed: onMore,
                                colors: colors,
                                emphasizeHitArea: true,
                                onPointerDown: onActionPointerDown,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class ReaderMobileBottomOverlayBar extends StatelessWidget {
  const ReaderMobileBottomOverlayBar({
    super.key,
    required this.colors,
    required this.overlayVisible,
    required this.animation,
    required this.fadeProgress,
    required this.transitionBuilder,
    required this.progressStrip,
    required this.autoReadAction,
    required this.dayNightAction,
    required this.interfaceAction,
    required this.onCatalog,
    required this.onAutoRead,
    required this.onAutoReadLongPress,
    required this.onToggleDayNight,
    required this.onInterfaceSettings,
    required this.onActionPointerDown,
    required this.onActionError,
  });

  final ReaderThemeColors colors;
  final bool overlayVisible;
  final Animation<double> animation;
  final double fadeProgress;
  final ReaderOverlayTransitionBuilder transitionBuilder;
  final Widget progressStrip;
  final ReaderChromeActionData autoReadAction;
  final ReaderChromeActionData dayNightAction;
  final ReaderChromeActionData interfaceAction;
  final ReaderToolbarActionCallback onCatalog;
  final ReaderToolbarActionCallback onAutoRead;
  final Future<void> Function()? onAutoReadLongPress;
  final ReaderToolbarActionCallback onToggleDayNight;
  final ReaderToolbarActionCallback onInterfaceSettings;
  final VoidCallback onActionPointerDown;
  final VoidCallback onActionError;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: IgnorePointer(
        ignoring: !overlayVisible,
        child: AnimatedBuilder(
          animation: animation,
          builder: (context, _) {
            return transitionBuilder(
              ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: _readerChromeBarBlurSigma,
                    sigmaY: _readerChromeBarBlurSigma,
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          colors.overlay.withValues(alpha: 0.84),
                          colors.overlay.withValues(alpha: 0.94),
                        ],
                      ),
                      border: Border(
                        top: BorderSide(
                          color: colors.divider.withValues(alpha: 0.22),
                        ),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: 0.06 * fadeProgress,
                          ),
                          blurRadius: 14,
                          offset: const Offset(0, -5),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            progressStrip,
                            const SizedBox(height: 3),
                            Container(
                              height: 1,
                              color: colors.divider.withValues(alpha: 0.18),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Expanded(
                                  child: ReaderBottomToolbarActionButton(
                                    icon: Icons.list_alt_outlined,
                                    label: '目录',
                                    onTap: onCatalog,
                                    colors: colors,
                                    onPointerDown: onActionPointerDown,
                                    onActionError: onActionError,
                                  ),
                                ),
                                Expanded(
                                  child: ReaderBottomToolbarActionButton(
                                    icon: autoReadAction.icon,
                                    label: autoReadAction.label,
                                    onTap: onAutoRead,
                                    onLongPress: onAutoReadLongPress,
                                    colors: colors,
                                    active: autoReadAction.active,
                                    onPointerDown: onActionPointerDown,
                                    onActionError: onActionError,
                                  ),
                                ),
                                Expanded(
                                  child: ReaderBottomToolbarActionButton(
                                    icon: dayNightAction.icon,
                                    label: dayNightAction.label,
                                    onTap: onToggleDayNight,
                                    colors: colors,
                                    active: dayNightAction.active,
                                    onPointerDown: onActionPointerDown,
                                    onActionError: onActionError,
                                  ),
                                ),
                                Expanded(
                                  child: ReaderBottomToolbarActionButton(
                                    icon: interfaceAction.icon,
                                    label: interfaceAction.label,
                                    onTap: onInterfaceSettings,
                                    colors: colors,
                                    onPointerDown: onActionPointerDown,
                                    onActionError: onActionError,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class ReaderDesktopBottomProgressOverlay extends StatelessWidget {
  const ReaderDesktopBottomProgressOverlay({
    super.key,
    required this.colors,
    required this.overlayVisible,
    required this.animation,
    required this.fadeProgress,
    required this.transitionBuilder,
    required this.progressStrip,
    required this.maxWidth,
    required this.bottomPadding,
  });

  final ReaderThemeColors colors;
  final bool overlayVisible;
  final Animation<double> animation;
  final double fadeProgress;
  final ReaderOverlayTransitionBuilder transitionBuilder;
  final Widget progressStrip;
  final double maxWidth;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: IgnorePointer(
        ignoring: !overlayVisible,
        child: AnimatedBuilder(
          animation: animation,
          builder: (context, _) {
            return transitionBuilder(
              SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(24, 0, 24, bottomPadding),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxWidth),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(
                            sigmaX: _readerChromeFloatingBlurSigma,
                            sigmaY: _readerChromeFloatingBlurSigma,
                          ),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: colors.overlay.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: colors.divider.withValues(alpha: 0.22),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(
                                    alpha: 0.08 * fadeProgress,
                                  ),
                                  blurRadius: 18,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              child: progressStrip,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class ReaderAutoReadStatusOverlay extends StatelessWidget {
  const ReaderAutoReadStatusOverlay({
    super.key,
    required this.colors,
    required this.visible,
    required this.isPaused,
    required this.isChapterPaused,
    required this.progress,
    required this.topPadding,
    required this.onResume,
    required this.onOpenSettings,
    required this.onContinueChapter,
  });

  final ReaderThemeColors colors;
  final bool visible;
  final bool isPaused;
  final bool isChapterPaused;
  final double progress;
  final double topPadding;
  final VoidCallback onResume;
  final VoidCallback onOpenSettings;
  final VoidCallback onContinueChapter;

  @override
  Widget build(BuildContext context) {
    if (!visible) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;
    final indicatorOpacity = isPaused ? 0.42 : 0.86;

    return IgnorePointer(
      ignoring: !isChapterPaused,
      child: Stack(
        children: [
          Positioned(
            top: topPadding + 8,
            left: 24,
            right: 24,
            child: AnimatedOpacity(
              duration: AppMotion.fast,
              opacity: indicatorOpacity,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: AppProgressIndicator(
                  linear: true,
                  minHeight: 3,
                  value: progress,
                  backgroundColor: colors.divider.withValues(alpha: 0.28),
                  color: colorScheme.primary,
                  semanticLabel: '自动阅读进度',
                ),
              ),
            ),
          ),
          if (isPaused && !isChapterPaused)
            Center(
              child: GestureDetector(
                onTap: onResume,
                onLongPress: onOpenSettings,
                child: ReaderAutoReadFloatingHint(
                  colors: colors,
                  icon: Icons.play_arrow_rounded,
                  title: '自动阅读已暂停',
                  actionLabel: '点击继续 · 长按设置',
                ),
              ),
            ),
          if (isChapterPaused)
            Center(
              child: GestureDetector(
                onTap: onContinueChapter,
                child: ReaderAutoReadFloatingHint(
                  colors: colors,
                  icon: Icons.play_arrow_rounded,
                  title: '本章结束',
                  actionLabel: '点击继续',
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ReaderAutoReadFloatingHint extends StatelessWidget {
  const ReaderAutoReadFloatingHint({
    super.key,
    required this.colors,
    required this.icon,
    required this.title,
    required this.actionLabel,
  });

  final ReaderThemeColors colors;
  final IconData icon;
  final String title;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return AppSurface(
      tone: AppSurfaceTone.elevated,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      borderRadius: BorderRadius.circular(18),
      backgroundColor: colors.overlay.withValues(alpha: 0.88),
      borderColor: colors.divider.withValues(alpha: 0.24),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: colorScheme.primary, size: 24),
          const SizedBox(width: 10),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: textTheme.bodyMedium?.copyWith(
                  color: colors.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                actionLabel,
                style: textTheme.bodySmall?.copyWith(color: colors.meta),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ReaderBottomProgressStrip extends StatelessWidget {
  const ReaderBottomProgressStrip({
    super.key,
    required this.colors,
    required this.progressValue,
    required this.canNavigateChapters,
    required this.hasVisibleReaderContent,
    required this.onPreviousChapter,
    required this.onNextChapter,
    required this.onPointerDown,
    required this.onChangeStart,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final ReaderThemeColors colors;
  final double progressValue;
  final bool canNavigateChapters;
  final bool hasVisibleReaderContent;
  final VoidCallback onPreviousChapter;
  final VoidCallback onNextChapter;
  final VoidCallback onPointerDown;
  final ValueChanged<double> onChangeStart;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => onPointerDown(),
      child: Row(
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            splashRadius: 20,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 48, minHeight: 44),
            tooltip: '上一章',
            onPressed: canNavigateChapters ? onPreviousChapter : null,
            icon: Icon(
              Icons.skip_previous_rounded,
              color: colors.text,
              size: 21,
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                overlayShape: SliderComponentShape.noOverlay,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                activeTrackColor: colors.text,
                inactiveTrackColor: colors.divider.withValues(alpha: 0.34),
                thumbColor: colors.text,
              ),
              child: Slider(
                min: 0,
                max: 1,
                divisions: 100,
                value: progressValue,
                onChangeStart: hasVisibleReaderContent ? onChangeStart : null,
                onChanged: hasVisibleReaderContent ? onChanged : null,
                onChangeEnd: hasVisibleReaderContent ? onChangeEnd : null,
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            splashRadius: 20,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 48, minHeight: 44),
            tooltip: '下一章',
            onPressed: canNavigateChapters ? onNextChapter : null,
            icon: Icon(Icons.skip_next_rounded, color: colors.text, size: 21),
          ),
        ],
      ),
    );
  }
}

class ReaderTopMoreActionSheet extends StatelessWidget {
  const ReaderTopMoreActionSheet({super.key, required this.actions});

  final List<ReaderChromeTopMoreActionData> actions;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final action in actions)
            ListTile(
              leading: Icon(action.icon, color: colorScheme.onSurfaceVariant),
              title: Text(action.title),
              enabled: action.enabled,
              trailing:
                  action.loading
                      ? AppProgressIndicator(
                        size: 22,
                        strokeWidth: 2,
                        color: colorScheme.onSurfaceVariant,
                        semanticLabel: '${action.title}处理中',
                      )
                      : null,
              onTap:
                  action.enabled
                      ? () => Navigator.of(context).pop(action.kind)
                      : null,
            ),
        ],
      ),
    );
  }
}

class ReaderTopChromeActionButton extends StatelessWidget {
  const ReaderTopChromeActionButton({
    super.key,
    required this.tooltip,
    required this.onPressed,
    required this.icon,
    required this.colors,
    required this.onPointerDown,
    this.loading = false,
    this.emphasizeHitArea = false,
  });

  final String tooltip;
  final VoidCallback? onPressed;
  final IconData icon;
  final ReaderThemeColors colors;
  final VoidCallback onPointerDown;
  final bool loading;
  final bool emphasizeHitArea;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => onPointerDown(),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          foregroundColor: colors.text,
          backgroundColor: Colors.transparent,
          minimumSize:
              emphasizeHitArea ? const Size(44, 44) : const Size(34, 34),
          visualDensity: VisualDensity.compact,
          padding: emphasizeHitArea ? const EdgeInsets.all(4) : EdgeInsets.zero,
          tapTargetSize:
              emphasizeHitArea
                  ? MaterialTapTargetSize.padded
                  : MaterialTapTargetSize.shrinkWrap,
        ),
        icon:
            loading
                ? AppProgressIndicator(
                  size: 16,
                  strokeWidth: 2,
                  color: colors.text,
                  semanticLabel: tooltip,
                )
                : Icon(icon, size: emphasizeHitArea ? 22 : 18),
      ),
    );
  }
}

class ReaderBottomToolbarActionButton extends StatelessWidget {
  const ReaderBottomToolbarActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    required this.colors,
    required this.onPointerDown,
    required this.onActionError,
    this.onLongPress,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final ReaderToolbarActionCallback onTap;
  final ReaderThemeColors colors;
  final VoidCallback onPointerDown;
  final VoidCallback onActionError;
  final Future<void> Function()? onLongPress;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTapDown: (_) => onPointerDown(),
        onTap: () async {
          try {
            await onTap(context);
          } catch (_) {
            onActionError();
          }
        },
        onLongPress:
            onLongPress == null
                ? null
                : () async {
                  try {
                    await onLongPress!();
                  } catch (_) {
                    onActionError();
                  }
                },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color:
                active
                    ? colors.background.withValues(alpha: 0.52)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(22),
          ),
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 19, color: colors.text),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: colors.text,
                  fontSize: 11.5,
                  height: 1.05,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReaderTopTitleBlock extends StatelessWidget {
  const _ReaderTopTitleBlock({
    required this.colors,
    required this.title,
    required this.subtitle,
  });

  final ReaderThemeColors colors;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: colors.text,
            fontSize: 18,
            height: 1.05,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: colors.meta,
            fontSize: 12,
            height: 1.05,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

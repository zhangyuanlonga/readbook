import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../../app/widgets/foundation/foundation.dart';

const double _readerOverlayBlurSigma = 8;

class ReaderOverlayPaletteData {
  const ReaderOverlayPaletteData({
    required this.background,
    required this.text,
    required this.meta,
    required this.divider,
    required this.overlay,
  });

  final Color background;
  final Color text;
  final Color meta;
  final Color divider;
  final Color overlay;
}

class ReaderTopOverlayAction {
  const ReaderTopOverlayAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.loading = false,
    this.emphasizeHitArea = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool loading;
  final bool emphasizeHitArea;
}

class ReaderBottomOverlayAction {
  const ReaderBottomOverlayAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final Future<void> Function() onTap;
  final bool active;
}

class ReaderTopOverlayWidget extends StatelessWidget {
  const ReaderTopOverlayWidget({
    super.key,
    required this.visible,
    required this.fade,
    required this.palette,
    required this.chapterTitle,
    required this.progressLabel,
    required this.actions,
    required this.transitionBuilder,
  });

  final bool visible;
  final double fade;
  final ReaderOverlayPaletteData palette;
  final String chapterTitle;
  final String progressLabel;
  final List<ReaderTopOverlayAction> actions;
  final Widget Function(Widget child) transitionBuilder;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: IgnorePointer(
        ignoring: !visible,
        child: transitionBuilder(
          ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: _readerOverlayBlurSigma,
                sigmaY: _readerOverlayBlurSigma,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      palette.overlay.withValues(alpha: 0.94),
                      palette.overlay.withValues(alpha: 0.84),
                    ],
                  ),
                  border: Border(
                    bottom: BorderSide(
                      color: palette.divider.withValues(alpha: 0.22),
                    ),
                  ),
                  boxShadow: [
                    // UI-GOV-EXEMPT: box-shadow reader-overlay-depth
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05 * fade),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: SafeArea(
                  bottom: false,
                  child: SizedBox(
                    height: 68,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                      child: Row(
                        children: [
                          if (actions.isNotEmpty)
                            _ReaderOverlayIconButton(
                              action: actions.first,
                              color: palette.text,
                            ),
                          if (actions.isNotEmpty) const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  chapterTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: palette.text,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  progressLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: palette.meta,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          for (final action in actions.skip(1)) ...[
                            const SizedBox(width: 2),
                            _ReaderOverlayIconButton(
                              action: action,
                              color: palette.text,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ReaderBottomOverlayWidget extends StatelessWidget {
  const ReaderBottomOverlayWidget({
    super.key,
    required this.visible,
    required this.fade,
    required this.palette,
    required this.progressValue,
    required this.hasVisibleReaderContent,
    required this.canNavigateChapters,
    required this.onProgressChanged,
    required this.onProgressChangeEnd,
    required this.onPreviousChapter,
    required this.onNextChapter,
    required this.actions,
    required this.transitionBuilder,
  });

  final bool visible;
  final double fade;
  final ReaderOverlayPaletteData palette;
  final double progressValue;
  final bool hasVisibleReaderContent;
  final bool canNavigateChapters;
  final ValueChanged<double>? onProgressChanged;
  final ValueChanged<double>? onProgressChangeEnd;
  final VoidCallback? onPreviousChapter;
  final VoidCallback? onNextChapter;
  final List<ReaderBottomOverlayAction> actions;
  final Widget Function(Widget child) transitionBuilder;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: IgnorePointer(
        ignoring: !visible,
        child: transitionBuilder(
          ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: _readerOverlayBlurSigma,
                sigmaY: _readerOverlayBlurSigma,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      palette.overlay.withValues(alpha: 0.84),
                      palette.overlay.withValues(alpha: 0.94),
                    ],
                  ),
                  border: Border(
                    top: BorderSide(
                      color: palette.divider.withValues(alpha: 0.22),
                    ),
                  ),
                  boxShadow: [
                    // UI-GOV-EXEMPT: box-shadow reader-overlay-depth
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06 * fade),
                      blurRadius: 14,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              splashRadius: 20,
                              tooltip: '上一章',
                              onPressed:
                                  canNavigateChapters
                                      ? onPreviousChapter
                                      : null,
                              icon: Icon(
                                Icons.skip_previous_rounded,
                                color: palette.text,
                                size: 22,
                              ),
                            ),
                            Expanded(
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 3,
                                  overlayShape: SliderComponentShape.noOverlay,
                                  thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 6,
                                  ),
                                  activeTrackColor: palette.text,
                                  inactiveTrackColor: palette.divider
                                      .withValues(alpha: 0.34),
                                  thumbColor: palette.text,
                                ),
                                child: Slider(
                                  min: 0,
                                  max: 1,
                                  divisions: 100,
                                  value: progressValue,
                                  onChanged:
                                      hasVisibleReaderContent
                                          ? onProgressChanged
                                          : null,
                                  onChangeEnd:
                                      hasVisibleReaderContent
                                          ? onProgressChangeEnd
                                          : null,
                                ),
                              ),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              splashRadius: 20,
                              tooltip: '下一章',
                              onPressed:
                                  canNavigateChapters ? onNextChapter : null,
                              icon: Icon(
                                Icons.skip_next_rounded,
                                color: palette.text,
                                size: 22,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Container(
                          height: 1,
                          color: palette.divider.withValues(alpha: 0.18),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            for (final action in actions)
                              Expanded(
                                child: _ReaderOverlayToolbarAction(
                                  action: action,
                                  palette: palette,
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
        ),
      ),
    );
  }
}

class _ReaderOverlayIconButton extends StatelessWidget {
  const _ReaderOverlayIconButton({required this.action, required this.color});

  final ReaderTopOverlayAction action;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: action.tooltip,
      onPressed: action.onPressed,
      style: IconButton.styleFrom(
        foregroundColor: color,
        backgroundColor: Colors.transparent,
        minimumSize:
            action.emphasizeHitArea ? const Size(44, 44) : const Size(34, 34),
        visualDensity: VisualDensity.compact,
        padding:
            action.emphasizeHitArea ? const EdgeInsets.all(4) : EdgeInsets.zero,
        tapTargetSize:
            action.emphasizeHitArea
                ? MaterialTapTargetSize.padded
                : MaterialTapTargetSize.shrinkWrap,
      ),
      icon:
          action.loading
              ? AppProgressIndicator(
                size: 16,
                strokeWidth: 2,
                color: color,
                semanticLabel: action.tooltip,
              )
              : Icon(action.icon, size: 18),
    );
  }
}

class _ReaderOverlayToolbarAction extends StatelessWidget {
  const _ReaderOverlayToolbarAction({
    required this.action,
    required this.palette,
  });

  final ReaderBottomOverlayAction action;
  final ReaderOverlayPaletteData palette;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () async {
          await action.onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color:
                action.active
                    ? palette.background.withValues(alpha: 0.52)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(22),
          ),
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(action.icon, size: 20, color: palette.text),
              const SizedBox(height: 3),
              Text(
                action.label,
                style: TextStyle(
                  color: palette.text,
                  fontSize: 12,
                  fontWeight: action.active ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

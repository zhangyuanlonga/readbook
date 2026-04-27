import 'dart:math';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../../../domain/entities/reader_settings.dart';
import '../application/reader_layout_resolver.dart';
import 'reader_shell.dart';

/// Public palette for reader chrome widgets.
///
/// `reader_page.dart` can map the existing private `_ReaderThemeColors`
/// 1:1 into this object without reinterpreting any values.
class ReaderChromePalette {
  const ReaderChromePalette({
    required this.background,
    required this.text,
    required this.meta,
    required this.divider,
    required this.overlay,
  });

  factory ReaderChromePalette.fromPresentationPalette(
    ReaderPresentationPalette palette,
  ) {
    return ReaderChromePalette(
      background: palette.backgroundColor,
      text: palette.primaryTextColor,
      meta: palette.secondaryTextColor,
      divider: palette.dividerColor,
      overlay: palette.chromeColor,
    );
  }

  final Color background;
  final Color text;
  final Color meta;
  final Color divider;
  final Color overlay;
}

enum ReaderInfoBarPlacement { header, footer }

enum ReaderChromeRole {
  scrollHeader,
  scrollFooter,
  pagedHeader,
  pagedFooter,
  pagedIndexOverlay,
}

enum ReaderInfoBarItemKind { text, battery }

enum ReaderInfoBarTextRole { primary, meta }

class ReaderInfoBarItemData {
  const ReaderInfoBarItemData.text(
    this.text, {
    this.role = ReaderInfoBarTextRole.meta,
    this.expand = false,
  }) : kind = ReaderInfoBarItemKind.text,
       batteryLevel = null,
       batteryReadFailed = false;

  const ReaderInfoBarItemData.battery({
    required this.batteryLevel,
    required this.batteryReadFailed,
  }) : kind = ReaderInfoBarItemKind.battery,
       text = null,
       role = ReaderInfoBarTextRole.meta,
       expand = false;

  final ReaderInfoBarItemKind kind;
  final String? text;
  final ReaderInfoBarTextRole role;
  final bool expand;
  final int? batteryLevel;
  final bool batteryReadFailed;
}

class ReaderPinnedChapterHeaderModel {
  const ReaderPinnedChapterHeaderModel({
    required this.title,
    required this.mode,
    required this.horizontalProgress,
    required this.topSafeInset,
    this.bottomSpacing = 0,
    this.topPadding = 6,
    this.height = 40,
    this.offsetY = 0,
    this.outerLeft = 6,
    this.outerRight = 12,
    this.measuredWidth,
    this.backTooltip = '返回',
  });

  final String title;
  final ReaderChapterHeaderMode mode;
  final double horizontalProgress;
  final double topSafeInset;
  final double bottomSpacing;
  final double topPadding;
  final double height;
  final double offsetY;
  final double outerLeft;
  final double outerRight;
  final double? measuredWidth;
  final String backTooltip;

  EdgeInsets get padding => EdgeInsets.only(
    top: topSafeInset + topPadding + offsetY,
    bottom: bottomSpacing,
  );
}

class ReaderPinnedChapterHeader extends StatelessWidget {
  const ReaderPinnedChapterHeader({
    super.key,
    required this.model,
    required this.palette,
    this.onBackPressed,
    this.onMeasuredWidthChanged,
    this.leading,
    this.titleTextStyle,
  });

  final ReaderPinnedChapterHeaderModel model;
  final ReaderChromePalette palette;
  final VoidCallback? onBackPressed;
  final ValueChanged<double>? onMeasuredWidthChanged;
  final Widget? leading;
  final TextStyle? titleTextStyle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: model.padding,
      child: SizedBox(
        height: model.height,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxHeaderWidth = max(
              0.0,
              constraints.maxWidth - model.outerLeft - model.outerRight,
            );
            final measuredWidth = (model.measuredWidth ?? maxHeaderWidth).clamp(
              0.0,
              maxHeaderWidth,
            );
            final maxTravel = max(0.0, maxHeaderWidth - measuredWidth);
            final left =
                model.outerLeft +
                (maxTravel * model.horizontalProgress.clamp(0.0, 1.0));

            Widget row = Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                leading ?? _buildBackButton(),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    model.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        titleTextStyle ??
                        TextStyle(
                          color: palette.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ],
            );

            if (onMeasuredWidthChanged != null) {
              row = _ReaderChromeSizeReporter(
                onSizeChanged: (size) => onMeasuredWidthChanged!(size.width),
                child: row,
              );
            }

            return Stack(
              children: <Widget>[
                Positioned(
                  left: left,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxHeaderWidth),
                    child: row,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildBackButton() {
    return IconButton(
      onPressed: onBackPressed,
      tooltip: model.backTooltip,
      visualDensity: VisualDensity.standard,
      style: IconButton.styleFrom(
        foregroundColor: palette.text,
        backgroundColor: Colors.transparent,
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.all(8),
        splashFactory: InkRipple.splashFactory,
      ),
      icon: const Icon(Icons.chevron_left_rounded, size: 22),
    );
  }
}

class ReaderInfoBarModel {
  const ReaderInfoBarModel({
    required this.leadingItems,
    required this.centerItems,
    required this.trailingItems,
    required this.placement,
    required this.role,
    required this.outerPadding,
    required this.innerHorizontalPadding,
    required this.showDivider,
    this.verticalPadding = 3,
  });

  factory ReaderInfoBarModel.fromSettings({
    required ReaderSettings settings,
    required ReaderLayoutResolver layoutResolver,
    required ReaderInfoBarPlacement placement,
    required ReaderChromeRole role,
    List<ReaderInfoBarItemData> leadingItems = const <ReaderInfoBarItemData>[],
    List<ReaderInfoBarItemData> centerItems = const <ReaderInfoBarItemData>[],
    List<ReaderInfoBarItemData> trailingItems = const <ReaderInfoBarItemData>[],
    EdgeInsets extraOuterPadding = EdgeInsets.zero,
  }) {
    final isHeader = placement == ReaderInfoBarPlacement.header;
    final rawInnerPadding =
        (isHeader ? settings.infoHeaderPadding : settings.infoFooterPadding)
            .clamp(
              ReaderSettings.minInfoBarPadding,
              ReaderSettings.maxInfoBarPadding,
            )
            .toDouble();
    final innerHorizontalPadding =
        isHeader
            ? rawInnerPadding
            : _resolveFooterHorizontalInset(rawInnerPadding);
    final verticalPadding =
        isHeader ? _resolveInfoBarVerticalPadding(innerHorizontalPadding) : 3.0;

    return ReaderInfoBarModel(
      leadingItems: leadingItems,
      centerItems: centerItems,
      trailingItems: trailingItems,
      placement: placement,
      role: role,
      outerPadding:
          layoutResolver.resolveInfoBarPadding(settings, isHeader: isHeader) +
          extraOuterPadding,
      innerHorizontalPadding: innerHorizontalPadding,
      verticalPadding: verticalPadding,
      showDivider:
          isHeader
              ? settings.infoHeaderDividerEnabled
              : settings.infoFooterDividerEnabled,
    );
  }

  final List<ReaderInfoBarItemData> leadingItems;
  final List<ReaderInfoBarItemData> centerItems;
  final List<ReaderInfoBarItemData> trailingItems;
  final ReaderInfoBarPlacement placement;
  final ReaderChromeRole role;
  final EdgeInsets outerPadding;
  final double innerHorizontalPadding;
  final bool showDivider;
  final double verticalPadding;

  bool get isHeader => placement == ReaderInfoBarPlacement.header;
  bool get hasContent =>
      leadingItems.isNotEmpty ||
      centerItems.isNotEmpty ||
      trailingItems.isNotEmpty;

  static double _resolveInfoBarVerticalPadding(double innerPadding) {
    return (innerPadding * 0.45).clamp(2.0, 12.0).toDouble();
  }

  static double _resolveFooterHorizontalInset(double innerPadding) {
    return (innerPadding * 3.2).clamp(0.0, 76.0).toDouble();
  }
}

class ReaderInfoBar extends StatelessWidget {
  const ReaderInfoBar({
    super.key,
    required this.model,
    required this.palette,
    this.itemTextStyle,
    this.separatorTextStyle,
  });

  final ReaderInfoBarModel model;
  final ReaderChromePalette palette;
  final TextStyle? itemTextStyle;
  final TextStyle? separatorTextStyle;

  @override
  Widget build(BuildContext context) {
    if (!model.hasContent) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: model.outerPadding,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            bottom:
                model.showDivider && model.isHeader
                    ? BorderSide(color: palette.divider.withValues(alpha: 0.22))
                    : BorderSide.none,
            top:
                model.showDivider && !model.isHeader
                    ? BorderSide(color: palette.divider.withValues(alpha: 0.22))
                    : BorderSide.none,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: model.innerHorizontalPadding,
            vertical: model.verticalPadding,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                flex: 4,
                child: _ReaderInfoBarSection(
                  items: model.leadingItems,
                  alignment: Alignment.centerLeft,
                  palette: palette,
                  itemTextStyle: itemTextStyle,
                  separatorTextStyle: separatorTextStyle,
                ),
              ),
              Expanded(
                flex: 3,
                child: _ReaderInfoBarSection(
                  items: model.centerItems,
                  alignment: Alignment.center,
                  palette: palette,
                  itemTextStyle: itemTextStyle,
                  separatorTextStyle: separatorTextStyle,
                ),
              ),
              Expanded(
                flex: 4,
                child: _ReaderInfoBarSection(
                  items: model.trailingItems,
                  alignment: Alignment.centerRight,
                  palette: palette,
                  itemTextStyle: itemTextStyle,
                  separatorTextStyle: separatorTextStyle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReaderInfoBarSection extends StatelessWidget {
  const _ReaderInfoBarSection({
    required this.items,
    required this.alignment,
    required this.palette,
    this.itemTextStyle,
    this.separatorTextStyle,
  });

  final List<ReaderInfoBarItemData> items;
  final Alignment alignment;
  final ReaderChromePalette palette;
  final TextStyle? itemTextStyle;
  final TextStyle? separatorTextStyle;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    final mainAxisAlignment = switch (alignment) {
      Alignment.centerLeft => MainAxisAlignment.start,
      Alignment.centerRight => MainAxisAlignment.end,
      _ => MainAxisAlignment.center,
    };

    return Align(
      alignment: alignment,
      child: Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: mainAxisAlignment,
        children: <Widget>[
          for (var index = 0; index < items.length; index += 1) ...<Widget>[
            if (index > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  '·',
                  style:
                      separatorTextStyle ??
                      TextStyle(
                        color: palette.meta.withValues(alpha: 0.8),
                        fontSize: 11,
                      ),
                ),
              ),
            Flexible(
              fit: FlexFit.loose,
              child: _ReaderInfoBarItem(
                item: items[index],
                palette: palette,
                itemTextStyle: itemTextStyle,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReaderInfoBarItem extends StatelessWidget {
  const _ReaderInfoBarItem({
    required this.item,
    required this.palette,
    this.itemTextStyle,
  });

  final ReaderInfoBarItemData item;
  final ReaderChromePalette palette;
  final TextStyle? itemTextStyle;

  @override
  Widget build(BuildContext context) {
    final child = switch (item.kind) {
      ReaderInfoBarItemKind.text => _buildTextItem(),
      ReaderInfoBarItemKind.battery => _ReaderInfoBarBattery(
        level: item.batteryLevel,
        readFailed: item.batteryReadFailed,
        palette: palette,
      ),
    };
    if (!item.expand) {
      return child;
    }
    return Flexible(child: child);
  }

  Widget _buildTextItem() {
    final baseStyle =
        itemTextStyle ??
        TextStyle(
          color:
              item.role == ReaderInfoBarTextRole.primary
                  ? palette.text
                  : palette.meta,
          fontSize: 11.5,
          fontWeight:
              item.role == ReaderInfoBarTextRole.primary
                  ? FontWeight.w500
                  : FontWeight.w400,
        );
    return Text(
      item.text ?? '',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
      style: baseStyle,
    );
  }
}

class _ReaderInfoBarBattery extends StatelessWidget {
  const _ReaderInfoBarBattery({
    required this.level,
    required this.readFailed,
    required this.palette,
  });

  final int? level;
  final bool readFailed;
  final ReaderChromePalette palette;

  @override
  Widget build(BuildContext context) {
    final icon = _batteryIcon();
    final label = readFailed ? 'N/A' : '${(level ?? 0).clamp(0, 100)}%';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: palette.meta.withValues(alpha: 0.92)),
        const SizedBox(width: 4),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: palette.meta,
            fontSize: 11.5,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  IconData _batteryIcon() {
    if (readFailed || level == null) {
      return Icons.battery_unknown_rounded;
    }
    final safeLevel = level!.clamp(0, 100);
    if (safeLevel >= 96) {
      return Icons.battery_full_rounded;
    }
    if (safeLevel >= 80) {
      return Icons.battery_6_bar_rounded;
    }
    if (safeLevel >= 60) {
      return Icons.battery_5_bar_rounded;
    }
    if (safeLevel >= 40) {
      return Icons.battery_4_bar_rounded;
    }
    if (safeLevel >= 25) {
      return Icons.battery_3_bar_rounded;
    }
    if (safeLevel >= 10) {
      return Icons.battery_2_bar_rounded;
    }
    return Icons.battery_alert_rounded;
  }
}

class ReaderPageIndexBadgeModel {
  const ReaderPageIndexBadgeModel({required this.index, required this.total});

  final int index;
  final int total;

  int get safeTotal => total <= 0 ? 1 : total;
  int get safeIndex => index.clamp(0, safeTotal - 1);
  int get current => safeIndex + 1;
  double get percent => (current / safeTotal) * 100;

  String get label => '$current/$safeTotal · ${percent.toStringAsFixed(2)}%';
}

class ReaderPageIndexOverlayModel {
  const ReaderPageIndexOverlayModel({
    required this.badge,
    required this.role,
    required this.showProgress,
    required this.rightItems,
    required this.horizontalPadding,
    required this.bottomPadding,
    required this.opacity,
  });

  factory ReaderPageIndexOverlayModel.fromSettings({
    required ReaderSettings settings,
    required ReaderLayoutResolver layoutResolver,
    required int index,
    required int total,
    required double bottomInset,
    required double safeBottomInset,
    required double fadeProgress,
    required List<String> rightItems,
  }) {
    final footerPadding = layoutResolver.resolveInfoBarPadding(
      settings,
      isHeader: false,
    );
    final innerPadding =
        settings.infoFooterPadding
            .clamp(
              ReaderSettings.minInfoBarPadding,
              ReaderSettings.maxInfoBarPadding,
            )
            .toDouble();
    final overlaySpacing = max(4.0, innerPadding * 0.5);
    final anchoredBottomPadding =
        max(bottomInset, safeBottomInset) +
        footerPadding.bottom +
        overlaySpacing;

    return ReaderPageIndexOverlayModel(
      badge: ReaderPageIndexBadgeModel(index: index, total: total),
      role: ReaderChromeRole.pagedIndexOverlay,
      showProgress: settings.infoShowProgress,
      rightItems: rightItems,
      horizontalPadding: max(
        14.0,
        max(footerPadding.left, footerPadding.right),
      ),
      bottomPadding: anchoredBottomPadding,
      opacity: lerpDouble(1.0, 0.0, fadeProgress.clamp(0.0, 1.0)) ?? 1.0,
    );
  }

  final ReaderPageIndexBadgeModel badge;
  final ReaderChromeRole role;
  final bool showProgress;
  final List<String> rightItems;
  final double horizontalPadding;
  final double bottomPadding;
  final double opacity;

  String get rightLabel =>
      rightItems.where((item) => item.isNotEmpty).join(' · ');

  bool get isVisible => opacity > 0 && (showProgress || rightLabel.isNotEmpty);
}

class ReaderPageIndexBadge extends StatelessWidget {
  const ReaderPageIndexBadge({
    super.key,
    required this.model,
    required this.palette,
    this.textStyle,
  });

  final ReaderPageIndexBadgeModel model;
  final ReaderChromePalette palette;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    return Text(
      model.label,
      style:
          textStyle ??
          TextStyle(
            color: palette.meta.withValues(alpha: 0.9),
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
          ),
    );
  }
}

class ReaderPageIndexOverlay extends StatelessWidget {
  const ReaderPageIndexOverlay({
    super.key,
    required this.model,
    required this.palette,
    this.ignorePointer = true,
    this.badgeTextStyle,
    this.trailingTextStyle,
  });

  final ReaderPageIndexOverlayModel model;
  final ReaderChromePalette palette;
  final bool ignorePointer;
  final TextStyle? badgeTextStyle;
  final TextStyle? trailingTextStyle;

  @override
  Widget build(BuildContext context) {
    if (!model.isVisible) {
      return const SizedBox.shrink();
    }

    final content = Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          model.horizontalPadding,
          0,
          model.horizontalPadding,
          model.bottomPadding,
        ),
        child: Opacity(
          opacity: model.opacity,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              if (model.showProgress)
                ReaderPageIndexBadge(
                  model: model.badge,
                  palette: palette,
                  textStyle: badgeTextStyle,
                ),
              if (model.rightLabel.isNotEmpty)
                Expanded(
                  child: Text(
                    model.rightLabel,
                    textAlign: TextAlign.right,
                    style:
                        trailingTextStyle ??
                        TextStyle(
                          color: palette.meta.withValues(alpha: 0.9),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                )
              else
                const Spacer(),
            ],
          ),
        ),
      ),
    );

    if (!ignorePointer) {
      return content;
    }
    return IgnorePointer(child: content);
  }
}

class _ReaderChromeSizeReporter extends StatefulWidget {
  const _ReaderChromeSizeReporter({
    required this.child,
    required this.onSizeChanged,
  });

  final Widget child;
  final ValueChanged<Size> onSizeChanged;

  @override
  State<_ReaderChromeSizeReporter> createState() =>
      _ReaderChromeSizeReporterState();
}

class _ReaderChromeSizeReporterState extends State<_ReaderChromeSizeReporter> {
  Size? _lastSize;

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final renderBox = context.findRenderObject();
      if (renderBox is! RenderBox || !renderBox.hasSize) {
        return;
      }
      final size = renderBox.size;
      if (_lastSize != null &&
          (_lastSize!.width - size.width).abs() < 0.5 &&
          (_lastSize!.height - size.height).abs() < 0.5) {
        return;
      }
      _lastSize = size;
      widget.onSizeChanged(size);
    });
    return widget.child;
  }
}

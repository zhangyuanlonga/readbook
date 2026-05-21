import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/layout/app_adaptive.dart';
import '../../../../app/motion/app_motion.dart';

class BookDetailPrimaryActions extends StatelessWidget {
  const BookDetailPrimaryActions({
    super.key,
    required this.availableWidth,
    required this.isInBookshelf,
    required this.isShelfStateLoading,
    required this.isShelfActionLoading,
    required this.onToggleBookshelf,
    required this.onOpenCatalog,
    required this.onSwitchSource,
    required this.onOpenOrganize,
    this.isCatalogEnabled = true,
    this.isSwitchSourceEnabled = true,
    this.isOrganizeEnabled = true,
  });

  static const double actionButtonHeight = 62;
  static const double actionButtonGap = 4;

  final double availableWidth;
  final bool isInBookshelf;
  final bool isShelfStateLoading;
  final bool isShelfActionLoading;
  final VoidCallback? onToggleBookshelf;
  final VoidCallback? onOpenCatalog;
  final VoidCallback? onSwitchSource;
  final VoidCallback? onOpenOrganize;
  final bool isCatalogEnabled;
  final bool isSwitchSourceEnabled;
  final bool isOrganizeEnabled;

  @override
  Widget build(BuildContext context) {
    final metrics = AppAdaptiveMetrics.of(context);
    final buttonHeight = metrics.isCompactDensity ? 52.0 : 58.0;
    final buttonGap = metrics.isCompactDensity ? 4.0 : 6.0;
    final iconSize = metrics.isCompactDensity ? 17.0 : 18.0;
    final useWrap = availableWidth < 260;
    final buttonTextStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      fontSize: metrics.isCompactDensity ? 11.5 : null,
      fontWeight: FontWeight.w600,
      height: 1.0,
    );

    Widget buildAction({
      required Key key,
      required Widget icon,
      required String label,
      required VoidCallback? onPressed,
      bool enabled = true,
    }) {
      final effectiveEnabled = enabled && onPressed != null;
      return SizedBox(
        height: buttonHeight,
        child: _ActionButtonSurface(
          inkKey: key,
          onTap: effectiveEnabled ? onPressed : null,
          enabled: effectiveEnabled,
          borderRadius: BorderRadius.circular(metrics.cardRadius * 0.72),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            opacity: effectiveEnabled ? 1 : 0.45,
            child: _ActionButtonContent(
              icon: icon,
              label: label,
              iconGap: metrics.isCompactDensity ? 2 : 3,
              textStyle: buttonTextStyle,
              enabled: effectiveEnabled,
            ),
          ),
        ),
      );
    }

    final showShelfProgress = isShelfActionLoading;
    final isShelfUnavailable = isShelfStateLoading || isShelfActionLoading;
    final shelfButton = buildAction(
      key: const Key('book_detail_shelf_button'),
      icon:
          showShelfProgress
              ? SizedBox(
                width: iconSize,
                height: iconSize,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              )
              : Icon(
                isInBookshelf
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                size: iconSize,
                color: Theme.of(context).colorScheme.onSurface,
              ),
      label: '书架',
      onPressed: isShelfUnavailable ? null : onToggleBookshelf,
    );
    final catalogButton = buildAction(
      key: const Key('book_detail_catalog_button'),
      icon: Icon(
        Icons.menu_book_rounded,
        size: iconSize,
        color: Theme.of(context).colorScheme.onSurface,
      ),
      label: '目录',
      onPressed: onOpenCatalog,
      enabled: isCatalogEnabled,
    );
    final sourceButton = buildAction(
      key: const Key('book_detail_source_button'),
      icon: Icon(
        Icons.swap_horiz_rounded,
        size: iconSize,
        color: Theme.of(context).colorScheme.onSurface,
      ),
      label: '书源',
      onPressed: onSwitchSource,
      enabled: isSwitchSourceEnabled,
    );
    final cacheButton = buildAction(
      key: const Key('book_detail_cache_button'),
      icon: Icon(
        Icons.bookmarks_rounded,
        size: iconSize,
        color: Theme.of(context).colorScheme.onSurface,
      ),
      label: '归类',
      onPressed: onOpenOrganize,
      enabled: isOrganizeEnabled,
    );

    if (useWrap) {
      final itemWidth = (availableWidth - buttonGap) / 2;
      return Wrap(
        spacing: buttonGap,
        runSpacing: buttonGap,
        children: [
          SizedBox(width: itemWidth, child: shelfButton),
          SizedBox(width: itemWidth, child: catalogButton),
          SizedBox(width: itemWidth, child: sourceButton),
          SizedBox(width: itemWidth, child: cacheButton),
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: shelfButton),
        SizedBox(width: buttonGap),
        Expanded(child: catalogButton),
        SizedBox(width: buttonGap),
        Expanded(child: sourceButton),
        SizedBox(width: buttonGap),
        Expanded(child: cacheButton),
      ],
    );
  }
}

class _ActionButtonSurface extends StatefulWidget {
  const _ActionButtonSurface({
    required this.inkKey,
    required this.child,
    required this.borderRadius,
    this.onTap,
    this.enabled = true,
  });

  final Key inkKey;
  final Widget child;
  final BorderRadius borderRadius;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  State<_ActionButtonSurface> createState() => _ActionButtonSurfaceState();
}

class _ActionButtonSurfaceState extends State<_ActionButtonSurface> {
  bool _pressed = false;

  bool get _enabled => widget.enabled && widget.onTap != null;

  @override
  Widget build(BuildContext context) {
    final motionEnabled = AppMotion.enabledOf(context, enabled: widget.enabled);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: widget.inkKey,
        borderRadius: widget.borderRadius,
        onTap: _enabled ? widget.onTap : null,
        onTapDown: _enabled ? (_) => HapticFeedback.lightImpact() : null,
        onHighlightChanged: (value) {
          if (_pressed == value) {
            return;
          }
          setState(() {
            _pressed = value;
          });
        },
        child: AnimatedScale(
          scale: motionEnabled && _pressed ? 0.97 : 1,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutBack,
          child: widget.child,
        ),
      ),
    );
  }
}

class _ActionButtonContent extends StatelessWidget {
  const _ActionButtonContent({
    required this.icon,
    required this.label,
    required this.iconGap,
    required this.enabled,
    this.textStyle,
  });

  final Widget icon;
  final String label;
  final double iconGap;
  final bool enabled;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final foregroundColor =
        enabled
            ? Theme.of(context).colorScheme.onSurface
            : Theme.of(context).colorScheme.onSurfaceVariant;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconTheme.merge(data: IconThemeData(color: foregroundColor), child: icon),
          SizedBox(height: iconGap),
          Text(
            label,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: textStyle?.copyWith(
              color: foregroundColor,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../motion/app_motion.dart';
import '../../theme/app_component_theme_tokens.dart';

enum AppSkeletonShape { rectangle, circle }

class AppSkeletonBlock extends StatelessWidget {
  const AppSkeletonBlock({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.borderRadius,
    this.margin,
    this.shape = AppSkeletonShape.rectangle,
    this.animate = true,
  });

  final double? width;
  final double height;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? margin;
  final AppSkeletonShape shape;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tokens = appComponentThemeTokensOf(context);
    final radius =
        borderRadius ?? BorderRadius.circular(tokens.card.radius * 0.56);
    final baseColor = colorScheme.surfaceContainerHighest;
    final highlightColor = Color.alphaBlend(
      colorScheme.onSurface.withValues(alpha: 0.06),
      baseColor,
    );
    final block = Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: baseColor,
        shape:
            shape == AppSkeletonShape.circle
                ? BoxShape.circle
                : BoxShape.rectangle,
        borderRadius: shape == AppSkeletonShape.circle ? null : radius,
      ),
    );

    if (!AppMotion.enabledOf(context, enabled: animate)) {
      return block;
    }
    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      period: const Duration(milliseconds: 1100),
      child: block,
    );
  }
}

class AppSkeletonList extends StatelessWidget {
  const AppSkeletonList({
    super.key,
    this.itemCount = 3,
    this.itemHeight = 72,
    this.spacing = 12,
    this.padding,
    this.showLeading = true,
    this.showTrailing = false,
  });

  final int itemCount;
  final double itemHeight;
  final double spacing;
  final EdgeInsetsGeometry? padding;
  final bool showLeading;
  final bool showTrailing;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var index = 0; index < itemCount; index++) {
      if (index > 0) {
        children.add(SizedBox(height: spacing));
      }
      children.add(
        _AppSkeletonListItem(
          height: itemHeight,
          showLeading: showLeading,
          showTrailing: showTrailing,
        ),
      );
    }

    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: Column(children: children),
    );
  }
}

class _AppSkeletonListItem extends StatelessWidget {
  const _AppSkeletonListItem({
    required this.height,
    required this.showLeading,
    required this.showTrailing,
  });

  final double height;
  final bool showLeading;
  final bool showTrailing;

  @override
  Widget build(BuildContext context) {
    final tokens = appComponentThemeTokensOf(context);
    return SizedBox(
      height: height,
      child: Row(
        children: [
          if (showLeading) ...[
            AppSkeletonBlock(
              width: height * 0.68,
              height: height * 0.68,
              borderRadius: BorderRadius.circular(tokens.card.radius * 0.5),
            ),
            const SizedBox(width: 12),
          ],
          const Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppSkeletonBlock(width: double.infinity, height: 14),
                SizedBox(height: 10),
                AppSkeletonBlock(width: 160, height: 12),
              ],
            ),
          ),
          if (showTrailing) ...[
            const SizedBox(width: 12),
            const AppSkeletonBlock(
              width: 28,
              height: 28,
              shape: AppSkeletonShape.circle,
            ),
          ],
        ],
      ),
    );
  }
}

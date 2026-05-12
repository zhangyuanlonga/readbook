import 'package:flutter/material.dart';

import '../layout/app_adaptive.dart';

class AdaptiveCard extends StatelessWidget {
  const AdaptiveCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.color,
    this.borderColor,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final Color? borderColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final metrics = AppAdaptiveMetrics.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(metrics.cardRadius);
    final content = Container(
      margin: margin,
      padding: padding ?? EdgeInsets.all(metrics.cardPadding),
      decoration: BoxDecoration(
        color: color ?? colorScheme.surfaceContainerLow,
        borderRadius: radius,
        border: Border.all(
          color: borderColor ?? colorScheme.outlineVariant,
          width: 0.8,
        ),
      ),
      child: child,
    );
    if (onTap == null) {
      return content;
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(borderRadius: radius, onTap: onTap, child: content),
    );
  }
}

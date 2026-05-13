import 'package:flutter/material.dart';

import '../layout/app_adaptive.dart';
import '../layout/app_size_tokens.dart';

class AdaptiveContentContainer extends StatelessWidget {
  const AdaptiveContentContainer({
    super.key,
    required this.child,
    this.maxWidth,
    this.alignment = Alignment.topCenter,
    this.padding,
  });

  final Widget child;
  final double? maxWidth;
  final AlignmentGeometry alignment;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final metrics = AppAdaptiveMetrics.of(context);
    final resolvedMaxWidth =
        maxWidth ?? AppSizeTokens.defaultContentMaxWidthForWidth(metrics.width);
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: resolvedMaxWidth),
        child: Padding(
          padding:
              padding ?? EdgeInsets.symmetric(horizontal: metrics.pagePadding),
          child: child,
        ),
      ),
    );
  }
}

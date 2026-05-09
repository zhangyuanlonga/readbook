import 'package:flutter/material.dart';

import '../layout/app_adaptive.dart';

class AdaptiveBottomSheet extends StatelessWidget {
  const AdaptiveBottomSheet({
    super.key,
    required this.child,
    this.maxWidth,
    this.padding,
  });

  final Widget child;
  final double? maxWidth;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final metrics = AppAdaptiveMetrics.of(context);
    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth ?? metrics.bottomSheetMaxWidth,
        ),
        child: Padding(
          padding:
              padding ??
              EdgeInsets.fromLTRB(
                metrics.pagePadding,
                metrics.contentGap,
                metrics.pagePadding,
                metrics.sectionGap,
              ),
          child: child,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../layout/app_adaptive.dart';
import '../layout/app_layout.dart';

class AdaptiveSplitBody extends StatelessWidget {
  const AdaptiveSplitBody({
    super.key,
    required this.primary,
    required this.secondary,
    this.primaryFlex = 3,
    this.secondaryFlex = 2,
    this.gap,
    this.breakpoint = AppLayout.expandedBreakpointWidth,
    this.stackSecondaryFirst = false,
    this.primaryMinHeight,
    this.secondaryMinHeight,
  });

  final Widget primary;
  final Widget secondary;
  final int primaryFlex;
  final int secondaryFlex;
  final double? gap;
  final double breakpoint;
  final bool stackSecondaryFirst;
  final double? primaryMinHeight;
  final double? secondaryMinHeight;

  @override
  Widget build(BuildContext context) {
    final metrics = AppAdaptiveMetrics.of(context);
    final resolvedGap = gap ?? metrics.sectionGap;
    return LayoutBuilder(
      builder: (context, constraints) {
        final useSplit = constraints.maxWidth >= breakpoint;
        if (!useSplit) {
          final children = <Widget>[
            _MinHeightBox(minHeight: primaryMinHeight, child: primary),
            SizedBox(height: resolvedGap),
            _MinHeightBox(minHeight: secondaryMinHeight, child: secondary),
          ];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children:
                stackSecondaryFirst
                    ? children.reversed.toList(growable: false)
                    : children,
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: primaryFlex,
              child: _MinHeightBox(minHeight: primaryMinHeight, child: primary),
            ),
            SizedBox(width: resolvedGap),
            Expanded(
              flex: secondaryFlex,
              child: _MinHeightBox(
                minHeight: secondaryMinHeight,
                child: secondary,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MinHeightBox extends StatelessWidget {
  const _MinHeightBox({required this.child, this.minHeight});

  final Widget child;
  final double? minHeight;

  @override
  Widget build(BuildContext context) {
    final resolvedMinHeight = minHeight;
    if (resolvedMinHeight == null) {
      return child;
    }
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: resolvedMinHeight),
      child: child,
    );
  }
}

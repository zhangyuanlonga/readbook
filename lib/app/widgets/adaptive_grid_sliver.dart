import 'package:flutter/material.dart';

import '../layout/app_adaptive.dart';

typedef AdaptiveGridItemBuilder =
    Widget Function(BuildContext context, int index);

class AdaptiveGridSliver extends StatelessWidget {
  const AdaptiveGridSliver({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.fixedCrossAxisCount,
    this.minItemWidth,
    this.minColumns = 1,
    this.maxColumns = 8,
    this.crossSpacing,
    this.mainSpacing,
    this.itemHeightExtra = 0,
    this.itemAspectRatio,
    this.childAspectRatio,
    this.contentWidthClamp = const (220, 2400),
    this.findChildIndexCallback,
  });

  final int itemCount;
  final AdaptiveGridItemBuilder itemBuilder;
  final int? fixedCrossAxisCount;
  final double? minItemWidth;
  final int minColumns;
  final int maxColumns;
  final double? crossSpacing;
  final double? mainSpacing;
  final double itemHeightExtra;
  final double? itemAspectRatio;
  final double? childAspectRatio;
  final (double, double) contentWidthClamp;
  final ChildIndexGetter? findChildIndexCallback;

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final metrics = AppAdaptiveMetrics.resolveForSliver(
          context,
          constraints,
        );
        final width =
            constraints.crossAxisExtent
                .clamp(contentWidthClamp.$1, contentWidthClamp.$2)
                .toDouble();
        final resolvedCrossSpacing = crossSpacing ?? metrics.contentGap;
        final resolvedMainSpacing = mainSpacing ?? metrics.sectionGap;
        final crossAxisCount =
            fixedCrossAxisCount?.clamp(minColumns, maxColumns) ??
            metrics.gridColumnsFor(
              availableWidth: width,
              minItemWidth: minItemWidth,
              minColumns: minColumns,
              maxColumns: maxColumns,
              spacing: resolvedCrossSpacing,
            );
        final itemWidth =
            (width - resolvedCrossSpacing * (crossAxisCount - 1)) /
            crossAxisCount;
        final resolvedItemHeight =
            itemAspectRatio == null
                ? itemWidth + itemHeightExtra
                : itemWidth / itemAspectRatio! + itemHeightExtra;
        final ratio =
            childAspectRatio ??
            itemWidth / resolvedItemHeight.clamp(1.0, 2400.0);

        return SliverGrid(
          delegate: SliverChildBuilderDelegate(
            itemBuilder,
            childCount: itemCount,
            findChildIndexCallback: findChildIndexCallback,
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: resolvedCrossSpacing,
            mainAxisSpacing: resolvedMainSpacing,
            childAspectRatio: ratio,
          ),
        );
      },
    );
  }
}

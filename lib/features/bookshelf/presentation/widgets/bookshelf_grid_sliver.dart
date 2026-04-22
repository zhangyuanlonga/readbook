import 'package:flutter/material.dart';

import '../../../../app/layout/app_layout.dart';

typedef BookshelfGridItemBuilder =
    Widget Function(BuildContext context, int index);

class BookshelfGridSliver extends StatelessWidget {
  const BookshelfGridSliver({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.fixedCrossAxisCount,
    this.crossSpacing = 8,
    this.mainSpacing = 12,
    this.itemHeightExtra = 42,
    this.coverAspectRatio = 68 / 96,
  });

  final int itemCount;
  final BookshelfGridItemBuilder itemBuilder;
  final int? fixedCrossAxisCount;
  final double crossSpacing;
  final double mainSpacing;
  final double itemHeightExtra;
  final double coverAspectRatio;

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final width =
            constraints.crossAxisExtent.clamp(220.0, 2400.0).toDouble();
        final crossAxisCount =
            fixedCrossAxisCount?.clamp(2, 6) ??
            AppLayout.bookshelfGridColumnsForWidth(width);
        final itemWidth =
            (width - crossSpacing * (crossAxisCount - 1)) / crossAxisCount;
        final itemHeight = itemWidth / coverAspectRatio + itemHeightExtra;

        return SliverGrid(
          delegate: SliverChildBuilderDelegate(
            itemBuilder,
            childCount: itemCount,
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: crossSpacing,
            mainAxisSpacing: mainSpacing,
            childAspectRatio: itemWidth / itemHeight,
          ),
        );
      },
    );
  }
}

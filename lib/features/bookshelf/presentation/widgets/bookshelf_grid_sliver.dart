import 'package:flutter/material.dart';

import '../../../../app/widgets/adaptive_grid_sliver.dart';

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
    this.findChildIndexCallback,
  });

  final int itemCount;
  final BookshelfGridItemBuilder itemBuilder;
  final int? fixedCrossAxisCount;
  final double crossSpacing;
  final double mainSpacing;
  final double itemHeightExtra;
  final double coverAspectRatio;
  final ChildIndexGetter? findChildIndexCallback;

  @override
  Widget build(BuildContext context) {
    return AdaptiveGridSliver(
      itemCount: itemCount,
      itemBuilder: itemBuilder,
      fixedCrossAxisCount: fixedCrossAxisCount,
      minColumns: 2,
      maxColumns: 6,
      crossSpacing: crossSpacing,
      mainSpacing: mainSpacing,
      itemHeightExtra: itemHeightExtra,
      itemAspectRatio: coverAspectRatio,
      findChildIndexCallback: findChildIndexCallback,
    );
  }
}

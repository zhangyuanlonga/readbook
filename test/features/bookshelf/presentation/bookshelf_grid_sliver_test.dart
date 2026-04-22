import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shuxiang_reading_next/features/bookshelf/presentation/widgets/bookshelf_grid_sliver.dart';

void main() {
  testWidgets(
    'uses constrained width instead of global screen width for columns',
    (tester) async {
      final delegate = await _pumpAndReadGridDelegate(
        tester,
        screenWidth: 1440,
        constrainedWidth: 390,
      );

      expect(delegate.crossAxisCount, 3);
    },
  );

  testWidgets('switches columns at bookshelf width thresholds', (tester) async {
    final delegate800 = await _pumpAndReadGridDelegate(
      tester,
      screenWidth: 1440,
      constrainedWidth: 810,
    );
    final delegate1100 = await _pumpAndReadGridDelegate(
      tester,
      screenWidth: 1440,
      constrainedWidth: 1120,
    );
    final delegate1400 = await _pumpAndReadGridDelegate(
      tester,
      screenWidth: 1440,
      constrainedWidth: 1420,
    );

    expect(delegate800.crossAxisCount, 4);
    expect(delegate1100.crossAxisCount, 5);
    expect(delegate1400.crossAxisCount, 6);
  });

  testWidgets('uses cover ratio plus extra height for child aspect ratio', (
    tester,
  ) async {
    final delegate = await _pumpAndReadGridDelegate(
      tester,
      screenWidth: 1440,
      constrainedWidth: 390,
      itemHeightExtra: 74,
      coverAspectRatio: 68 / 96,
    );

    const crossSpacing = 8.0;
    final itemWidth = (390 - crossSpacing * (3 - 1)) / 3;
    final expectedHeight = itemWidth / (68 / 96) + 74;

    expect(
      delegate.childAspectRatio,
      closeTo(itemWidth / expectedHeight, 1e-6),
    );
  });
}

Future<SliverGridDelegateWithFixedCrossAxisCount> _pumpAndReadGridDelegate(
  WidgetTester tester, {
  required double screenWidth,
  required double constrainedWidth,
  double itemHeightExtra = 42,
  double coverAspectRatio = 68 / 96,
}) async {
  await tester.binding.setSurfaceSize(Size(screenWidth, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: constrainedWidth,
            height: 600,
            child: CustomScrollView(
              slivers: [
                BookshelfGridSliver(
                  itemCount: 20,
                  itemHeightExtra: itemHeightExtra,
                  coverAspectRatio: coverAspectRatio,
                  itemBuilder:
                      (context, index) => Container(
                        key: ValueKey<String>('grid_item_$index'),
                        color: Colors.blueGrey,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();

  final sliverGrid = tester.widget<SliverGrid>(find.byType(SliverGrid));
  return sliverGrid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
}

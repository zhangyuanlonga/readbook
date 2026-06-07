import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/app/widgets/adaptive_overflow_toolbar.dart';
import 'package:shuxiang_reading_next/app/widgets/adaptive_route_top_bar.dart';

import '../../../test_utils/adaptive_test_harness.dart';

void main() {
  const widths = <double>[520, 600, 840, 1200, 1600];

  for (final width in widths) {
    testWidgets('search route top bar survives desktop drag width $width', (
      tester,
    ) async {
      await tester.pumpWidget(
        AdaptiveTestHarness(
          width: width,
          height: 900,
          wrapWithMaterialApp: true,
          child: Scaffold(
            appBar: AdaptiveRouteTopBar(
              title: '在线搜索',
              subtitle: '聚合同名同作者结果',
              leading: const IconButton(
                onPressed: null,
                icon: Icon(Icons.arrow_back),
              ),
              middle: const TextField(
                key: ValueKey<String>('search_route_middle'),
                decoration: InputDecoration(hintText: '输入书名或作者'),
              ),
              actions: [
                AdaptiveOverflowToolbarItem(
                  icon: Icons.search_rounded,
                  label: '搜索',
                  priority: 20,
                  onPressed: () {},
                ),
                AdaptiveOverflowToolbarItem(
                  icon: Icons.source_outlined,
                  label: '全部服务器源',
                  priority: 10,
                  onPressed: () {},
                ),
                AdaptiveOverflowToolbarItem(
                  icon: Icons.check_circle_outline_rounded,
                  label: '精准匹配',
                  priority: 8,
                  onPressed: () {},
                ),
              ],
            ),
            body: const SizedBox.shrink(),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('在线搜索'), findsOneWidget);
    });

    testWidgets(
      'book detail route top bar survives desktop drag width $width',
      (tester) async {
        await tester.pumpWidget(
          AdaptiveTestHarness(
            width: width,
            height: 900,
            wrapWithMaterialApp: true,
            child: Scaffold(
              appBar: AdaptiveRouteTopBar(
                title: '测试书籍',
                subtitle: '作者 · 测试源',
                leading: const IconButton(
                  onPressed: null,
                  icon: Icon(Icons.arrow_back),
                ),
                actions: [
                  AdaptiveOverflowToolbarItem(
                    icon: Icons.edit_outlined,
                    label: '编辑',
                    priority: 12,
                    onPressed: () {},
                  ),
                  AdaptiveOverflowToolbarItem(
                    icon: Icons.share_outlined,
                    label: '分享',
                    priority: 10,
                    onPressed: () {},
                  ),
                  AdaptiveOverflowToolbarItem(
                    icon: Icons.more_horiz_rounded,
                    label: '更多',
                    priority: 4,
                    onPressed: () {},
                  ),
                ],
              ),
              body: const SizedBox.shrink(),
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.text('测试书籍'), findsOneWidget);
      },
    );
  }
}

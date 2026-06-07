import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/app/widgets/app_empty_state_card.dart';
import 'package:shuxiang_reading_next/app/widgets/app_status_state_card.dart';
import 'package:shuxiang_reading_next/features/mine/presentation/bookmarks_page.dart';

import '../../../test_utils/adaptive_test_harness.dart';

void main() {
  testWidgets('灵感空态使用统一空状态卡', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      AdaptiveTestHarness(
        width: 390,
        height: 844,
        wrapWithMaterialApp: true,
        child: Scaffold(
          body: Center(
            child: BookmarksEmptyStateCard(
              onAction: () {
                tapped = true;
              },
            ),
          ),
        ),
      ),
    );

    expect(find.byType(AppEmptyStateCard), findsOneWidget);
    expect(find.text('灵感空空如也'), findsOneWidget);
    expect(find.text('阅读时选中喜欢的段落，点击「保存灵感」'), findsOneWidget);

    await tester.tap(find.text('去阅读一本书'));
    expect(tapped, isTrue);
  });

  testWidgets('灵感加载失败使用统一状态卡', (tester) async {
    var retryTapped = false;
    await tester.pumpWidget(
      AdaptiveTestHarness(
        width: 840,
        height: 900,
        wrapWithMaterialApp: true,
        child: Scaffold(
          body: Center(
            child: BookmarksStatusStateCard(
              title: '加载失败',
              message: '灵感加载失败，请稍后重试。',
              actionLabel: '重试',
              onAction: () {
                retryTapped = true;
              },
            ),
          ),
        ),
      ),
    );

    expect(find.byType(AppStatusStateCard), findsOneWidget);
    expect(find.text('加载失败'), findsOneWidget);
    expect(find.text('灵感加载失败，请稍后重试。'), findsOneWidget);

    await tester.tap(find.text('重试'));
    expect(retryTapped, isTrue);
  });
}

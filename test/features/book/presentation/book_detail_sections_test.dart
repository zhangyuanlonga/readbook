import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shuxiang_reading_next/features/book/presentation/widgets/book_detail_sections.dart';
import '../../../test_utils/adaptive_test_harness.dart';

void main() {
  testWidgets('intro card clamps and expands on compact viewport', (
    tester,
  ) async {
    const intro =
        '这是一段很长的简介，用来覆盖小屏详情页的折叠状态。'
        '它会包含足够多的文字，确保默认状态不会把首屏全部推走，'
        '同时用户仍然可以展开查看完整内容。'
        '继续追加一些描述文字，让长度超过阈值并触发展开按钮。'
        '再补充书籍背景、人物关系、世界观线索和阅读节奏说明，'
        '让测试文本稳定超过折叠阈值。';

    await tester.pumpWidget(
      const AdaptiveTestHarness(
        width: 360,
        height: 800,
        wrapWithMaterialApp: true,
        child: Scaffold(body: BookDetailIntroCard(intro: intro)),
      ),
    );
    await tester.pump();

    final collapsed = tester.widget<Text>(find.text(intro));
    expect(collapsed.maxLines, 5);
    expect(find.text('展开'), findsOneWidget);

    await tester.tap(find.text('展开'));
    await tester.pump();

    final expanded = tester.widget<Text>(find.text(intro));
    expect(expanded.maxLines, isNull);
    expect(find.text('收起'), findsOneWidget);
  });
}

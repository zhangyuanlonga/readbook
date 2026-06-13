import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/app/widgets/runtime_feedback_card.dart';
import 'package:shuxiang_reading_next/domain/entities/local_book.dart';
import 'package:shuxiang_reading_next/features/book/presentation/widgets/book_detail_content_sections.dart';

import 'package:shuxiang_reading_next/features/book/presentation/widgets/book_detail_sections.dart';
import '../../../test_utils/adaptive_test_harness.dart';

void main() {
  testWidgets('summary card can render in desktop scroll view', (tester) async {
    await tester.pumpWidget(
      AdaptiveTestHarness(
        width: 1280,
        height: 800,
        dpr: 1,
        wrapWithMaterialApp: true,
        child: Scaffold(
          body: ListView(
            children: [
              SizedBox(
                width: 260,
                child: BookDetailSummaryCard(
                  title: '桌面端详情布局测试',
                  sourceName: '本地图书',
                  author: '作者甲',
                  cover: Container(
                    width: 104,
                    height: 148,
                    color: Colors.blueGrey,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('桌面端详情布局测试'), findsOneWidget);
  });

  testWidgets('intro card clamps and expands on compact viewport', (
    tester,
  ) async {
    const intro =
        '这是一段很长的简介，用来覆盖小屏详情页的折叠状态。'
        '它会包含足够多的文字，确保默认状态不会把首屏全部推走，'
        '同时用户仍然可以展开查看完整内容。'
        '继续追加一些描述文字，让长度超过阈值并触发展开按钮。'
        '再补充书籍背景、人物关系、世界观线索和阅读节奏说明，'
        '让测试文本稳定超过折叠阈值。'
        '为了避免不同字体度量和平台渲染导致按钮不出现，'
        '这里继续追加更多段落，覆盖折叠状态下的正文裁切逻辑。'
        '读者在详情页应该先看到摘要，再主动展开完整简介，'
        '这也是本测试要锁住的交互行为。';

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
    expect(find.text('展开全文'), findsOneWidget);

    await tester.tap(find.text('展开全文'));
    await tester.pump();

    final expanded = tester.widget<Text>(find.text(intro));
    expect(expanded.maxLines, isNull);
    expect(find.text('收起全文'), findsOneWidget);
  });

  testWidgets('mobile latest meta line places latest chapter and tag inline', (
    tester,
  ) async {
    await tester.pumpWidget(
      const AdaptiveTestHarness(
        width: 390,
        height: 800,
        wrapWithMaterialApp: true,
        child: Scaffold(
          body: BookDetailMobileLatestMetaLine(
            latestChapter: '忘语新书《玄界之门》',
            category: '武侠',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('最新: 忘语新书《玄界之门》'), findsOneWidget);
    expect(find.text('武侠'), findsOneWidget);
    expect(find.textContaining('更新'), findsNothing);
  });

  testWidgets('loading skeleton keeps route preview title visible', (
    tester,
  ) async {
    await tester.pumpWidget(
      const AdaptiveTestHarness(
        width: 390,
        height: 800,
        wrapWithMaterialApp: true,
        child: Scaffold(
          body: BookDetailLoadingSkeleton(title: '剑来', author: '烽火戏诸侯'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('剑来'), findsOneWidget);
    expect(find.text('烽火戏诸侯'), findsOneWidget);
  });

  testWidgets('feedback card exposes retry action', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      AdaptiveTestHarness(
        width: 390,
        height: 800,
        wrapWithMaterialApp: true,
        child: Scaffold(
          body: BookDetailFeedbackCard(
            title: '加载失败',
            message: '响应解析失败',
            tone: RuntimeFeedbackTone.error,
            actions: [
              FilledButton(
                onPressed: () {
                  retried = true;
                },
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('加载失败'), findsOneWidget);
    expect(find.text('响应解析失败'), findsOneWidget);

    await tester.tap(find.text('重试'));
    expect(retried, isTrue);
  });

  testWidgets('local index status card shows rebuild for failed index', (
    tester,
  ) async {
    var rebuild = false;
    final now = DateTime(2026, 6, 13);
    final localBook = LocalBook(
      id: 'local_1',
      title: '本地图书',
      format: LocalBookFormat.txt,
      storagePath: '/tmp/book.txt',
      fileSize: 1024,
      createdAt: now,
      updatedAt: now,
      indexStatus: LocalBookIndexStatus.failed,
      lastError: '解析失败',
    );

    await tester.pumpWidget(
      AdaptiveTestHarness(
        width: 390,
        height: 800,
        wrapWithMaterialApp: true,
        child: Scaffold(
          body: BookDetailLocalIndexStatusCard(
            localBook: localBook,
            isLoading: false,
            onRebuild: () {
              rebuild = true;
            },
          ),
        ),
      ),
    );

    expect(find.text('重建'), findsOneWidget);

    await tester.tap(find.text('重建'));
    expect(rebuild, isTrue);
  });
}

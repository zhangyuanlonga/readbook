import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shuxiang_reading_next/domain/entities/book.dart';
import 'package:shuxiang_reading_next/features/book/application/book_display_state.dart';
import 'package:shuxiang_reading_next/features/search/application/search_models.dart';
import 'package:shuxiang_reading_next/features/search/presentation/widgets/search_book_card.dart';
import 'package:shuxiang_reading_next/features/search/presentation/search_render_state_controller.dart';
import 'package:shuxiang_reading_next/features/search/presentation/widgets/search_results_sliver.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_utils/adaptive_test_harness.dart';

void main() {
  testWidgets('renders with minimal search book fields', (tester) async {
    final book = const Book(
      id: 'book_1',
      sourceId: 'source_a',
      title: '凡人修仙传',
      detailUrl: 'https://example.com/book/1',
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SearchBookCard(
              book: book,
              presentation: const BookDisplayState(displayTitle: '凡人修仙传'),
              sourceName: '测试源',
              heroTag: 'hero_book_1',
              onTap: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('凡人修仙传'), findsWidgets);
    expect(find.text('来源: 测试源'), findsOneWidget);
    expect(find.textContaining('作者:'), findsNothing);
    expect(find.textContaining('最新章节:'), findsNothing);
  });

  testWidgets('keeps search result card inside a 360dp viewport', (
    tester,
  ) async {
    await registerAdaptiveViewportTearDown(tester);
    tester.view.devicePixelRatio = 3;
    await tester.binding.setSurfaceSize(const Size(360, 800));

    final book = const Book(
      id: 'book_1',
      sourceId: 'source_a',
      title: '凡人修仙传',
      detailUrl: 'https://example.com/book/1',
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SearchBookCard(
              book: book,
              presentation: const BookDisplayState(
                displayTitle: '凡人修仙传',
                displayIntro: '一个较长的简介会在紧凑密度下自动减少行数，避免搜索结果卡片把横向空间挤爆。',
              ),
              sourceName: '测试源',
              sourceHitCount: 3,
              heroTag: 'hero_book_360',
              normalizedLatestChapter: '第一百二十三章',
              onTap: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    final cardRect = tester.getRect(find.byType(SearchBookCard));
    expect(cardRect.left, greaterThanOrEqualTo(0));
    expect(cardRect.right, lessThanOrEqualTo(360));
  });

  testWidgets('results sliver renders only visible page and forwards taps', (
    tester,
  ) async {
    const books = <Book>[
      Book(
        id: 'book_1',
        sourceId: 'source_a',
        title: '凡人修仙传',
        detailUrl: 'https://example.com/book/1',
      ),
      Book(
        id: 'book_2',
        sourceId: 'source_b',
        title: '雪中悍刀行',
        detailUrl: 'https://example.com/book/2',
      ),
    ];
    const report = SearchExecutionReport(
      keyword: '凡人',
      sourceCount: 2,
      successSourceCount: 2,
      books: books,
      failures: <SourceSearchFailure>[],
      sourceNames: {'source_a': '测试源A', 'source_b': '测试源B'},
    );
    const renderState = SearchRenderState(
      report: report,
      booksIdentity: 'test',
      keyword: '凡人',
      preciseMatch: false,
      visibleBooks: books,
      normalizedIntros: <String, String?>{},
      normalizedLatestChapters: <String, String?>{},
      renderedResultCount: 1,
    );
    String? tappedBookId;

    await tester.pumpWidget(
      AdaptiveTestHarness(
        width: 390,
        height: 800,
        wrapWithMaterialApp: true,
        child: Scaffold(
          body: CustomScrollView(
            slivers: [
              SearchResultsSliver(
                books: books,
                report: report,
                renderState: renderState,
                visibleCount: 1,
                presentationByTargetKey: const <String, BookDisplayState>{},
                buildHeroTag: (book, index) => 'hero_${book.id}_$index',
                onBookTap: ({
                  required book,
                  required listIndex,
                  required heroTag,
                }) async {
                  tappedBookId = book.id;
                },
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('凡人修仙传'), findsWidgets);
    expect(find.text('雪中悍刀行'), findsNothing);

    await tester.tap(find.text('凡人修仙传').first);
    await tester.pump();

    expect(tappedBookId, 'book_1');
  });
}

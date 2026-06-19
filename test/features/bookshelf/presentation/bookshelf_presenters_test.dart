import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/bookshelf_book.dart';
import 'package:shuxiang_reading_next/features/book/application/book_reading_status_service.dart';
import 'package:shuxiang_reading_next/features/bookshelf/presentation/bookshelf_filter_header_presenter.dart';
import 'package:shuxiang_reading_next/features/bookshelf/presentation/bookshelf_hero_tags.dart';
import 'package:shuxiang_reading_next/features/bookshelf/presentation/bookshelf_page_models.dart';
import 'package:shuxiang_reading_next/features/bookshelf/presentation/widgets/bookshelf_book_more_menu_presenter.dart';

void main() {
  test('hero tag resolver keeps stable detail transition tags', () {
    const resolver = BookshelfHeroTagResolver();
    final book = _book(
      bookId: ' book_1 ',
      sourceId: ' source_a ',
      detailUrl: 'https://example.test/detail/1',
    );

    expect(
      resolver.cover(book),
      'book_cover_source_a_book_1_${book.detailUrl.hashCode}',
    );
    expect(
      resolver.title(book),
      'book_title_source_a_book_1_${book.detailUrl.hashCode}',
    );
    expect(
      resolver.meta(book),
      'book_meta_source_a_book_1_${book.detailUrl.hashCode}',
    );
  });

  test('filter header presenter resolves summary text and height', () {
    const presenter = BookshelfFilterHeaderPresenter();

    expect(
      presenter.searchSummaryText(
        isSelectionMode: true,
        selectedCount: 2,
        hasSearchKeyword: true,
        filteredCount: 5,
        activeFilterLabel: '全部',
      ),
      '已选 2 本',
    );
    expect(
      presenter.searchSummaryText(
        isSelectionMode: false,
        selectedCount: 0,
        hasSearchKeyword: true,
        filteredCount: 3,
        activeFilterLabel: '全部',
      ),
      '结果 3 本',
    );
    expect(
      presenter.searchSummaryText(
        isSelectionMode: false,
        selectedCount: 0,
        hasSearchKeyword: false,
        filteredCount: 7,
        activeFilterLabel: '待读清单',
      ),
      '待读清单 7 本',
    );
    expect(
      presenter.searchSectionHeight(
        showSearchBar: true,
        shouldShowQuickFilters: true,
        shouldShowExpandedSearch: true,
      ),
      108,
    );
  });

  test('filter header presenter resolves quick filter visibility', () {
    const presenter = BookshelfFilterHeaderPresenter();
    final untagged = _book(bookId: 'book_1');
    final tagged = _book(bookId: 'book_2');

    expect(
      presenter.shouldShowQuickFilters(
        content: BookshelfSearchQuickFilterContent.none,
        books: <BookshelfBook>[untagged],
        userTags: const <String>[],
        userCategories: const <String>[],
        tagsOfBook: (_) => const <String>[],
        categoryOfBook: (_) => null,
      ),
      isFalse,
    );
    expect(
      presenter.shouldShowQuickFilters(
        content: BookshelfSearchQuickFilterContent.readingStatus,
        books: <BookshelfBook>[untagged],
        userTags: const <String>[],
        userCategories: const <String>[],
        tagsOfBook: (_) => const <String>[],
        categoryOfBook: (_) => null,
      ),
      isTrue,
    );
    expect(
      presenter.shouldShowQuickFilters(
        content: BookshelfSearchQuickFilterContent.tags,
        books: <BookshelfBook>[tagged],
        userTags: const <String>[],
        userCategories: const <String>[],
        tagsOfBook: (_) => const <String>['玄幻'],
        categoryOfBook: (_) => '小说',
      ),
      isFalse,
    );
    expect(
      presenter.shouldShowQuickFilters(
        content: BookshelfSearchQuickFilterContent.categories,
        books: <BookshelfBook>[untagged],
        userTags: const <String>[],
        userCategories: const <String>[],
        tagsOfBook: (_) => const <String>[],
        categoryOfBook: (_) => null,
      ),
      isTrue,
    );
  });

  testWidgets('more menu presenter emits book actions', (tester) async {
    final actions = <BookshelfBookMoreAction>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: BookshelfBookMoreMenuPresenter(
              book: _book(bookId: 'book_1'),
              compact: false,
              currentReadingStatus: BookReadingStatus.unread,
              onAction: actions.add,
              onReadingStatusSelected: (_) {},
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('查看详情'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();

    expect(actions, <BookshelfBookMoreAction>[
      BookshelfBookMoreAction.detail,
      BookshelfBookMoreAction.delete,
    ]);
  });
}

BookshelfBook _book({
  String bookId = 'book_1',
  String sourceId = 'source_a',
  String detailUrl = 'https://example.test/detail/1',
}) {
  return BookshelfBook(
    bookId: bookId,
    sourceId: sourceId,
    title: '测试书籍',
    detailUrl: detailUrl,
    addedAt: DateTime.parse('2026-06-19T00:00:00.000Z'),
  );
}

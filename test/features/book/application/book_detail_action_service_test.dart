import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuxiang_reading_next/domain/entities/book_detail.dart';
import 'package:shuxiang_reading_next/domain/entities/bookshelf_book.dart';
import 'package:shuxiang_reading_next/features/book/application/book_detail_action_service.dart';
import 'package:shuxiang_reading_next/features/book/application/book_metadata_presentation_resolver.dart';
import 'package:shuxiang_reading_next/features/bookshelf/application/bookshelf_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('toggleBookshelf upserts and removes bookshelf record', () async {
    final prefs = await SharedPreferences.getInstance();
    final bookshelfService = BookshelfService(preferences: prefs);
    final service = BookDetailActionService(bookshelfService: bookshelfService);
    const detail = BookDetail(
      id: 'book_1',
      sourceId: 'source_a',
      title: '原始标题',
      detailUrl: 'https://example.com/book/1',
    );
    const presentation = BookMetadataPresentation(
      displayTitle: '展示标题',
      displayAuthor: '展示作者',
      displayCover: 'https://example.com/cover.jpg',
      displayCoverSource: BookMetadataPresentationCoverSource.remote,
    );

    final added = await service.toggleBookshelf(
      wasInBookshelf: false,
      detail: detail,
      presentation: presentation,
      latestChapterTitle: '第一章',
    );

    expect(added.isInBookshelf, isTrue);
    expect((await bookshelfService.getAll()).single.title, '展示标题');

    final removed = await service.toggleBookshelf(
      wasInBookshelf: true,
      detail: detail,
      presentation: presentation,
    );

    expect(removed.isInBookshelf, isFalse);
    expect(await bookshelfService.getAll(), isEmpty);
  });

  test('saveOrganization persists category and tags', () async {
    final prefs = await SharedPreferences.getInstance();
    final bookshelfService = BookshelfService(preferences: prefs);
    final service = BookDetailActionService(bookshelfService: bookshelfService);
    const detail = BookDetail(
      id: 'book_1',
      sourceId: 'source_a',
      title: '原始标题',
      detailUrl: 'https://example.com/book/1',
    );

    await bookshelfService.upsert(
      BookshelfBook(
        bookId: detail.id,
        sourceId: detail.sourceId,
        title: detail.title,
        detailUrl: detail.detailUrl,
        addedAt: DateTime.parse('2026-04-28T00:00:00.000Z'),
      ),
    );

    await service.saveOrganization(
      detail: detail,
      category: '玄幻',
      tags: const ['在读', '收藏'],
    );

    final categories = await bookshelfService.getCategoryMap();
    final tags = await bookshelfService.getTagMap();
    expect(categories['source_a::https://example.com/book/1'], '玄幻');
    expect(
      tags['source_a::https://example.com/book/1'],
      orderedEquals(const ['在读', '收藏']),
    );
  });
}

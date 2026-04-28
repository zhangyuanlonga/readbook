import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/bookmark.dart';
import 'package:shuxiang_reading_next/domain/entities/chapter.dart';
import 'package:shuxiang_reading_next/features/book/application/book_detail_catalog_service.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_catalog_search_service.dart';

void main() {
  const service = BookDetailCatalogService();

  test('buildDisplayedChapters respects reverse flag', () {
    final chapters = <Chapter>[
      const Chapter(
        id: 'c1',
        bookId: 'book_1',
        title: '第一章',
        chapterUrl: 'https://example.com/1',
        index: 0,
      ),
      const Chapter(
        id: 'c2',
        bookId: 'book_1',
        title: '第二章',
        chapterUrl: 'https://example.com/2',
        index: 1,
      ),
    ];

    expect(
      service.buildDisplayedChapters(chapters, reversed: false).first.id,
      'c1',
    );
    expect(
      service.buildDisplayedChapters(chapters, reversed: true).first.id,
      'c2',
    );
  });

  test('resolveChapterFromBookmark prefers chapter id then chapter index', () {
    final chapters = <Chapter>[
      const Chapter(
        id: 'volume',
        bookId: 'book_1',
        title: '卷一',
        chapterUrl: '',
        index: 0,
        isVolume: true,
      ),
      const Chapter(
        id: 'c1',
        bookId: 'book_1',
        title: '第一章',
        chapterUrl: 'https://example.com/1',
        index: 1,
      ),
    ];

    final bookmarkById = Bookmark(
      id: 'b1',
      bookId: 'book_1',
      chapterId: 'c1',
      chapterIndex: 0,
      startOffset: 0,
      endOffset: 1,
      snippet: 'snippet',
      createdAt: DateTime.parse('2026-04-28T00:00:00.000Z'),
      updatedAt: DateTime.parse('2026-04-28T00:00:00.000Z'),
    );
    final bookmarkByIndex = bookmarkById.copyWith(chapterId: '', chapterIndex: 1);

    expect(service.resolveChapterFromBookmark(chapters, bookmarkById)?.id, 'c1');
    expect(
      service.resolveChapterFromBookmark(chapters, bookmarkByIndex)?.id,
      'c1',
    );
  });

  test('resolves catalog entry target index for readable chapter only', () {
    const chapters = <Chapter>[
      Chapter(
        id: 'volume',
        bookId: 'book_1',
        title: '卷一',
        chapterUrl: '',
        index: 0,
        isVolume: true,
      ),
      Chapter(
        id: 'c1',
        bookId: 'book_1',
        title: '第一章',
        chapterUrl: 'https://example.com/1',
        index: 1,
      ),
    ];
    const entry = ReaderCatalogSearchEntry(
      chapterIndex: 1,
      targetChapterIndex: 1,
      title: '第一章',
      subtitle: '第一章',
      isContent: false,
      isVolume: false,
    );

    expect(service.resolveEntryTargetIndex(entry, chapters), 1);
    expect(
      service.resolveEntryTargetIndex(
        const ReaderCatalogSearchEntry(
          chapterIndex: 0,
          targetChapterIndex: 0,
          title: '卷一',
          subtitle: '卷一',
          isContent: false,
          isVolume: true,
        ),
        chapters,
      ),
      isNull,
    );
  });
}

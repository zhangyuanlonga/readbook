import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/bookmark.dart';
import 'package:shuxiang_reading_next/domain/entities/bookshelf_book.dart';
import 'package:shuxiang_reading_next/domain/entities/chapter.dart';
import 'package:shuxiang_reading_next/domain/entities/reading_progress.dart';
import 'package:shuxiang_reading_next/features/reader/application/local/local_reader_identity.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_entry_route_resolver.dart';

void main() {
  group('ReaderEntryRouteResolver', () {
    const resolver = ReaderEntryRouteResolver();

    test('normalizes local detail and chapter urls for progress route', () {
      final progress = ReadingProgress(
        bookId: 'local_book_1',
        sourceId: LocalReaderIdentity.localSourceId,
        detailUrl: '',
        chapterId: 'chapter_1',
        chapterUrl: '',
        chapterTitle: '第一章',
        chapterIndex: 0,
        updatedAt: DateTime(2026, 4, 7),
      );

      final route = resolver.buildRouteFromProgress(progress);

      expect(route, contains('sourceId=${Uri.encodeQueryComponent(LocalReaderIdentity.localSourceId)}'));
      expect(route, contains(Uri.encodeQueryComponent(LocalReaderIdentity.buildBookDetailUrl('local_book_1'))));
      expect(route, contains(Uri.encodeQueryComponent(LocalReaderIdentity.buildChapterUrl('chapter_1'))));
    });

    test('builds bookshelf fallback route with bootstrap chapter', () {
      final book = BookshelfBook(
        bookId: 'book_1',
        sourceId: 'source_1',
        title: '测试书籍',
        detailUrl: 'https://example.com/detail/1',
        addedAt: DateTime(2026, 4, 7),
      );

      final route = resolver.buildRouteFromBookshelfFallback(book);

      expect(route, contains('/reader/book_1/bootstrap'));
      expect(route, contains(Uri.encodeQueryComponent('https://example.com/detail/1')));
    });

    test('builds bookmark route with bookmark id and local fallback urls', () {
      final bookmark = Bookmark(
        id: 'bookmark_1',
        bookId: 'local_book_1',
        chapterId: '',
        chapterIndex: 2,
        snippet: '片段',
        startOffset: 1,
        endOffset: 3,
        createdAt: DateTime(2026, 4, 7),
        updatedAt: DateTime(2026, 4, 7),
      );

      final route = resolver.buildRouteFromBookmark(
        bookmark: bookmark,
        sourceId: LocalReaderIdentity.localSourceId,
        detailUrl: '',
      );

      expect(route, contains('/reader/local_book_1/bootstrap'));
      expect(route, contains('bookmarkId=bookmark_1'));
      expect(route, contains(Uri.encodeQueryComponent(LocalReaderIdentity.buildBookDetailUrl('local_book_1'))));
      expect(
        route,
        contains(
          Uri.encodeQueryComponent(
            LocalReaderIdentity.buildChapterUrl('bootstrap'),
          ),
        ),
      );
    });

    test('builds chapter route from chapter entity', () {
      const chapter = Chapter(
        id: 'chapter_2',
        bookId: 'book_1',
        title: '第二章',
        chapterUrl: 'https://example.com/chapter/2',
        index: 1,
      );

      final route = resolver.buildRouteFromChapter(
        bookId: 'book_1',
        sourceId: 'source_1',
        detailUrl: 'https://example.com/detail/1',
        chapter: chapter,
      );

      expect(route, contains('/reader/book_1/chapter_2'));
      expect(route, contains(Uri.encodeQueryComponent('https://example.com/chapter/2')));
    });

    test('keeps open trace query when building progress route', () {
      final progress = ReadingProgress(
        bookId: 'book_1',
        sourceId: 'source_1',
        detailUrl: 'https://example.com/detail/1',
        chapterId: 'chapter_1',
        chapterUrl: 'https://example.com/chapter/1',
        chapterTitle: '第一章',
        chapterIndex: 0,
        updatedAt: DateTime(2026, 4, 7),
      );

      final route = resolver.buildRouteFromProgress(
        progress,
        openRequestedAtMs: 123456,
        openRouteKind: 'progress',
      );

      expect(route, contains('openRequestedAtMs=123456'));
      expect(route, contains('openRouteKind=progress'));
    });
  });
}

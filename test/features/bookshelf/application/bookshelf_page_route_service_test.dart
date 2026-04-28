import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuxiang_reading_next/domain/entities/bookshelf_book.dart';
import 'package:shuxiang_reading_next/domain/entities/reading_progress.dart';
import 'package:shuxiang_reading_next/domain/entities/reading_record.dart';
import 'package:shuxiang_reading_next/features/bookshelf/application/bookshelf_page_route_service.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_entry_route_resolver.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_preferences_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BookshelfPageRouteService', () {
    late ReaderPreferencesService preferencesService;
    late BookshelfPageRouteService service;

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      preferencesService = ReaderPreferencesService();
      service = BookshelfPageRouteService(
        readerPreferencesService: preferencesService,
        readerEntryRouteResolver: const ReaderEntryRouteResolver(),
      );
    });

    test('uses matched progress route for latest reading record', () async {
      final record = _record();
      await preferencesService.saveProgress(
        ReadingProgress(
          bookId: record.bookId,
          sourceId: record.sourceId,
          detailUrl: record.detailUrl,
          chapterId: 'chapter_2',
          chapterUrl: 'https://reader.test/chapter-2',
          chapterTitle: '第二章',
          chapterIndex: 1,
          updatedAt: DateTime.parse('2026-04-28T10:00:00.000Z'),
        ),
      );

      final route = await service.resolveLatestReadingRecordRoute(record);

      expect(route, contains('/reader/'));
      expect(route, contains('chapter_2'));
    });

    test('falls back to detail route when no chapter locator exists', () async {
      final route = await service.resolveLatestReadingRecordRoute(
        ReadingRecord(
          bookId: 'book_1',
          sourceId: 'source_1',
          detailUrl: 'https://detail.test/book-1',
          bookTitle: '测试书',
          lastReadAt: DateTime.utc(2026, 4, 28),
        ),
      );

      expect(route, contains('/book/book_1'));
      expect(route, contains('detailUrl='));
    });

    test('builds bookshelf fallback, progress and detail routes', () {
      final book = _book();
      final progress = ReadingProgress(
        bookId: book.bookId,
        sourceId: book.sourceId,
        detailUrl: book.detailUrl,
        chapterId: 'chapter_1',
        chapterUrl: 'https://reader.test/chapter-1',
        chapterTitle: '第一章',
        chapterIndex: 0,
        updatedAt: DateTime.parse('2026-04-28T10:00:00.000Z'),
      );

      expect(service.resolveReaderFallbackRoute(book), contains('/reader/'));
      expect(service.resolveProgressRoute(progress), contains('chapter_1'));
      expect(
        service.resolveBookDetailRoute(book, heroTag: 'hero_1'),
        contains('heroTag=hero_1'),
      );
    });
  });
}

ReadingRecord _record() {
  return ReadingRecord(
    bookId: 'book_1',
    sourceId: 'source_1',
    detailUrl: 'https://detail.test/book-1',
    bookTitle: '测试书',
    bookAuthor: '作者',
    coverUrl: 'https://image.test/cover.jpg',
    lastChapterId: 'chapter_1',
    lastChapterTitle: '第一章',
    lastChapterIndex: 0,
    lastChapterUrl: 'https://reader.test/chapter-1',
    lastReadAt: DateTime.utc(2026, 4, 28),
  );
}

BookshelfBook _book() {
  return BookshelfBook(
    bookId: 'book_1',
    sourceId: 'source_1',
    detailUrl: 'https://detail.test/book-1',
    title: '测试书',
    author: '作者',
    coverUrl: 'https://image.test/cover.jpg',
    addedAt: DateTime.parse('2026-04-28T10:00:00.000Z'),
  );
}

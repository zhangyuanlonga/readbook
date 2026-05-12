import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuxiang_reading_next/data/datasources/local/app_database.dart';
import 'package:shuxiang_reading_next/domain/entities/book_detail.dart';
import 'package:shuxiang_reading_next/domain/entities/chapter.dart';
import 'package:shuxiang_reading_next/domain/entities/reading_record.dart';
import 'package:shuxiang_reading_next/features/book/application/book_metadata_presentation_resolver.dart';
import 'package:shuxiang_reading_next/features/book/application/book_presentation_sync_service.dart';
import 'package:shuxiang_reading_next/features/bookshelf/application/bookshelf_service.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_preferences_service.dart';
import 'package:shuxiang_reading_next/features/reader/application/reading_record_service.dart';

void main() {
  final now = DateTime.parse('2026-04-27T12:00:00.000Z');

  test(
    'syncPresentation writes toc snapshot reading record and bookshelf',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      final database = AppDatabase(executor: NativeDatabase.memory());
      addTearDown(database.close);

      final service = BookPresentationSyncService(
        readerPreferencesService: ReaderPreferencesService(preferences: prefs),
        readingRecordService: ReadingRecordService(database: database),
        bookshelfService: BookshelfService(preferences: prefs),
      );

      await database.upsertReadingRecord(
        ReadingRecord(
          bookId: 'book_1',
          sourceId: 'source_a',
          detailUrl: 'https://example.com/book/1',
          bookTitle: '旧标题',
          bookAuthor: '旧作者',
          coverUrl: 'https://example.com/old-cover.jpg',
          lastReadAt: now,
        ),
      );

      await service.syncPresentation(
        detail: const BookDetail(
          id: 'book_1',
          sourceId: 'source_a',
          title: '原始标题',
          detailUrl: 'https://example.com/book/1',
        ),
        chapters: const <Chapter>[
          Chapter(
            id: 'chapter_1',
            bookId: 'book_1',
            title: '第一章',
            chapterUrl: 'https://example.com/book/1/ch1',
            index: 0,
          ),
        ],
        presentation: const BookDisplayState(
          displayTitle: '展示标题',
          displayAuthor: '展示作者',
          displayCover: 'https://example.com/cover.jpg',
          displayCoverSource: BookDisplayCoverSource.remote,
        ),
        isInBookshelf: true,
        latestChapterTitle: '第一章',
      );

      final snapshot = await ReaderPreferencesService(
        preferences: prefs,
      ).loadTocSnapshot(
        sourceId: 'source_a',
        detailUrl: 'https://example.com/book/1',
      );
      expect(snapshot?.title, '展示标题');
      expect(snapshot?.coverUrl, 'https://example.com/cover.jpg');

      final record = await database.getReadingRecordByBookId('book_1');
      expect(record?.bookTitle, '展示标题');
      expect(record?.coverUrl, 'https://example.com/cover.jpg');

      final bookshelf = await BookshelfService(preferences: prefs).getAll();
      expect(bookshelf, hasLength(1));
      expect(bookshelf.first.title, '展示标题');
      expect(bookshelf.first.coverUrl, 'https://example.com/cover.jpg');
    },
  );
}

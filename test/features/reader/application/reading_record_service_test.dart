import 'package:drift/native.dart';
import 'package:flutter_appread/data/datasources/local/app_database.dart';
import 'package:flutter_appread/features/reader/application/reading_record_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReadingRecordService', () {
    late AppDatabase database;
    late ReadingRecordService service;

    setUp(() {
      database = AppDatabase(executor: NativeDatabase.memory());
      service = ReadingRecordService(database: database);
    });

    tearDown(() async {
      await database.close();
    });

    test('ignores sessions shorter than minimum duration', () async {
      final start = DateTime.parse('2026-03-21T10:00:00.000Z');
      final end = start.add(const Duration(seconds: 5));

      await service.commitSession(
        ReadingRecordCommitInput(
          bookId: 'book_1',
          sourceId: 'source_1',
          detailUrl: 'https://example.com/book/1',
          bookTitle: '测试书',
          chapterId: 'chapter_1',
          chapterTitle: '第一章',
          chapterIndex: 0,
          chapterUrl: 'https://example.com/book/1/chapter/1',
          startAt: start,
          endAt: end,
        ),
      );

      final record = await database.getReadingRecordByBookId('book_1');
      expect(record, isNull);
    });

    test('stores aggregate, daily, and session records', () async {
      final start = DateTime.parse('2026-03-21T10:00:00.000Z');
      final end = start.add(const Duration(minutes: 12));

      await service.commitSession(
        ReadingRecordCommitInput(
          bookId: 'book_1',
          sourceId: 'source_1',
          detailUrl: 'https://example.com/book/1',
          bookTitle: '测试书',
          bookAuthor: '作者甲',
          chapterId: 'chapter_1',
          chapterTitle: '第一章',
          chapterIndex: 0,
          chapterUrl: 'https://example.com/book/1/chapter/1',
          startAt: start,
          endAt: end,
          startPositionRatio: 0.1,
          endPositionRatio: 0.6,
        ),
      );

      final record = await database.getReadingRecordByBookId('book_1');
      expect(record, isNotNull);
      expect(record!.bookTitle, '测试书');
      expect(
        record.totalReadMillis,
        const Duration(minutes: 12).inMilliseconds,
      );

      final day = await database.getReadingRecordDay(
        bookId: 'book_1',
        dateKey: '2026-03-21',
      );
      expect(day, isNotNull);
      expect(day!.readMillis, const Duration(minutes: 12).inMilliseconds);

      final sessions = await database.watchReadingRecordSessions().first;
      expect(sessions, hasLength(1));
      expect(sessions.first.chapterTitle, '第一章');
    });
  });
}

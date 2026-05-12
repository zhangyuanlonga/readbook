import 'package:drift/native.dart';
import 'package:shuxiang_reading_next/data/datasources/local/app_database.dart';
import 'package:shuxiang_reading_next/domain/entities/reading_record.dart';
import 'package:shuxiang_reading_next/domain/entities/reading_record_day.dart';
import 'package:shuxiang_reading_next/domain/entities/reading_record_session.dart';
import 'package:shuxiang_reading_next/features/reader/application/reading_record_service.dart';
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

    test('stores short sessions when progress is meaningful', () async {
      final start = DateTime.parse('2026-03-21T10:00:00.000Z');
      final end = start.add(const Duration(seconds: 5));

      await service.commitSession(
        ReadingRecordCommitInput(
          bookId: 'book_short_progress',
          sourceId: 'source_1',
          detailUrl: 'https://example.com/book/short-progress',
          bookTitle: '短时阅读',
          chapterId: 'chapter_1',
          chapterTitle: '第一章',
          chapterIndex: 0,
          chapterUrl: 'https://example.com/book/short-progress/1',
          startAt: start,
          endAt: end,
          readChars: 600,
          startPositionRatio: 0.0,
          endPositionRatio: 0.2,
        ),
      );

      final record = await database.getReadingRecordByBookId(
        'book_short_progress',
      );
      expect(record, isNotNull);
      expect(
        record!.totalReadMillis,
        const Duration(seconds: 5).inMilliseconds,
      );

      final sessions = await database.listReadingRecordSessionsByBookId(
        'book_short_progress',
      );
      expect(sessions, hasLength(1));
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

    test(
      'reassigns reading records to the new book identity after switching',
      () async {
        final firstStart = DateTime.parse('2026-03-21T10:00:00.000Z');
        final firstEnd = firstStart.add(const Duration(minutes: 12));
        final secondStart = DateTime.parse('2026-03-22T10:00:00.000Z');
        final secondEnd = secondStart.add(const Duration(minutes: 8));

        await service.commitSession(
          ReadingRecordCommitInput(
            bookId: 'book_old',
            sourceId: 'source_old',
            detailUrl: 'https://example.com/book/old',
            bookTitle: '测试书',
            bookAuthor: '作者甲',
            chapterId: 'chapter_1',
            chapterTitle: '第一章',
            chapterIndex: 0,
            chapterUrl: 'https://example.com/book/old/chapter/1',
            startAt: firstStart,
            endAt: firstEnd,
            readChars: 1800,
          ),
        );
        await service.commitSession(
          ReadingRecordCommitInput(
            bookId: 'book_new',
            sourceId: 'source_new',
            detailUrl: 'https://example.com/book/new',
            bookTitle: '测试书',
            bookAuthor: '作者甲',
            chapterId: 'chapter_2',
            chapterTitle: '第二章',
            chapterIndex: 1,
            chapterUrl: 'https://example.com/book/new/chapter/2',
            startAt: secondStart,
            endAt: secondEnd,
            readChars: 1200,
          ),
        );

        await service.reassignBookIdentity(
          previousBookId: 'book_old',
          nextBookId: 'book_new',
          nextSourceId: 'source_new',
          nextDetailUrl: 'https://example.com/book/new',
          nextBookTitle: '测试书',
          nextBookAuthor: '作者甲',
        );

        final oldRecord = await database.getReadingRecordByBookId('book_old');
        final newRecord = await database.getReadingRecordByBookId('book_new');
        final oldSessions = await database.listReadingRecordSessionsByBookId(
          'book_old',
        );
        final newSessions = await database.listReadingRecordSessionsByBookId(
          'book_new',
        );
        final oldDays = await database.listReadingRecordDaysByBookId(
          'book_old',
        );
        final newDays = await database.listReadingRecordDaysByBookId(
          'book_new',
        );

        expect(oldRecord, isNull);
        expect(oldSessions, isEmpty);
        expect(oldDays, isEmpty);

        expect(newRecord, isNotNull);
        expect(newRecord!.sourceId, 'source_new');
        expect(newRecord.detailUrl, 'https://example.com/book/new');
        expect(newRecord.bookTitle, '测试书');
        expect(
          newRecord.totalReadMillis,
          const Duration(minutes: 20).inMilliseconds,
        );
        expect(newRecord.totalReadChars, 3000);
        expect(newSessions, hasLength(2));
        expect(newDays, hasLength(2));
        expect(newSessions.every((item) => item.bookId == 'book_new'), isTrue);
        expect(newDays.every((item) => item.bookId == 'book_new'), isTrue);
      },
    );

    test('sorts merge candidates and filters mismatched authors', () async {
      final now = DateTime.parse('2026-03-21T10:00:00.000Z');
      final target = ReadingRecord(
        bookId: 'target',
        sourceId: 'source_target',
        detailUrl: 'https://example.com/book/target',
        bookTitle: '同名书',
        bookAuthor: '作者甲',
        lastReadAt: now,
      );
      final sameAuthor = ReadingRecord(
        bookId: 'same_author',
        sourceId: 'source_a',
        detailUrl: 'https://example.com/book/a',
        bookTitle: '同名书',
        bookAuthor: '作者甲',
        totalReadMillis: const Duration(minutes: 30).inMilliseconds,
        lastReadAt: now.subtract(const Duration(minutes: 1)),
      );
      final missingAuthor = ReadingRecord(
        bookId: 'missing_author',
        sourceId: 'source_b',
        detailUrl: 'https://example.com/book/b',
        bookTitle: '同名书',
        bookAuthor: null,
        totalReadMillis: const Duration(minutes: 10).inMilliseconds,
        lastReadAt: now.subtract(const Duration(minutes: 2)),
      );
      final differentAuthor = ReadingRecord(
        bookId: 'different_author',
        sourceId: 'source_c',
        detailUrl: 'https://example.com/book/c',
        bookTitle: '同名书',
        bookAuthor: '作者乙',
        totalReadMillis: const Duration(minutes: 50).inMilliseconds,
        lastReadAt: now.subtract(const Duration(minutes: 3)),
      );

      await database.upsertReadingRecord(target);
      await database.upsertReadingRecord(sameAuthor);
      await database.upsertReadingRecord(missingAuthor);
      await database.upsertReadingRecord(differentAuthor);

      final result = await service.getMergeCandidates(target);

      expect(result.blockedCount, 1);
      expect(
        result.candidates.map((item) => item.record.bookId).toList(),
        <String>['same_author', 'missing_author'],
      );
      expect(result.candidates.first.risk, ReadingRecordMergeRisk.safe);
      expect(result.candidates.last.risk, ReadingRecordMergeRisk.review);
    });

    test('ignores blocked merge sources with different authors', () async {
      final now = DateTime.parse('2026-03-21T10:00:00.000Z');
      final target = ReadingRecord(
        bookId: 'target',
        sourceId: 'source_target',
        detailUrl: 'https://example.com/book/target',
        bookTitle: '同名书',
        bookAuthor: '作者甲',
        totalReadMillis: const Duration(minutes: 20).inMilliseconds,
        lastReadAt: now,
      );
      final blocked = ReadingRecord(
        bookId: 'blocked',
        sourceId: 'source_blocked',
        detailUrl: 'https://example.com/book/blocked',
        bookTitle: '同名书',
        bookAuthor: '作者乙',
        totalReadMillis: const Duration(minutes: 10).inMilliseconds,
        lastReadAt: now.subtract(const Duration(minutes: 5)),
      );

      await database.upsertReadingRecord(target);
      await database.upsertReadingRecord(blocked);
      await database.insertReadingRecordSession(
        ReadingRecordSession(
          id: 0,
          bookId: 'blocked',
          sourceId: 'source_blocked',
          detailUrl: 'https://example.com/book/blocked',
          bookTitle: '同名书',
          bookAuthor: '作者乙',
          chapterId: 'chapter_1',
          chapterTitle: '第一章',
          chapterIndex: 0,
          chapterUrl: 'https://example.com/book/blocked/1',
          startAt: now.subtract(const Duration(minutes: 10)),
          endAt: now.subtract(const Duration(minutes: 1)),
          durationMillis: const Duration(minutes: 9).inMilliseconds,
        ),
      );

      await service.mergeRecords(
        target: target,
        sources: <ReadingRecord>[blocked],
      );

      final blockedRecord = await database.getReadingRecordByBookId('blocked');
      expect(blockedRecord, isNotNull);

      final targetRecord = await database.getReadingRecordByBookId('target');
      expect(targetRecord, isNotNull);
      expect(
        targetRecord!.totalReadMillis,
        const Duration(minutes: 20).inMilliseconds,
      );

      final blockedSessions = await database.listReadingRecordSessionsByBookId(
        'blocked',
      );
      expect(blockedSessions, hasLength(1));
    });

    test(
      'keeps target chapter location when merged latest session lacks anchor',
      () async {
        final now = DateTime.parse('2026-03-21T10:00:00.000Z');
        final target = ReadingRecord(
          bookId: 'target',
          sourceId: 'source_target',
          detailUrl: 'https://example.com/book/target',
          bookTitle: '同名书',
          bookAuthor: '作者甲',
          lastChapterId: 'target_chapter',
          lastChapterTitle: '目标章节',
          lastChapterIndex: 8,
          lastChapterUrl: 'https://example.com/book/target/9',
          lastPositionRatio: 0.72,
          totalReadMillis: const Duration(minutes: 20).inMilliseconds,
          lastReadAt: now.subtract(const Duration(minutes: 30)),
        );
        final source = ReadingRecord(
          bookId: 'source',
          sourceId: 'source_other',
          detailUrl: 'https://example.com/book/source',
          bookTitle: '同名书',
          bookAuthor: '作者甲',
          totalReadMillis: const Duration(minutes: 12).inMilliseconds,
          lastReadAt: now,
        );

        await database.upsertReadingRecord(target);
        await database.upsertReadingRecord(source);
        await database.insertReadingRecordSession(
          ReadingRecordSession(
            id: 0,
            bookId: 'source',
            sourceId: 'source_other',
            detailUrl: 'https://example.com/book/source',
            bookTitle: '同名书',
            bookAuthor: '作者甲',
            chapterId: 'source_chapter',
            chapterTitle: '源章节',
            chapterIndex: 20,
            chapterUrl: 'https://example.com/book/source/21',
            startAt: now.subtract(const Duration(minutes: 12)),
            endAt: now,
            durationMillis: const Duration(minutes: 12).inMilliseconds,
            startPositionRatio: 0.2,
            endPositionRatio: 0.9,
          ),
        );

        await service.mergeRecords(
          target: target,
          sources: <ReadingRecord>[source],
        );

        final merged = await database.getReadingRecordByBookId('target');
        expect(merged, isNotNull);
        expect(merged!.sourceId, 'source_target');
        expect(merged.detailUrl, 'https://example.com/book/target');
        expect(merged.lastChapterId, 'target_chapter');
        expect(merged.lastChapterUrl, 'https://example.com/book/target/9');
        expect(merged.lastPositionRatio, closeTo(0.72, 0.0001));
        expect(
          merged.lastReadAt.millisecondsSinceEpoch,
          now.millisecondsSinceEpoch,
        );
      },
    );

    test('deletes and restores book record snapshot', () async {
      final start = DateTime.parse('2026-03-21T10:00:00.000Z');
      final end = start.add(const Duration(minutes: 12));

      await service.commitSession(
        ReadingRecordCommitInput(
          bookId: 'book_restore',
          sourceId: 'source_1',
          detailUrl: 'https://example.com/book/restore',
          bookTitle: '可恢复书籍',
          bookAuthor: '作者甲',
          chapterId: 'chapter_1',
          chapterTitle: '第一章',
          chapterIndex: 0,
          chapterUrl: 'https://example.com/book/restore/1',
          startAt: start,
          endAt: end,
          readChars: 1234,
        ),
      );

      final record = await database.getReadingRecordByBookId('book_restore');
      final snapshot = await service.deleteRecordWithSnapshot(record!);

      expect(snapshot, isNotNull);
      expect(await database.getReadingRecordByBookId('book_restore'), isNull);

      await service.restoreDeletedRecord(snapshot!);

      final restored = await database.getReadingRecordByBookId('book_restore');
      expect(restored, isNotNull);
      expect(restored!.totalReadChars, 1234);

      final restoredSessions = await database.listReadingRecordSessionsByBookId(
        'book_restore',
      );
      expect(restoredSessions, hasLength(1));
    });

    test('deletes and restores day and session snapshots', () async {
      final start = DateTime.parse('2026-03-21T10:00:00.000Z');
      final mid = start.add(const Duration(minutes: 12));
      final end = start.add(const Duration(hours: 2));

      await service.commitSession(
        ReadingRecordCommitInput(
          bookId: 'book_day_restore',
          sourceId: 'source_1',
          detailUrl: 'https://example.com/book/day',
          bookTitle: '按天恢复',
          bookAuthor: '作者甲',
          chapterId: 'chapter_1',
          chapterTitle: '第一章',
          chapterIndex: 0,
          chapterUrl: 'https://example.com/book/day/1',
          startAt: start,
          endAt: mid,
          readChars: 100,
        ),
      );
      await service.commitSession(
        ReadingRecordCommitInput(
          bookId: 'book_day_restore',
          sourceId: 'source_1',
          detailUrl: 'https://example.com/book/day',
          bookTitle: '按天恢复',
          bookAuthor: '作者甲',
          chapterId: 'chapter_2',
          chapterTitle: '第二章',
          chapterIndex: 1,
          chapterUrl: 'https://example.com/book/day/2',
          startAt: end,
          endAt: end.add(const Duration(minutes: 15)),
          readChars: 200,
        ),
      );

      final daySnapshot = await service.deleteDayRecordWithSnapshot(
        ReadingRecordDay(
          bookId: 'book_day_restore',
          dateKey: '2026-03-21',
          bookTitle: '按天恢复',
          bookAuthor: '作者甲',
          readMillis: 0,
          firstReadAt: start,
          lastReadAt: mid,
        ),
      );
      expect(daySnapshot, isNotNull);
      expect(
        await database.getReadingRecordDay(
          bookId: 'book_day_restore',
          dateKey: '2026-03-21',
        ),
        isNull,
      );

      await service.restoreDeletedDayRecord(daySnapshot!);
      expect(
        await database.getReadingRecordDay(
          bookId: 'book_day_restore',
          dateKey: '2026-03-21',
        ),
        isNotNull,
      );

      final sessions = await database.listReadingRecordSessionsByBookId(
        'book_day_restore',
      );
      final sessionSnapshot = await service.deleteSessionWithSnapshot(
        sessions.first,
      );
      expect(sessionSnapshot, isNotNull);

      await service.restoreDeletedSession(sessionSnapshot!);
      final restoredSessions = await database.listReadingRecordSessionsByBookId(
        'book_day_restore',
      );
      expect(restoredSessions, hasLength(2));
    });
  });
}

// ignore_for_file: depend_on_referenced_packages

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/data/datasources/local/app_database.dart';
import 'package:shuxiang_reading_next/domain/entities/book_identity.dart';
import 'package:shuxiang_reading_next/domain/entities/book_metadata_override.dart';
import 'package:shuxiang_reading_next/domain/entities/chapter.dart';
import 'package:shuxiang_reading_next/domain/entities/local_book.dart';
import 'package:shuxiang_reading_next/domain/entities/reader_toc_snapshot.dart';
import 'package:shuxiang_reading_next/domain/entities/reading_book_status.dart';
import 'package:shuxiang_reading_next/domain/entities/reading_progress.dart';
import 'package:shuxiang_reading_next/domain/entities/reading_record.dart';
import 'package:shuxiang_reading_next/domain/entities/reading_record_session.dart';

void main() {
  group('AppDatabase storage maintenance', () {
    late AppDatabase database;

    setUp(() {
      database = AppDatabase(executor: NativeDatabase.memory());
    });

    tearDown(() async {
      await database.close();
    });

    test('cleans orphaned local-source records and stale search hits', () async {
      final now = DateTime.utc(2026, 6, 10, 12);
      final retainedBook = LocalBook(
        id: 'local_book_kept',
        title: 'Kept Local Book',
        format: LocalBookFormat.txt,
        storagePath: '/tmp/kept.txt',
        fileSize: 128,
        createdAt: now,
        updatedAt: now,
      );
      await database.upsertLocalBook(retainedBook);

      await database.upsertReadingProgress(
        ReadingProgress(
          bookId: 'local_book_kept',
          sourceId: BookIdentityScheme.localSourceId,
          detailUrl: buildLocalBookDetailUrl('local_book_kept'),
          chapterId: 'chapter_kept',
          chapterUrl: buildLocalChapterUrl('chapter_kept'),
          chapterTitle: 'Kept',
          chapterIndex: 1,
          chapterPositionRatio: 0.5,
          updatedAt: now,
        ),
      );
      await database.upsertReadingProgress(
        ReadingProgress(
          bookId: 'local_book_orphan',
          sourceId: BookIdentityScheme.localSourceId,
          detailUrl: buildLocalBookDetailUrl('local_book_orphan'),
          chapterId: 'chapter_orphan',
          chapterUrl: buildLocalChapterUrl('chapter_orphan'),
          chapterTitle: 'Orphan',
          chapterIndex: 2,
          chapterPositionRatio: 0.25,
          updatedAt: now,
        ),
      );
      await database.upsertReadingRecord(
        ReadingRecord(
          bookId: 'local_book_orphan',
          sourceId: BookIdentityScheme.localSourceId,
          detailUrl: buildLocalBookDetailUrl('local_book_orphan'),
          bookTitle: 'Orphan',
          lastReadAt: now,
        ),
      );
      await database.insertReadingRecordSession(
        ReadingRecordSession(
          id: 0,
          bookId: 'local_book_orphan',
          sourceId: BookIdentityScheme.localSourceId,
          detailUrl: buildLocalBookDetailUrl('local_book_orphan'),
          bookTitle: 'Orphan',
          startAt: now.subtract(const Duration(minutes: 10)),
          endAt: now,
          durationMillis: 600000,
        ),
      );
      await database.upsertReadingBookStatus(
        ReadingBookStatusEntry(
          bookId: 'local_book_orphan',
          sourceId: BookIdentityScheme.localSourceId,
          detailUrl: buildLocalBookDetailUrl('local_book_orphan'),
          bookTitle: 'Orphan',
          override: ReadingBookStatusOverride.reading,
          updatedAt: now,
        ),
      );
      await database.upsertTocSnapshot(
        ReaderTocSnapshot(
          bookId: 'local_book_orphan',
          sourceId: BookIdentityScheme.localSourceId,
          detailUrl: buildLocalBookDetailUrl('local_book_orphan'),
          title: 'Orphan',
          chapters: const <Chapter>[
            Chapter(
              id: 'chapter_orphan',
              bookId: 'local_book_orphan',
              title: 'Orphan Chapter',
              chapterUrl: 'local://chapter/orphan',
              index: 1,
            ),
          ],
          updatedAt: now,
        ),
      );
      await database.upsertBookMetadataOverride(
        BookMetadataOverride.forLocal(
          bookId: 'local_book_orphan',
          title: 'Orphan Override',
          updatedAt: now,
        ),
      );
      await database.upsertSearchSourceHits(const <SearchSourceHitUpsert>[
        SearchSourceHitUpsert(
          titleNorm: 'book',
          authorNorm: '',
          sourceId: 'source_old',
          sourceName: 'Old Source',
          title: 'Book',
        ),
        SearchSourceHitUpsert(
          titleNorm: 'book',
          authorNorm: '',
          sourceId: 'source_new',
          sourceName: 'New Source',
          title: 'Book',
        ),
      ]);
      await database.customStatement(
        "UPDATE search_source_hits SET updated_at = ? WHERE source_id = 'source_old'",
        <Object>[
          now.subtract(const Duration(days: 120)).millisecondsSinceEpoch,
        ],
      );
      await database.customStatement(
        "UPDATE search_source_hits SET updated_at = ? WHERE source_id = 'source_new'",
        <Object>[now.subtract(const Duration(days: 10)).millisecondsSinceEpoch],
      );

      final report = await database.runStorageMaintenance(now: now);

      expect(report.orphanedLocalReadingProgresses, 1);
      expect(report.orphanedLocalReadingRecords, 1);
      expect(report.orphanedLocalReadingRecordSessions, 1);
      expect(report.orphanedLocalReadingBookStatuses, 1);
      expect(report.orphanedLocalTocSnapshots, 1);
      expect(report.orphanedLocalMetadataOverrides, 1);
      expect(report.staleSearchSourceHits, 1);
      expect(report.totalDeleted, 7);

      final remainingProgresses = await database.listReadingProgresses();
      expect(remainingProgresses.map((item) => item.bookId), <String>[
        'local_book_kept',
      ]);
      expect(
        (await database.listLatestReadingRecords()).map((item) => item.bookId),
        isEmpty,
      );
      expect(await database.listAllReadingRecordSessions(), isEmpty);
      expect(await database.listReadingBookStatuses(), isEmpty);
      expect(
        await database.getTocSnapshot(
          '${BookIdentityScheme.localSourceId}|${buildLocalBookDetailUrl('local_book_orphan')}',
        ),
        isNull,
      );
      expect(
        await database.getBookMetadataOverrideByLocalBookId(
          'local_book_orphan',
        ),
        isNull,
      );
      expect(await database.countSearchSourceHits(), 1);
      expect(
        await database.getSearchSourceHitCounts(
          titleNorm: 'book',
          authorNorm: '',
        ),
        <String, int>{'source_new': 1},
      );
    });

    test('deleteLocalBook clears dependent local records', () async {
      final now = DateTime.utc(2026, 6, 10, 18);
      await database.upsertLocalBook(
        LocalBook(
          id: 'local_book_1',
          title: 'Local Book',
          format: LocalBookFormat.txt,
          storagePath: '/tmp/local_book.txt',
          fileSize: 256,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await database.upsertReadingProgress(
        ReadingProgress(
          bookId: 'local_book_1',
          sourceId: BookIdentityScheme.localSourceId,
          detailUrl: buildLocalBookDetailUrl('local_book_1'),
          chapterId: 'chapter_1',
          chapterUrl: buildLocalChapterUrl('chapter_1'),
          chapterTitle: 'Chapter 1',
          chapterIndex: 1,
          chapterPositionRatio: 0.4,
          updatedAt: now,
        ),
      );
      await database.upsertReadingRecord(
        ReadingRecord(
          bookId: 'local_book_1',
          sourceId: BookIdentityScheme.localSourceId,
          detailUrl: buildLocalBookDetailUrl('local_book_1'),
          bookTitle: 'Local Book',
          lastReadAt: now,
        ),
      );
      await database.upsertReadingBookStatus(
        ReadingBookStatusEntry(
          bookId: 'local_book_1',
          sourceId: BookIdentityScheme.localSourceId,
          detailUrl: buildLocalBookDetailUrl('local_book_1'),
          bookTitle: 'Local Book',
          override: ReadingBookStatusOverride.completed,
          updatedAt: now,
        ),
      );
      await database.upsertTocSnapshot(
        ReaderTocSnapshot(
          bookId: 'local_book_1',
          sourceId: BookIdentityScheme.localSourceId,
          detailUrl: buildLocalBookDetailUrl('local_book_1'),
          title: 'Local Book',
          chapters: const <Chapter>[],
          updatedAt: now,
        ),
      );
      await database.upsertBookMetadataOverride(
        BookMetadataOverride.forLocal(
          bookId: 'local_book_1',
          title: 'Override',
          updatedAt: now,
        ),
      );

      await database.deleteLocalBook('local_book_1');

      expect(await database.getLocalBookById('local_book_1'), isNull);
      expect(await database.getReadingProgressByBookId('local_book_1'), isNull);
      expect(await database.getReadingRecordByBookId('local_book_1'), isNull);
      expect(await database.listReadingBookStatuses(), isEmpty);
      expect(
        await database.getBookMetadataOverrideByLocalBookId('local_book_1'),
        isNull,
      );
    });
  });
}

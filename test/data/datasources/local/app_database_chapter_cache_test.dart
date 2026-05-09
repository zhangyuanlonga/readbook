// ignore_for_file: depend_on_referenced_packages

import 'dart:io';

import 'package:drift/native.dart';
import 'package:shuxiang_reading_next/data/datasources/local/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  group('AppDatabase chapter caches', () {
    late AppDatabase database;

    setUp(() {
      database = AppDatabase(executor: NativeDatabase.memory());
    });

    tearDown(() async {
      await database.close();
    });

    test('upsert, count and delete caches', () async {
      await database.upsertChapterCache(
        cacheKey: 's1|u1',
        bookId: 'book_1',
        sourceId: 's1',
        chapterIndex: 0,
        chapterUrl: 'u1',
        chapterTitle: 'c1',
        content: 'hello',
      );
      await database.upsertChapterCache(
        cacheKey: 's1|u2',
        bookId: 'book_1',
        sourceId: 's1',
        chapterIndex: 1,
        chapterUrl: 'u2',
        chapterTitle: 'c2',
        content: 'world',
      );

      final cached = await database.getCachedChapterCount('book_1');
      expect(cached, 2);

      final summary = await database.listCachedBooks();
      expect(summary, hasLength(1));
      expect(summary.first.bookId, 'book_1');
      expect(summary.first.cachedCount, 2);

      await database.deleteChapterCachesByBookId('book_1');
      expect(await database.getCachedChapterCount('book_1'), 0);

      final total = await database.getTotalCachedChapterCount();
      expect(total, 0);
    });

    test('clear all caches', () async {
      await database.upsertChapterCache(
        cacheKey: 's1|u1',
        bookId: 'book_1',
        sourceId: 's1',
        chapterIndex: 0,
        chapterUrl: 'u1',
        chapterTitle: 'c1',
        content: 'hello',
      );
      await database.upsertChapterCache(
        cacheKey: 's1|u2',
        bookId: 'book_2',
        sourceId: 's1',
        chapterIndex: 0,
        chapterUrl: 'u2',
        chapterTitle: 'c2',
        content: 'world',
      );

      expect(await database.getTotalCachedChapterCount(), 2);
      await database.clearChapterCaches();
      expect(await database.getTotalCachedChapterCount(), 0);
    });

    test('summarizes estimated bytes and prunes by byte budget', () async {
      await database.upsertChapterCache(
        cacheKey: 's1|large',
        bookId: 'book_1',
        sourceId: 's1',
        chapterIndex: 0,
        chapterUrl: 'large',
        chapterTitle: 'large',
        content: 'x' * 1024,
      );
      await database.upsertChapterCache(
        cacheKey: 's1|small',
        bookId: 'book_1',
        sourceId: 's1',
        chapterIndex: 1,
        chapterUrl: 'small',
        chapterTitle: 'small',
        content: 'ok',
      );
      await database.customStatement(
        "UPDATE chapter_caches SET updated_at = ? WHERE cache_key = 's1|large'",
        <Object>[DateTime(2026, 1).millisecondsSinceEpoch],
      );
      await database.customStatement(
        "UPDATE chapter_caches SET updated_at = ? WHERE cache_key = 's1|small'",
        <Object>[DateTime(2026, 1, 2).millisecondsSinceEpoch],
      );

      final summaries = await database.listCachedBooks();
      expect(summaries.single.estimatedBytes, greaterThan(1024));

      final deleted = await database.pruneChapterCachesByBudget(
        maxEntries: 10,
        maxBytes: 256,
      );

      expect(deleted, 1);
      expect(await database.getChapterCache('s1|large'), isNull);
      expect(await database.getChapterCache('s1|small'), isNotNull);
    });

    test('creates reader cache query indexes', () async {
      final chapterIndexes =
          await database
              .customSelect('PRAGMA index_list(chapter_caches)')
              .get();
      final localChapterIndexes =
          await database
              .customSelect('PRAGMA index_list(local_chapters)')
              .get();
      final bookmarkIndexes =
          await database.customSelect('PRAGMA index_list(bookmarks)').get();

      expect(
        chapterIndexes.any(
          (row) => row.data['name'] == 'idx_chapter_caches_book_id',
        ),
        isTrue,
      );
      expect(
        chapterIndexes.any(
          (row) => row.data['name'] == 'idx_chapter_caches_book_source_chapter',
        ),
        isTrue,
      );
      expect(
        chapterIndexes.any(
          (row) => row.data['name'] == 'idx_chapter_caches_updated_at',
        ),
        isTrue,
      );
      expect(
        localChapterIndexes.any(
          (row) => row.data['name'] == 'idx_local_chapters_book_chapter',
        ),
        isTrue,
      );
      expect(
        bookmarkIndexes.any(
          (row) => row.data['name'] == 'idx_bookmarks_book_chapter_start',
        ),
        isTrue,
      );
    });

    test('migrates v25 database with reader cache query indexes', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'app_database_reader_index_migration',
      );
      final dbFile = File('${tempDir.path}/app.sqlite');
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final seed = AppDatabase(executor: NativeDatabase(dbFile));
      await seed.customSelect('SELECT 1').get();
      await seed.close();

      final sqliteDb = sqlite.sqlite3.open(dbFile.path);
      try {
        for (final name in <String>[
          'idx_chapter_caches_book_id',
          'idx_chapter_caches_book_source_chapter',
          'idx_chapter_caches_updated_at',
          'idx_local_chapters_book_chapter',
          'idx_bookmarks_book_chapter_start',
        ]) {
          sqliteDb.execute('DROP INDEX IF EXISTS $name;');
        }
        sqliteDb.execute('PRAGMA user_version = 25;');
      } finally {
        sqliteDb.close();
      }

      final migrated = AppDatabase(executor: NativeDatabase(dbFile));
      addTearDown(migrated.close);
      await migrated.customSelect('SELECT 1').get();

      final chapterIndexes =
          await migrated
              .customSelect('PRAGMA index_list(chapter_caches)')
              .get();
      final localChapterIndexes =
          await migrated
              .customSelect('PRAGMA index_list(local_chapters)')
              .get();
      final bookmarkIndexes =
          await migrated.customSelect('PRAGMA index_list(bookmarks)').get();

      expect(
        chapterIndexes.any(
          (row) => row.data['name'] == 'idx_chapter_caches_book_id',
        ),
        isTrue,
      );
      expect(
        chapterIndexes.any(
          (row) => row.data['name'] == 'idx_chapter_caches_book_source_chapter',
        ),
        isTrue,
      );
      expect(
        chapterIndexes.any(
          (row) => row.data['name'] == 'idx_chapter_caches_updated_at',
        ),
        isTrue,
      );
      expect(
        localChapterIndexes.any(
          (row) => row.data['name'] == 'idx_local_chapters_book_chapter',
        ),
        isTrue,
      );
      expect(
        bookmarkIndexes.any(
          (row) => row.data['name'] == 'idx_bookmarks_book_chapter_start',
        ),
        isTrue,
      );
    });
  });
}

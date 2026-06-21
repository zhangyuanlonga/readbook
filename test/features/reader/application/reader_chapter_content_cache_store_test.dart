import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/core/cache/cache_entry.dart';
import 'package:shuxiang_reading_next/core/cache/cache_policy.dart';
import 'package:shuxiang_reading_next/core/cache/cache_result.dart';
import 'package:shuxiang_reading_next/data/datasources/local/app_database.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_chapter_content_cache_store.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_gateway_content_cache_codec.dart';

void main() {
  group('ReaderChapterContentCacheStore', () {
    late AppDatabase database;
    late ReaderChapterContentCacheStore store;
    const keyBuilder = ReaderChapterContentCacheKeyBuilder();

    setUp(() {
      database = AppDatabase(executor: NativeDatabase.memory());
      store = ReaderChapterContentCacheStore(database: database);
    });

    tearDown(() async {
      await database.close();
    });

    test('writes and reads chapter content through AppCacheStore', () async {
      final key = keyBuilder.build(
        bookId: 'book_1',
        sourceId: 'source_1',
        chapterUrl: 'chapter://1',
        chapterIndex: 0,
      );
      final now = DateTime(2026, 6, 13);

      final writeResult = await store.write(
        AppCacheEntry(
          key: key,
          payload: '{"content":"正文"}',
          createdAt: now,
          updatedAt: now,
          lastAccessedAt: now,
          metadata: <String, Object?>{
            'bookId': 'book_1',
            'sourceId': 'source_1',
            'chapterIndex': 0,
            'chapterTitle': '第一章',
            'chapterUrl': 'chapter://1',
          },
        ),
      );
      final readResult = await store.read(key);

      expect(writeResult.status, AppCacheWriteStatus.written);
      expect(readResult.status, AppCacheReadStatus.hit);
      expect(readResult.entry?.payload, '{"content":"正文"}');
      expect(readResult.entry?.metadata['cacheKey'], 'source_1|chapter://1');
    });

    test('reads existing source-url cache keys', () async {
      await database.upsertChapterCache(
        cacheKey: 'source_1|chapter://1',
        bookId: 'book_1',
        sourceId: 'source_1',
        chapterIndex: 2,
        chapterUrl: 'chapter://1',
        content: 'cached payload',
      );

      final result = await store.read(
        keyBuilder.build(
          bookId: 'book_1',
          sourceId: 'source_1',
          chapterUrl: 'chapter://1',
          chapterIndex: 2,
        ),
      );

      expect(result.status, AppCacheReadStatus.hit);
      expect(result.entry?.payload, 'cached payload');
    });

    test('returns miss for absent chapter content', () async {
      final result = await store.read(
        keyBuilder.build(
          bookId: 'book_missing',
          sourceId: 'source_missing',
          chapterUrl: 'chapter://missing',
          chapterIndex: 1,
        ),
      );

      expect(result.status, AppCacheReadStatus.miss);
    });

    test('skips empty payload writes', () async {
      final key = keyBuilder.build(
        bookId: 'book_empty',
        sourceId: 'source_empty',
        chapterUrl: 'chapter://empty',
        chapterIndex: 1,
      );
      final now = DateTime(2026, 6, 13);

      final writeResult = await store.write(
        AppCacheEntry(
          key: key,
          payload: '   ',
          createdAt: now,
          updatedAt: now,
          lastAccessedAt: now,
          metadata: <String, Object?>{
            'bookId': 'book_empty',
            'sourceId': 'source_empty',
            'chapterIndex': 1,
            'chapterUrl': 'chapter://empty',
          },
        ),
      );
      final readResult = await store.read(key);

      expect(writeResult.status, AppCacheWriteStatus.skipped);
      expect(readResult.status, AppCacheReadStatus.miss);
    });

    test('reports corrupted prefixed payload as decodeFailed', () async {
      await database.upsertChapterCache(
        cacheKey: 'source_bad|chapter://bad',
        bookId: 'book_bad',
        sourceId: 'source_bad',
        chapterIndex: 1,
        chapterUrl: 'chapter://bad',
        content: '${ReaderGatewayContentCacheCodec.payloadPrefix}{bad json',
      );

      final result = await store.read(
        keyBuilder.build(
          bookId: 'book_bad',
          sourceId: 'source_bad',
          chapterUrl: 'chapter://bad',
          chapterIndex: 1,
        ),
      );

      expect(result.status, AppCacheReadStatus.decodeFailed);
      expect(result.invalidReason, AppCacheInvalidReason.payloadCorrupted);
    });

    test('reports schema version mismatch from policy', () async {
      await database.upsertChapterCache(
        cacheKey: 'source_version|chapter://version',
        bookId: 'book_version',
        sourceId: 'source_version',
        chapterIndex: 1,
        chapterUrl: 'chapter://version',
        content: 'versioned payload',
      );

      final result = await store.read(
        keyBuilder.build(
          bookId: 'book_version',
          sourceId: 'source_version',
          chapterUrl: 'chapter://version',
          chapterIndex: 1,
        ),
        policy: const AppCachePolicy(version: 2),
      );

      expect(result.status, AppCacheReadStatus.versionMismatch);
      expect(result.invalidReason, AppCacheInvalidReason.versionChanged);
    });

    test('deletes a single chapter cache entry', () async {
      await database.upsertChapterCache(
        cacheKey: 'source_delete|chapter://delete',
        bookId: 'book_delete',
        sourceId: 'source_delete',
        chapterIndex: 1,
        chapterUrl: 'chapter://delete',
        content: 'payload',
      );
      final key = keyBuilder.build(
        bookId: 'book_delete',
        sourceId: 'source_delete',
        chapterUrl: 'chapter://delete',
        chapterIndex: 1,
      );

      final deleteResult = await store.delete(key);
      final readResult = await store.read(key);

      expect(deleteResult.deletedEntries, 1);
      expect(readResult.status, AppCacheReadStatus.miss);
    });
  });
}

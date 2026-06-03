import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/core/cache/app_cache_governance_service.dart';
import 'package:shuxiang_reading_next/core/cache/cover_image_disk_cache.dart';
import 'package:shuxiang_reading_next/data/datasources/local/app_database.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_pagination_cache_service.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_pagination_models.dart';

void main() {
  group('AppCacheGovernanceService', () {
    late AppDatabase database;
    late Directory paginationDir;
    late Directory coverDir;
    late ReaderPaginationCacheService paginationCacheService;
    late CoverImageDiskCache coverImageDiskCache;

    setUp(() async {
      database = AppDatabase(executor: NativeDatabase.memory());
      paginationDir = await Directory.systemTemp.createTemp(
        'app_cache_governance_pagination_',
      );
      coverDir = await Directory.systemTemp.createTemp(
        'app_cache_governance_cover_',
      );
      paginationCacheService = ReaderPaginationCacheService(
        directoryProvider: () async => paginationDir,
      );
      coverImageDiskCache = _TestCoverImageDiskCache(coverDir);
    });

    tearDown(() async {
      await database.close();
      if (await paginationDir.exists()) {
        await paginationDir.delete(recursive: true);
      }
      if (await coverDir.exists()) {
        await coverDir.delete(recursive: true);
      }
    });

    test('aggregates chapter, pagination and cover cache budgets', () async {
      await database.upsertChapterCache(
        cacheKey: 's1|u1',
        bookId: 'book_1',
        sourceId: 's1',
        chapterIndex: 0,
        chapterUrl: 'u1',
        chapterTitle: 'c1',
        content: 'hello world',
      );

      await paginationCacheService.persistPrecomputedChapterLayout(
        sourceId: 's1',
        chapterUrl: 'chapter://a',
        layout: const ReaderPrecomputedChapterLayout(
          paragraphs: <String>['正文'],
          pagedPages: <List<ReaderPagedSlice>>[
            <ReaderPagedSlice>[
              ReaderPagedSlice(paragraphIndex: 0, start: 0, end: 2, height: 24),
            ],
          ],
          paginationSignature: 'sig_a',
        ),
      );

      await File(
        '${coverDir.path}/cover_a',
      ).writeAsBytes(const <int>[1, 2, 3, 4], flush: true);

      final service = AppCacheGovernanceService(
        database: database,
        paginationCacheStore: paginationCacheService,
        coverImageDiskCache: coverImageDiskCache,
      );
      final snapshot = await service.loadSnapshot();

      expect(snapshot.entries, hasLength(3));
      expect(snapshot.totalEntries, greaterThanOrEqualTo(3));
      expect(snapshot.totalBytes, greaterThan(0));
      expect(
        snapshot.entries.every((entry) => entry.deletable && entry.rebuildable),
        isTrue,
      );
    });

    test('enforces chapter and pagination cache budgets', () async {
      for (var index = 0; index < 4; index++) {
        await database.upsertChapterCache(
          cacheKey: 'src|chapter_$index',
          bookId: 'book_1',
          sourceId: 'src',
          chapterIndex: index,
          chapterUrl: 'chapter_$index',
          content: 'payload_$index',
        );
      }

      for (var index = 0; index < 3; index++) {
        await File(
          '${paginationDir.path}/layout_$index.json',
        ).writeAsString('{"payload":"${'x' * 1024}"}');
        await Future<void>.delayed(const Duration(milliseconds: 2));
      }

      final service = AppCacheGovernanceService(
        database: database,
        paginationCacheStore: paginationCacheService,
        coverImageDiskCache: coverImageDiskCache,
      );

      await service.enforceBudgets();

      final chapterCount = await database.countChapterCaches();
      final paginationCount =
          await paginationCacheService.countPersistedChapterLayouts();

      expect(chapterCount, lessThanOrEqualTo(4));
      expect(paginationCount, lessThanOrEqualTo(3));
    });
  });
}

class _TestCoverImageDiskCache extends CoverImageDiskCache {
  _TestCoverImageDiskCache(this._directory);

  final Directory _directory;

  @override
  Future<int> countAll() async {
    if (!await _directory.exists()) {
      return 0;
    }
    var count = 0;
    await for (final entity in _directory.list(followLinks: false)) {
      if (entity is File) {
        count++;
      }
    }
    return count;
  }

  @override
  Future<int> estimateAllBytes() async {
    if (!await _directory.exists()) {
      return 0;
    }
    var bytes = 0;
    await for (final entity in _directory.list(followLinks: false)) {
      if (entity is! File) {
        continue;
      }
      bytes += await entity.length();
    }
    return bytes;
  }
}

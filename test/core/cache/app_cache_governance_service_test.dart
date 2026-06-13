import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuxiang_reading_next/core/cache/app_cache_governance_service.dart';
import 'package:shuxiang_reading_next/core/cache/cache_budget_policy.dart';
import 'package:shuxiang_reading_next/core/cache/cache_result.dart';
import 'package:shuxiang_reading_next/core/cache/cache_scope.dart';
import 'package:shuxiang_reading_next/core/cache/cover_image_disk_cache.dart';
import 'package:shuxiang_reading_next/core/storage/managed_asset_store.dart';
import 'package:shuxiang_reading_next/data/datasources/local/app_database.dart';
import 'package:shuxiang_reading_next/domain/entities/managed_asset.dart';
import 'package:shuxiang_reading_next/domain/entities/local_book.dart';
import 'package:shuxiang_reading_next/domain/entities/local_chapter.dart';
import 'package:shuxiang_reading_next/features/reader/application/local/local_book_index_cache_store.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_pagination_cache_service.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_pagination_models.dart';

void main() {
  group('AppCacheGovernanceService', () {
    late AppDatabase database;
    late Directory paginationDir;
    late Directory coverDir;
    late ReaderPaginationCacheService paginationCacheService;
    late _TestCoverImageDiskCache coverImageDiskCache;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
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

    test('aggregates unified cache scopes and cover cache budgets', () async {
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

      expect(
        snapshot.entries.map((entry) => entry.scope),
        containsAll(<AppCacheScope>[
          AppCacheScope.chapterContent,
          AppCacheScope.paginationLayout,
          AppCacheScope.coverImage,
          AppCacheScope.apiResponse,
          AppCacheScope.searchHit,
          AppCacheScope.sourceHealth,
        ]),
      );
      expect(snapshot.totalEntries, greaterThanOrEqualTo(3));
      expect(snapshot.totalBytes, greaterThan(0));
      expect(
        snapshot.entries.every((entry) => entry.deletable && entry.rebuildable),
        isTrue,
      );
    });

    test('enforces chapter, pagination and cover cache budgets', () async {
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
      expect(coverImageDiskCache.compactCalls, 1);
      expect(
        coverImageDiskCache.lastCompactMaxEntries,
        AppCacheBudgetPolicies.coverImages.maxEntries,
      );
      expect(
        coverImageDiskCache.lastCompactMaxBytes,
        AppCacheBudgetPolicies.coverImages.maxBytes,
      );
    });

    test(
      'clears rebuildable caches without deleting managed user assets',
      () async {
        await database.upsertChapterCache(
          cacheKey: 'src|chapter',
          bookId: 'book_1',
          sourceId: 'src',
          chapterIndex: 0,
          chapterUrl: 'chapter',
          chapterTitle: 'chapter',
          content: 'payload',
        );
        await File(
          '${paginationDir.path}/layout.json',
        ).writeAsString('{"payload":"cached"}', flush: true);
        await File(
          '${coverDir.path}/cover_a',
        ).writeAsBytes(const <int>[1, 2, 3], flush: true);

        final documentsDir = await Directory.systemTemp.createTemp(
          'cache_governance_docs_',
        );
        final supportDir = await Directory.systemTemp.createTemp(
          'cache_governance_support_',
        );
        try {
          final avatar = await ManagedAssetStore(
            documentsDirectoryProvider: () async => documentsDir,
            supportDirectoryProvider: () async => supportDir,
          ).persistBytes(
            type: ManagedAssetType.profileAvatar,
            scope: ManagedAssetScope.userProfile,
            bytes: const <int>[9, 9, 9],
            fileName: 'avatar.png',
            collectionId: 'user_1',
            targetNamePrefix: 'user_1',
          );
          final themeCoverGallery = await ManagedAssetStore(
            documentsDirectoryProvider: () async => documentsDir,
            supportDirectoryProvider: () async => supportDir,
          ).persistBytes(
            type: ManagedAssetType.coverGalleryImage,
            scope: ManagedAssetScope.themeBinding,
            bytes: const <int>[8, 8, 8],
            fileName: 'theme-cover.png',
            collectionId: 'theme_1',
            targetNamePrefix: 'theme_1',
          );

          final service = AppCacheGovernanceService(
            database: database,
            paginationCacheStore: paginationCacheService,
            coverImageDiskCache: coverImageDiskCache,
          );

          await service.clearRebuildableCaches();

          expect(await database.countChapterCaches(), 0);
          expect(
            await paginationCacheService.countPersistedChapterLayouts(),
            0,
          );
          expect(coverImageDiskCache.clearCalls, 1);
          expect(await File(avatar.resolvedPath!).exists(), isTrue);
          expect(await File(themeCoverGallery.resolvedPath!).exists(), isTrue);
        } finally {
          if (await documentsDir.exists()) {
            await documentsDir.delete(recursive: true);
          }
          if (await supportDir.exists()) {
            await supportDir.delete(recursive: true);
          }
        }
      },
    );

    test('removes stale pagination cache during budget enforcement', () async {
      final staleFile = File('${paginationDir.path}/stale_layout.json');
      await staleFile.writeAsString('{"payload":"old"}', flush: true);
      await staleFile.setLastModified(
        DateTime.now().subtract(const Duration(days: 31)),
      );

      final service = AppCacheGovernanceService(
        database: database,
        paginationCacheStore: paginationCacheService,
        coverImageDiskCache: coverImageDiskCache,
      );

      await service.enforceBudgets();

      expect(await staleFile.exists(), isFalse);
    });

    test('continues other cache cleanup when one path fails', () async {
      final failingPaginationStore = _FailingPaginationLayoutCacheStore();
      final service = AppCacheGovernanceService(
        database: database,
        paginationCacheStore: failingPaginationStore,
        coverImageDiskCache: coverImageDiskCache,
      );

      await service.enforceBudgets();

      expect(failingPaginationStore.pruneCalls, 1);
      expect(coverImageDiskCache.compactCalls, 1);
    });

    test('clears a single cache scope', () async {
      await database.upsertChapterCache(
        cacheKey: 'src|chapter',
        bookId: 'book_1',
        sourceId: 'src',
        chapterIndex: 0,
        chapterUrl: 'chapter',
        chapterTitle: 'chapter',
        content: 'payload',
      );
      await File(
        '${coverDir.path}/cover_a',
      ).writeAsBytes(const <int>[1, 2, 3], flush: true);
      final service = AppCacheGovernanceService(
        database: database,
        paginationCacheStore: paginationCacheService,
        coverImageDiskCache: coverImageDiskCache,
      );

      final result = await service.clearScope(AppCacheScope.chapterContent);

      expect(result.status, AppCacheDeleteStatus.deleted);
      expect(result.deletedEntries, 1);
      expect(await database.countChapterCaches(), 0);
      expect(await coverImageDiskCache.countAll(), 1);
    });

    test(
      'clears local book index without deleting local book metadata',
      () async {
        final now = DateTime.parse('2026-06-13T08:00:00.000Z');
        await database.upsertLocalBook(
          LocalBook(
            id: 'local_book_1',
            title: '本地书',
            format: LocalBookFormat.txt,
            storagePath: '/tmp/local_book_1.txt',
            fileSize: 128,
            indexStatus: LocalBookIndexStatus.ready,
            chapterCount: 1,
            createdAt: now,
            updatedAt: now,
          ),
        );
        await database.replaceLocalChapters(
          bookId: 'local_book_1',
          chapters: <LocalChapter>[
            LocalChapter(
              id: 'local_book_1_chapter_1',
              bookId: 'local_book_1',
              chapterIndex: 0,
              title: '第一章',
              content: '正文',
              createdAt: now,
              updatedAt: now,
            ),
          ],
        );
        final service = AppCacheGovernanceService(
          database: database,
          paginationCacheStore: paginationCacheService,
          coverImageDiskCache: coverImageDiskCache,
          extraStores: <LocalBookIndexCacheStore>[
            LocalBookIndexCacheStore(database: database),
          ],
        );

        final before = await service.loadSnapshot();
        final localIndexBefore = before.entries.singleWhere(
          (entry) => entry.scope == AppCacheScope.localBookIndex,
        );
        final result = await service.clearScope(AppCacheScope.localBookIndex);
        final book = await database.getLocalBookById('local_book_1');

        expect(localIndexBefore.currentEntries, 1);
        expect(result.status, AppCacheDeleteStatus.deleted);
        expect(result.deletedEntries, 1);
        expect(await database.countLocalBookIndexEntries(), 0);
        expect(book, isNotNull);
        expect(book!.indexStatus, LocalBookIndexStatus.stale);
        expect(book.chapterCount, 0);
      },
    );
  });
}

class _TestCoverImageDiskCache extends CoverImageDiskCache {
  _TestCoverImageDiskCache(this._directory);

  final Directory _directory;
  int compactCalls = 0;
  int clearCalls = 0;
  int? lastCompactMaxEntries;
  int? lastCompactMaxBytes;

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

  @override
  Future<int> compact({
    Duration stalePeriod = CoverImageDiskCache.defaultStalePeriod,
    int maxEntries = CoverImageDiskCache.defaultMaxEntries,
    int maxBytes = -1,
  }) async {
    compactCalls += 1;
    lastCompactMaxEntries = maxEntries;
    lastCompactMaxBytes = maxBytes;
    return 0;
  }

  @override
  Future<int> clearAll() async {
    clearCalls += 1;
    final count = await countAll();
    if (await _directory.exists()) {
      await for (final entity in _directory.list(followLinks: false)) {
        if (entity is File) {
          await entity.delete();
        }
      }
    }
    return count;
  }
}

class _FailingPaginationLayoutCacheStore
    implements AppPaginationLayoutCacheStore {
  int pruneCalls = 0;

  @override
  Future<int> countPersistedChapterLayouts() async => 0;

  @override
  Future<int> estimatePersistedChapterLayoutBytes() async => 0;

  @override
  Future<int> prunePersistedChapterLayoutsByBudget({
    required int maxEntries,
    required int maxBytes,
    Duration? stalePeriod,
  }) async {
    pruneCalls += 1;
    throw StateError('pagination cleanup failed');
  }

  @override
  Future<int> clearPersistedChapterLayouts() async {
    throw StateError('pagination clear failed');
  }
}

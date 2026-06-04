import 'dart:developer' as developer;

import '../../data/datasources/local/app_database.dart';
import 'cache_budget_policy.dart';
import 'cover_image_disk_cache.dart';

enum AppCacheKind { chapterCaches, paginationLayouts, coverImages }

class AppCacheGovernanceEntry {
  const AppCacheGovernanceEntry({
    required this.kind,
    required this.label,
    required this.maxEntries,
    required this.maxBytes,
    required this.stalePeriod,
    required this.currentEntries,
    required this.currentBytes,
    required this.deletable,
    required this.rebuildable,
  });

  final AppCacheKind kind;
  final String label;
  final int maxEntries;
  final int maxBytes;
  final Duration stalePeriod;
  final int currentEntries;
  final int currentBytes;
  final bool deletable;
  final bool rebuildable;
}

class AppCacheGovernanceSnapshot {
  const AppCacheGovernanceSnapshot({required this.entries});

  final List<AppCacheGovernanceEntry> entries;

  int get totalEntries =>
      entries.fold<int>(0, (sum, item) => sum + item.currentEntries);

  int get totalBytes =>
      entries.fold<int>(0, (sum, item) => sum + item.currentBytes);
}

abstract interface class AppPaginationLayoutCacheStore {
  Future<int> countPersistedChapterLayouts();

  Future<int> estimatePersistedChapterLayoutBytes();

  Future<int> prunePersistedChapterLayoutsByBudget({
    required int maxEntries,
    required int maxBytes,
    Duration? stalePeriod,
  });

  Future<int> clearPersistedChapterLayouts();
}

class AppCacheGovernanceService {
  AppCacheGovernanceService({
    AppDatabase? database,
    AppPaginationLayoutCacheStore? paginationCacheStore,
    CoverImageDiskCache? coverImageDiskCache,
  }) : _database = database ?? AppDatabase.instance,
       _paginationCacheStore =
           paginationCacheStore ?? const _EmptyPaginationLayoutCacheStore(),
       _coverImageDiskCache =
           coverImageDiskCache ?? CoverImageDiskCache.instance;

  final AppDatabase _database;
  final AppPaginationLayoutCacheStore _paginationCacheStore;
  final CoverImageDiskCache _coverImageDiskCache;

  Future<void> enforceBudgets() async {
    await _runCleanup(
      kind: AppCacheKind.chapterCaches,
      action:
          () => _database.pruneChapterCachesByBudget(
            maxEntries: AppCacheBudgetPolicies.chapterCaches.maxEntries,
            maxBytes: AppCacheBudgetPolicies.chapterCaches.maxBytes,
            stalePeriod: AppCacheBudgetPolicies.chapterCaches.stalePeriod,
          ),
    );
    await _runCleanup(
      kind: AppCacheKind.paginationLayouts,
      action:
          () => _paginationCacheStore.prunePersistedChapterLayoutsByBudget(
            maxEntries: AppCacheBudgetPolicies.paginationLayouts.maxEntries,
            maxBytes: AppCacheBudgetPolicies.paginationLayouts.maxBytes,
            stalePeriod: AppCacheBudgetPolicies.paginationLayouts.stalePeriod,
          ),
    );
    await _runCleanup(
      kind: AppCacheKind.coverImages,
      action:
          () => _coverImageDiskCache.compact(
            maxEntries: AppCacheBudgetPolicies.coverImages.maxEntries,
            maxBytes: AppCacheBudgetPolicies.coverImages.maxBytes,
            stalePeriod: AppCacheBudgetPolicies.coverImages.stalePeriod,
          ),
    );
  }

  Future<void> clearRebuildableCaches() async {
    await _runCleanup(
      kind: AppCacheKind.chapterCaches,
      action: _database.clearChapterCaches,
    );
    await _runCleanup(
      kind: AppCacheKind.paginationLayouts,
      action: _paginationCacheStore.clearPersistedChapterLayouts,
    );
    await _runCleanup(
      kind: AppCacheKind.coverImages,
      action: _coverImageDiskCache.clearAll,
    );
  }

  Future<AppCacheGovernanceSnapshot> loadSnapshot() async {
    final chapterEntries = await _database.countChapterCaches();
    final chapterBytes = await _database.estimateChapterCachesBytes();
    final paginationEntries =
        await _paginationCacheStore.countPersistedChapterLayouts();
    final paginationBytes =
        await _paginationCacheStore.estimatePersistedChapterLayoutBytes();
    final coverEntries = await _coverImageDiskCache.countAll();
    final coverBytes = await _coverImageDiskCache.estimateAllBytes();

    return AppCacheGovernanceSnapshot(
      entries: <AppCacheGovernanceEntry>[
        AppCacheGovernanceEntry(
          kind: AppCacheKind.chapterCaches,
          label: '章节缓存',
          maxEntries: AppCacheBudgetPolicies.chapterCaches.maxEntries,
          maxBytes: AppCacheBudgetPolicies.chapterCaches.maxBytes,
          stalePeriod: AppCacheBudgetPolicies.chapterCaches.stalePeriod,
          currentEntries: chapterEntries,
          currentBytes: chapterBytes,
          deletable: true,
          rebuildable: true,
        ),
        AppCacheGovernanceEntry(
          kind: AppCacheKind.paginationLayouts,
          label: '分页缓存',
          maxEntries: AppCacheBudgetPolicies.paginationLayouts.maxEntries,
          maxBytes: AppCacheBudgetPolicies.paginationLayouts.maxBytes,
          stalePeriod: AppCacheBudgetPolicies.paginationLayouts.stalePeriod,
          currentEntries: paginationEntries,
          currentBytes: paginationBytes,
          deletable: true,
          rebuildable: true,
        ),
        AppCacheGovernanceEntry(
          kind: AppCacheKind.coverImages,
          label: '封面磁盘缓存',
          maxEntries: AppCacheBudgetPolicies.coverImages.maxEntries,
          maxBytes: AppCacheBudgetPolicies.coverImages.maxBytes,
          stalePeriod: AppCacheBudgetPolicies.coverImages.stalePeriod,
          currentEntries: coverEntries,
          currentBytes: coverBytes,
          deletable: true,
          rebuildable: true,
        ),
      ],
    );
  }

  Future<void> _runCleanup({
    required AppCacheKind kind,
    required Future<Object?> Function() action,
  }) async {
    try {
      await action();
    } catch (error, stackTrace) {
      developer.log(
        'Cache cleanup failed and was skipped: ${kind.name}.',
        name: 'app.cache.governance',
        error: error,
        stackTrace: stackTrace,
        level: 900,
      );
    }
  }
}

class _EmptyPaginationLayoutCacheStore
    implements AppPaginationLayoutCacheStore {
  const _EmptyPaginationLayoutCacheStore();

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
    return 0;
  }

  @override
  Future<int> clearPersistedChapterLayouts() async => 0;
}

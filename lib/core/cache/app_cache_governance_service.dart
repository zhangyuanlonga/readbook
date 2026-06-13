import 'dart:developer' as developer;

import '../../data/datasources/local/app_database.dart';
import '../../features/search/application/search_hit_cache_service.dart';
import '../../features/source/application/source_health_persistence_service.dart';
import '../logging/app_logger.dart';
import '../network/api_client.dart';
import 'app_cache_coordinator.dart';
import 'cache_budget_policy.dart';
import 'cache_entry.dart';
import 'cache_key.dart';
import 'cache_policy.dart';
import 'cache_result.dart';
import 'cache_scope.dart';
import 'cache_store.dart';
import 'cover_image_disk_cache.dart';

class AppCacheGovernanceEntry {
  const AppCacheGovernanceEntry({
    required this.scope,
    required this.label,
    required this.currentEntries,
    required this.currentBytes,
    required this.deletable,
    required this.rebuildable,
    this.maxEntries,
    this.maxBytes,
    this.stalePeriod,
    this.backend,
  });

  final AppCacheScope scope;
  final String label;
  final int? maxEntries;
  final int? maxBytes;
  final Duration? stalePeriod;
  final int currentEntries;
  final int currentBytes;
  final bool deletable;
  final bool rebuildable;
  final String? backend;

  bool get overBudget {
    final maxEntries = this.maxEntries;
    final maxBytes = this.maxBytes;
    return (maxEntries != null && currentEntries > maxEntries) ||
        (maxBytes != null && currentBytes > maxBytes);
  }
}

class AppCacheGovernanceSnapshot {
  const AppCacheGovernanceSnapshot({required this.entries});

  final List<AppCacheGovernanceEntry> entries;

  int get totalEntries =>
      entries.fold<int>(0, (sum, item) => sum + item.currentEntries);

  int get totalBytes =>
      entries.fold<int>(0, (sum, item) => sum + item.currentBytes);
}

class AppCacheGovernanceRunSummary {
  const AppCacheGovernanceRunSummary({
    required this.before,
    required this.after,
    required this.cost,
  });

  final AppCacheGovernanceSnapshot before;
  final AppCacheGovernanceSnapshot after;
  final Duration cost;

  int get deletedEntries => before.totalEntries - after.totalEntries;

  int get reclaimedBytes => before.totalBytes - after.totalBytes;
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
    AppCacheCoordinator? cacheCoordinator,
    Iterable<AppCacheStore> extraStores = const <AppCacheStore>[],
    AppLogger? logger,
  }) : _database = database ?? AppDatabase.instance,
       _paginationCacheStore =
           paginationCacheStore ?? const _EmptyPaginationLayoutCacheStore(),
       _coverImageDiskCache =
           coverImageDiskCache ?? CoverImageDiskCache.instance,
       _logger = logger ?? AppLogger.instance {
    _cacheCoordinator =
        cacheCoordinator ??
        AppCacheCoordinator(
          stores: <AppCacheStore>[
            _ChapterContentGovernanceStore(_database),
            _PaginationLayoutGovernanceStore(_paginationCacheStore),
            ApiClient.defaultCacheStore,
            SearchHitCacheService(database: _database),
            SourceHealthPersistenceService(database: _database),
            ...extraStores,
          ],
        );
  }

  final AppDatabase _database;
  final AppPaginationLayoutCacheStore _paginationCacheStore;
  final CoverImageDiskCache _coverImageDiskCache;
  final AppLogger _logger;
  late final AppCacheCoordinator _cacheCoordinator;

  Future<AppCacheGovernanceRunSummary> enforceBudgets({
    bool collectSnapshot = true,
  }) async {
    final stopwatch = Stopwatch()..start();
    final before =
        collectSnapshot
            ? await loadSnapshot()
            : const AppCacheGovernanceSnapshot(
              entries: <AppCacheGovernanceEntry>[],
            );
    await _runCleanup(action: _cacheCoordinator.prune);
    await _runCleanup(
      action:
          () => _coverImageDiskCache.compact(
            maxEntries: AppCacheBudgetPolicies.coverImages.maxEntries,
            maxBytes: AppCacheBudgetPolicies.coverImages.maxBytes,
            stalePeriod: AppCacheBudgetPolicies.coverImages.stalePeriod,
          ),
    );
    final after =
        collectSnapshot
            ? await loadSnapshot()
            : const AppCacheGovernanceSnapshot(
              entries: <AppCacheGovernanceEntry>[],
            );
    final summary = AppCacheGovernanceRunSummary(
      before: before,
      after: after,
      cost: stopwatch.elapsed,
    );
    _logger.info(
      'Cache governance budget enforcement complete',
      context: <String, Object?>{
        'beforeEntries': before.totalEntries,
        'beforeBytes': before.totalBytes,
        'afterEntries': after.totalEntries,
        'afterBytes': after.totalBytes,
        'deletedEntries': summary.deletedEntries,
        'reclaimedBytes': summary.reclaimedBytes,
        'costMs': summary.cost.inMilliseconds,
      },
    );
    return summary;
  }

  Future<void> clearRebuildableCaches() async {
    await _runCleanup(action: _cacheCoordinator.clearRebuildable);
    await _runCleanup(action: _coverImageDiskCache.clearAll);
  }

  Future<AppCacheDeleteResult> clearScope(AppCacheScope scope) async {
    if (scope == AppCacheScope.coverImage) {
      final deleted = await _coverImageDiskCache.clearAll();
      return AppCacheDeleteResult.deleted(
        scope: scope,
        backend: 'flutter_cache_manager.cover_images',
        deletedEntries: deleted,
      );
    }
    final results = await _cacheCoordinator.clearScope(scope: scope);
    return results[scope] ??
        AppCacheDeleteResult.skipped(scope: scope, backend: 'unregistered');
  }

  Future<AppCacheGovernanceSnapshot> loadSnapshot() async {
    final statsByScope = await _cacheCoordinator.stats();
    final entries = <AppCacheGovernanceEntry>[
      for (final stats in statsByScope.values)
        _entryForStats(stats, policy: _cacheCoordinator.policyFor(stats.scope)),
    ];

    if (!statsByScope.containsKey(AppCacheScope.coverImage)) {
      entries.add(
        AppCacheGovernanceEntry(
          scope: AppCacheScope.coverImage,
          label: AppCacheScope.coverImage.label,
          maxEntries: AppCachePolicies.coverImage.maxEntries,
          maxBytes: AppCachePolicies.coverImage.maxBytes,
          stalePeriod: AppCachePolicies.coverImage.ttl,
          currentEntries: await _coverImageDiskCache.countAll(),
          currentBytes: await _coverImageDiskCache.estimateAllBytes(),
          deletable: AppCachePolicies.coverImage.deletable,
          rebuildable: AppCachePolicies.coverImage.rebuildable,
          backend: 'flutter_cache_manager.cover_images',
        ),
      );
    }

    entries.sort(
      (left, right) => left.scope.index.compareTo(right.scope.index),
    );
    return AppCacheGovernanceSnapshot(entries: List.unmodifiable(entries));
  }

  AppCacheGovernanceEntry _entryForStats(
    AppCacheStats stats, {
    required AppCachePolicy policy,
  }) {
    return AppCacheGovernanceEntry(
      scope: stats.scope,
      label: stats.scope.label,
      maxEntries: policy.maxEntries,
      maxBytes: policy.maxBytes,
      stalePeriod: policy.ttl,
      currentEntries: stats.entries,
      currentBytes: stats.bytes,
      deletable: policy.deletable,
      rebuildable: policy.rebuildable,
      backend: stats.backend,
    );
  }

  Future<void> _runCleanup({required Future<Object?> Function() action}) async {
    try {
      await action();
    } catch (error, stackTrace) {
      developer.log(
        'Cache cleanup failed and was skipped.',
        name: 'app.cache.governance',
        error: error,
        stackTrace: stackTrace,
        level: 900,
      );
    }
  }
}

class _ChapterContentGovernanceStore implements AppCacheStore {
  const _ChapterContentGovernanceStore(this._database);

  final AppDatabase _database;

  @override
  AppCacheScope get scope => AppCacheScope.chapterContent;

  @override
  String get backendName => 'drift.chapter_caches';

  @override
  Future<AppCacheReadResult> read(
    AppCacheKey key, {
    AppCachePolicy? policy,
  }) async {
    return AppCacheReadResult.miss(key: key, backend: backendName);
  }

  @override
  Future<AppCacheWriteResult> write(
    AppCacheEntry entry, {
    AppCachePolicy? policy,
  }) async {
    return AppCacheWriteResult.skipped(key: entry.key, backend: backendName);
  }

  @override
  Future<AppCacheDeleteResult> delete(AppCacheKey key) async {
    return AppCacheDeleteResult.skipped(
      scope: scope,
      backend: backendName,
      key: key,
    );
  }

  @override
  Future<AppCacheDeleteResult> clearScope({String? owner}) async {
    final normalizedOwner = owner?.trim() ?? '';
    if (normalizedOwner.isNotEmpty) {
      final before = await _database.getCachedChapterCount(normalizedOwner);
      await _database.deleteChapterCachesByBookId(normalizedOwner);
      return AppCacheDeleteResult.deleted(
        scope: scope,
        backend: backendName,
        deletedEntries: before,
      );
    }
    final before = await _database.countChapterCaches();
    await _database.clearChapterCaches();
    return AppCacheDeleteResult.deleted(
      scope: scope,
      backend: backendName,
      deletedEntries: before,
    );
  }

  @override
  Future<AppCacheStats> stats({String? owner}) async {
    final normalizedOwner = owner?.trim() ?? '';
    if (normalizedOwner.isNotEmpty) {
      return AppCacheStats(
        scope: scope,
        backend: backendName,
        entries: await _database.getCachedChapterCount(normalizedOwner),
        bytes: 0,
      );
    }
    return AppCacheStats(
      scope: scope,
      backend: backendName,
      entries: await _database.countChapterCaches(),
      bytes: await _database.estimateChapterCachesBytes(),
    );
  }

  @override
  Future<AppCachePruneResult> prune(AppCachePolicy policy) async {
    final deleted = await _database.pruneChapterCachesByBudget(
      maxEntries: policy.maxEntries ?? 0,
      maxBytes: policy.maxBytes ?? 0,
      stalePeriod: policy.ttl,
    );
    return AppCachePruneResult(
      scope: scope,
      backend: backendName,
      deletedEntries: deleted,
    );
  }
}

class _PaginationLayoutGovernanceStore implements AppCacheStore {
  const _PaginationLayoutGovernanceStore(this._store);

  final AppPaginationLayoutCacheStore _store;

  @override
  AppCacheScope get scope => AppCacheScope.paginationLayout;

  @override
  String get backendName => 'file.reader_pagination_layouts';

  @override
  Future<AppCacheReadResult> read(
    AppCacheKey key, {
    AppCachePolicy? policy,
  }) async {
    return AppCacheReadResult.miss(key: key, backend: backendName);
  }

  @override
  Future<AppCacheWriteResult> write(
    AppCacheEntry entry, {
    AppCachePolicy? policy,
  }) async {
    return AppCacheWriteResult.skipped(key: entry.key, backend: backendName);
  }

  @override
  Future<AppCacheDeleteResult> delete(AppCacheKey key) async {
    return AppCacheDeleteResult.skipped(
      scope: scope,
      backend: backendName,
      key: key,
    );
  }

  @override
  Future<AppCacheDeleteResult> clearScope({String? owner}) async {
    final deleted = await _store.clearPersistedChapterLayouts();
    return AppCacheDeleteResult.deleted(
      scope: scope,
      backend: backendName,
      deletedEntries: deleted,
    );
  }

  @override
  Future<AppCacheStats> stats({String? owner}) async {
    return AppCacheStats(
      scope: scope,
      backend: backendName,
      entries: await _store.countPersistedChapterLayouts(),
      bytes: await _store.estimatePersistedChapterLayoutBytes(),
    );
  }

  @override
  Future<AppCachePruneResult> prune(AppCachePolicy policy) async {
    final deleted = await _store.prunePersistedChapterLayoutsByBudget(
      maxEntries: policy.maxEntries ?? 0,
      maxBytes: policy.maxBytes ?? 0,
      stalePeriod: policy.ttl,
    );
    return AppCachePruneResult(
      scope: scope,
      backend: backendName,
      deletedEntries: deleted,
    );
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

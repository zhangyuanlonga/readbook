import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/core/cache/app_cache_coordinator.dart';
import 'package:shuxiang_reading_next/core/cache/cache_entry.dart';
import 'package:shuxiang_reading_next/core/cache/cache_key.dart';
import 'package:shuxiang_reading_next/core/cache/cache_policy.dart';
import 'package:shuxiang_reading_next/core/cache/cache_result.dart';
import 'package:shuxiang_reading_next/core/cache/cache_scope.dart';
import 'package:shuxiang_reading_next/core/cache/cache_store.dart';
import 'package:shuxiang_reading_next/core/cache/cache_trace.dart';

void main() {
  group('AppCacheCoordinator', () {
    test('returns miss for unregistered stores and traces the read', () async {
      final logs = <Map<String, Object?>>[];
      final coordinator = AppCacheCoordinator(
        tracer: AppCacheTracer(
          log: (_, {context = const <String, Object?>{}}) {
            logs.add(context);
          },
        ),
      );
      final key = AppCacheKey(scope: AppCacheScope.chapterContent);

      final result = await coordinator.read(key);

      expect(result.status, AppCacheReadStatus.miss);
      expect(result.backend, 'unregistered');
      expect(logs.single['status'], AppCacheReadStatus.miss.name);
    });

    test('reads and writes through the registered store', () async {
      final store = _MemoryCacheStore(AppCacheScope.chapterContent);
      final coordinator = AppCacheCoordinator(
        stores: <AppCacheStore>[store],
        tracer: AppCacheTracer(enabled: false),
      );
      final key = AppCacheKey(
        scope: AppCacheScope.chapterContent,
        owner: 'user_1',
        parts: <String, Object?>{'chapterUrl': 'chapter://1'},
      );
      final now = DateTime(2026, 6, 13);
      final entry = AppCacheEntry(
        key: key,
        payload: '正文',
        createdAt: now,
        updatedAt: now,
        lastAccessedAt: now,
        version: AppCachePolicies.chapterContent.version,
        sizeBytes: 6,
      );

      final writeResult = await coordinator.write(entry);
      final readResult = await coordinator.read(key);

      expect(writeResult.status, AppCacheWriteStatus.written);
      expect(readResult.status, AppCacheReadStatus.hit);
      expect(readResult.entry?.payload, '正文');
    });

    test('surfaces version mismatches from stores', () async {
      final store = _MemoryCacheStore(AppCacheScope.paginationLayout);
      final coordinator = AppCacheCoordinator(
        stores: <AppCacheStore>[store],
        policies: <AppCacheScope, AppCachePolicy>{
          AppCacheScope.paginationLayout: const AppCachePolicy(version: 2),
        },
        tracer: AppCacheTracer(enabled: false),
      );
      final key = AppCacheKey(scope: AppCacheScope.paginationLayout);
      final now = DateTime(2026, 6, 13);
      await store.write(
        AppCacheEntry(
          key: key,
          payload: 'layout',
          createdAt: now,
          updatedAt: now,
          lastAccessedAt: now,
          version: 1,
        ),
      );

      final result = await coordinator.read(key);

      expect(result.status, AppCacheReadStatus.versionMismatch);
      expect(result.invalidReason, AppCacheInvalidReason.versionChanged);
    });

    test('clears only user scoped stores when requested', () async {
      final chapterStore = _MemoryCacheStore(AppCacheScope.chapterContent);
      final coverStore = _MemoryCacheStore(AppCacheScope.coverImage);
      final coordinator = AppCacheCoordinator(
        stores: <AppCacheStore>[chapterStore, coverStore],
        tracer: AppCacheTracer(enabled: false),
      );
      final now = DateTime(2026, 6, 13);
      await coordinator.write(
        AppCacheEntry(
          key: AppCacheKey(
            scope: AppCacheScope.chapterContent,
            owner: 'user_1',
          ),
          payload: 'chapter',
          createdAt: now,
          updatedAt: now,
          lastAccessedAt: now,
        ),
      );
      await coordinator.write(
        AppCacheEntry(
          key: AppCacheKey(scope: AppCacheScope.coverImage, owner: 'global'),
          payload: 'cover',
          createdAt: now,
          updatedAt: now,
          lastAccessedAt: now,
        ),
      );

      final clearResult = await coordinator.clearUserScoped(owner: 'user_1');

      expect(clearResult.keys, contains(AppCacheScope.chapterContent));
      expect(clearResult.keys, isNot(contains(AppCacheScope.coverImage)));
      expect((await chapterStore.stats()).entries, 0);
      expect((await coverStore.stats()).entries, 1);
    });
  });
}

class _MemoryCacheStore implements AppCacheStore {
  _MemoryCacheStore(this.scope);

  @override
  final AppCacheScope scope;

  @override
  String get backendName => 'memory.${scope.name}';

  final Map<String, AppCacheEntry> _entries = <String, AppCacheEntry>{};

  @override
  Future<AppCacheReadResult> read(
    AppCacheKey key, {
    AppCachePolicy? policy,
  }) async {
    final entry = _entries[key.toStorageKey()];
    if (entry == null) {
      return AppCacheReadResult.miss(key: key, backend: backendName);
    }
    final resolvedPolicy = policy ?? const AppCachePolicy();
    if (!entry.hasVersion(resolvedPolicy.version)) {
      return AppCacheReadResult.versionMismatch(
        key: key,
        backend: backendName,
        entry: entry,
      );
    }
    final now = DateTime(2026, 6, 13, 10);
    if (entry.isExpired(now) ||
        resolvedPolicy.isExpired(now, createdAt: entry.createdAt)) {
      return AppCacheReadResult.stale(
        key: key,
        backend: backendName,
        entry: entry,
        invalidReason: AppCacheInvalidReason.ttlExpired,
      );
    }
    return AppCacheReadResult.hit(key: key, backend: backendName, entry: entry);
  }

  @override
  Future<AppCacheWriteResult> write(
    AppCacheEntry entry, {
    AppCachePolicy? policy,
  }) async {
    final resolvedPolicy = policy ?? const AppCachePolicy();
    final expiresAt =
        entry.expiresAt ?? resolvedPolicy.expiresAtFor(entry.createdAt);
    final nextEntry = entry.copyWith(
      expiresAt: expiresAt,
      version: resolvedPolicy.version,
    );
    _entries[entry.key.toStorageKey()] = nextEntry;
    return AppCacheWriteResult.written(
      key: entry.key,
      backend: backendName,
      sizeBytes: entry.sizeBytes,
    );
  }

  @override
  Future<AppCacheDeleteResult> delete(AppCacheKey key) async {
    final removed = _entries.remove(key.toStorageKey());
    return AppCacheDeleteResult.deleted(
      scope: scope,
      backend: backendName,
      key: key,
      deletedEntries: removed == null ? 0 : 1,
      deletedBytes: removed?.sizeBytes ?? 0,
    );
  }

  @override
  Future<AppCacheDeleteResult> clearScope({String? owner}) async {
    final keys =
        _entries.entries
            .where((entry) => owner == null || entry.value.key.owner == owner)
            .map((entry) => entry.key)
            .toList();
    var deletedBytes = 0;
    for (final key in keys) {
      deletedBytes += _entries.remove(key)?.sizeBytes ?? 0;
    }
    return AppCacheDeleteResult.deleted(
      scope: scope,
      backend: backendName,
      deletedEntries: keys.length,
      deletedBytes: deletedBytes,
    );
  }

  @override
  Future<AppCacheStats> stats({String? owner}) async {
    final entries =
        _entries.values
            .where((entry) => owner == null || entry.key.owner == owner)
            .toList();
    return AppCacheStats(
      scope: scope,
      backend: backendName,
      entries: entries.length,
      bytes: entries.fold<int>(0, (sum, entry) => sum + (entry.sizeBytes ?? 0)),
    );
  }

  @override
  Future<AppCachePruneResult> prune(AppCachePolicy policy) async {
    return AppCachePruneResult(scope: scope, backend: backendName);
  }
}

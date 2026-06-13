import '../../../../core/cache/cache_entry.dart';
import '../../../../core/cache/cache_key.dart';
import '../../../../core/cache/cache_policy.dart';
import '../../../../core/cache/cache_result.dart';
import '../../../../core/cache/cache_scope.dart';
import '../../../../core/cache/cache_store.dart';
import '../../../../data/datasources/local/app_database.dart';

class LocalBookIndexCacheStore implements AppCacheStore {
  LocalBookIndexCacheStore({AppDatabase? database})
    : _database = database ?? AppDatabase.instance;

  final AppDatabase _database;

  @override
  AppCacheScope get scope => AppCacheScope.localBookIndex;

  @override
  String get backendName => 'drift.local_book_index';

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
    final deleted = await _database.clearLocalBookIndexCache();
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
      entries: await _database.countLocalBookIndexEntries(),
      bytes: await _database.estimateLocalBookIndexBytes(),
    );
  }

  @override
  Future<AppCachePruneResult> prune(AppCachePolicy policy) async {
    return AppCachePruneResult(scope: scope, backend: backendName);
  }
}

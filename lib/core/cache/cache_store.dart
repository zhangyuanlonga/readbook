import 'cache_entry.dart';
import 'cache_key.dart';
import 'cache_policy.dart';
import 'cache_result.dart';
import 'cache_scope.dart';

abstract interface class AppCacheStore {
  AppCacheScope get scope;

  String get backendName;

  Future<AppCacheReadResult> read(AppCacheKey key, {AppCachePolicy? policy});

  Future<AppCacheWriteResult> write(
    AppCacheEntry entry, {
    AppCachePolicy? policy,
  });

  Future<AppCacheDeleteResult> delete(AppCacheKey key);

  Future<AppCacheDeleteResult> clearScope({String? owner});

  Future<AppCacheStats> stats({String? owner});

  Future<AppCachePruneResult> prune(AppCachePolicy policy);
}

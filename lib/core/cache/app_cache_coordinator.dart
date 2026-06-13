import 'cache_entry.dart';
import 'cache_key.dart';
import 'cache_policy.dart';
import 'cache_result.dart';
import 'cache_scope.dart';
import 'cache_store.dart';
import 'cache_trace.dart';

class AppCacheCoordinator {
  AppCacheCoordinator({
    Iterable<AppCacheStore> stores = const <AppCacheStore>[],
    Map<AppCacheScope, AppCachePolicy> policies = AppCachePolicies.defaults,
    AppCacheTracer? tracer,
  }) : _policies = Map<AppCacheScope, AppCachePolicy>.unmodifiable(policies),
       _tracer = tracer ?? AppCacheTracer() {
    for (final store in stores) {
      _stores[store.scope] = store;
    }
  }

  final Map<AppCacheScope, AppCacheStore> _stores =
      <AppCacheScope, AppCacheStore>{};
  final Map<AppCacheScope, AppCachePolicy> _policies;
  final AppCacheTracer _tracer;

  Iterable<AppCacheScope> get registeredScopes => _stores.keys;

  AppCachePolicy policyFor(AppCacheScope scope) {
    return _policies[scope] ?? const AppCachePolicy();
  }

  void registerStore(AppCacheStore store) {
    _stores[store.scope] = store;
  }

  Future<AppCacheReadResult> read(AppCacheKey key) async {
    final store = _stores[key.scope];
    if (store == null) {
      final result = AppCacheReadResult.miss(key: key, backend: 'unregistered');
      _tracer.traceRead(result);
      return result;
    }
    try {
      final result = await store.read(key, policy: policyFor(key.scope));
      _tracer.traceRead(result);
      return result;
    } catch (error, stackTrace) {
      final result = AppCacheReadResult.backendError(
        key: key,
        backend: store.backendName,
        error: error,
        stackTrace: stackTrace,
      );
      _tracer.traceRead(result);
      return result;
    }
  }

  Future<AppCacheWriteResult> write(AppCacheEntry entry) async {
    final store = _stores[entry.key.scope];
    if (store == null) {
      final result = AppCacheWriteResult.backendError(
        key: entry.key,
        backend: 'unregistered',
        error: StateError('No cache store registered for ${entry.key.scope}'),
      );
      _tracer.traceWrite(result);
      return result;
    }
    try {
      final result = await store.write(
        entry,
        policy: policyFor(entry.key.scope),
      );
      _tracer.traceWrite(result);
      return result;
    } catch (error, stackTrace) {
      final result = AppCacheWriteResult.backendError(
        key: entry.key,
        backend: store.backendName,
        error: error,
        stackTrace: stackTrace,
      );
      _tracer.traceWrite(result);
      return result;
    }
  }

  Future<AppCacheDeleteResult> delete(AppCacheKey key) async {
    final store = _stores[key.scope];
    if (store == null) {
      final result = AppCacheDeleteResult.skipped(
        scope: key.scope,
        backend: 'unregistered',
        key: key,
      );
      _tracer.traceDelete(result);
      return result;
    }
    try {
      final result = await store.delete(key);
      _tracer.traceDelete(result);
      return result;
    } catch (error, stackTrace) {
      final result = AppCacheDeleteResult.backendError(
        scope: key.scope,
        backend: store.backendName,
        key: key,
        error: error,
        stackTrace: stackTrace,
      );
      _tracer.traceDelete(result);
      return result;
    }
  }

  Future<Map<AppCacheScope, AppCacheDeleteResult>> clearScope({
    required AppCacheScope scope,
    String? owner,
  }) async {
    final store = _stores[scope];
    if (store == null) {
      final result = AppCacheDeleteResult.skipped(
        scope: scope,
        backend: 'unregistered',
      );
      _tracer.traceDelete(result);
      return <AppCacheScope, AppCacheDeleteResult>{scope: result};
    }
    try {
      final result = await store.clearScope(owner: owner);
      _tracer.traceDelete(result);
      return <AppCacheScope, AppCacheDeleteResult>{scope: result};
    } catch (error, stackTrace) {
      final result = AppCacheDeleteResult.backendError(
        scope: scope,
        backend: store.backendName,
        error: error,
        stackTrace: stackTrace,
      );
      _tracer.traceDelete(result);
      return <AppCacheScope, AppCacheDeleteResult>{scope: result};
    }
  }

  Future<Map<AppCacheScope, AppCacheDeleteResult>> clearUserScoped({
    String? owner,
  }) {
    return _clearWhere(
      owner: owner,
      shouldClear: (scope, policy) => policy.userScoped,
    );
  }

  Future<Map<AppCacheScope, AppCacheDeleteResult>> clearRebuildable({
    String? owner,
  }) {
    return _clearWhere(
      owner: owner,
      shouldClear: (scope, policy) => policy.rebuildable && policy.deletable,
    );
  }

  Future<Map<AppCacheScope, AppCacheStats>> stats({String? owner}) async {
    final result = <AppCacheScope, AppCacheStats>{};
    for (final entry in _stores.entries) {
      try {
        result[entry.key] = await entry.value.stats(owner: owner);
      } catch (_) {
        result[entry.key] = AppCacheStats(
          scope: entry.key,
          backend: entry.value.backendName,
          entries: 0,
          bytes: 0,
        );
      }
    }
    return result;
  }

  Future<Map<AppCacheScope, AppCachePruneResult>> prune() async {
    final result = <AppCacheScope, AppCachePruneResult>{};
    for (final entry in _stores.entries) {
      late final AppCachePruneResult pruneResult;
      try {
        pruneResult = await entry.value.prune(policyFor(entry.key));
      } catch (_) {
        pruneResult = AppCachePruneResult(
          scope: entry.key,
          backend: entry.value.backendName,
        );
      }
      _tracer.tracePrune(pruneResult);
      result[entry.key] = pruneResult;
    }
    return result;
  }

  Future<Map<AppCacheScope, AppCacheDeleteResult>> _clearWhere({
    required bool Function(AppCacheScope scope, AppCachePolicy policy)
    shouldClear,
    String? owner,
  }) async {
    final result = <AppCacheScope, AppCacheDeleteResult>{};
    for (final entry in _stores.entries) {
      final policy = policyFor(entry.key);
      if (!shouldClear(entry.key, policy)) {
        continue;
      }
      late final AppCacheDeleteResult deleteResult;
      try {
        deleteResult = await entry.value.clearScope(owner: owner);
      } catch (error, stackTrace) {
        deleteResult = AppCacheDeleteResult.backendError(
          scope: entry.key,
          backend: entry.value.backendName,
          error: error,
          stackTrace: stackTrace,
        );
      }
      _tracer.traceDelete(deleteResult);
      result[entry.key] = deleteResult;
    }
    return result;
  }
}

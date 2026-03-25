import 'cache_policy.dart';

class CacheRecord<T> {
  const CacheRecord({
    required this.key,
    required this.sourceId,
    required this.step,
    required this.value,
    required this.createdAt,
    required this.policy,
  });

  final String key;
  final String sourceId;
  final CacheStep step;
  final T value;
  final DateTime createdAt;
  final CachePolicy policy;

  DateTime get expiresAt => createdAt.add(policy.ttl);

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

abstract class CacheManager {
  T? get<T>(String key);
  void put<T>({
    required String key,
    required String sourceId,
    required CacheStep step,
    required T value,
    CachePolicy? policy,
  });
  void invalidateKey(String key);
  void invalidateSource(String sourceId);
  void invalidateStep({required String sourceId, required CacheStep step});
  void clear();
}

class InMemoryCacheManager implements CacheManager {
  final Map<String, CacheRecord<Object?>> _records =
      <String, CacheRecord<Object?>>{};

  List<CacheRecord<Object?>> recordsForSource(String sourceId) {
    _purgeExpired();
    return _records.values
        .where((CacheRecord<Object?> record) => record.sourceId == sourceId)
        .toList(growable: false);
  }

  @override
  T? get<T>(String key) {
    _purgeExpired();
    final record = _records[key];
    if (record == null || record.isExpired) {
      _records.remove(key);
      return null;
    }

    final value = record.value;
    if (value is T) {
      return value;
    }
    return null;
  }

  @override
  void put<T>({
    required String key,
    required String sourceId,
    required CacheStep step,
    required T value,
    CachePolicy? policy,
  }) {
    _records[key] = CacheRecord<Object?>(
      key: key,
      sourceId: sourceId,
      step: step,
      value: value,
      createdAt: DateTime.now(),
      policy: policy ?? CachePolicy.forStep(step),
    );
  }

  @override
  void invalidateKey(String key) {
    _records.remove(key);
  }

  @override
  void invalidateSource(String sourceId) {
    _records.removeWhere(
      (_, CacheRecord<Object?> record) => record.sourceId == sourceId,
    );
  }

  @override
  void invalidateStep({required String sourceId, required CacheStep step}) {
    _records.removeWhere(
      (_, CacheRecord<Object?> record) =>
          record.sourceId == sourceId && record.step == step,
    );
  }

  @override
  void clear() {
    _records.clear();
  }

  void _purgeExpired() {
    _records.removeWhere((_, CacheRecord<Object?> record) => record.isExpired);
  }
}

class CacheStoreContext {
  const CacheStoreContext({required CacheManager cacheManager})
    : _cacheManager = cacheManager;

  final CacheManager _cacheManager;

  T? get<T>(String key) {
    return _cacheManager.get<T>(key);
  }

  void set(
    String key,
    Object? value, {
    required String sourceId,
    CacheStep step = CacheStep.content,
    CachePolicy? policy,
  }) {
    _cacheManager.put<Object?>(
      key: key,
      sourceId: sourceId,
      step: step,
      value: value,
      policy: policy,
    );
  }

  void remove(String key) {
    _cacheManager.invalidateKey(key);
  }

  void clearPrefix(String prefix) {
    if (_cacheManager case final InMemoryCacheManager manager) {
      manager._records.removeWhere(
        (String key, CacheRecord<Object?> _) => key.startsWith(prefix),
      );
      return;
    }
  }
}

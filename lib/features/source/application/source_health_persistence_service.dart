import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/cache/cache_entry.dart';
import '../../../core/cache/cache_key.dart';
import '../../../core/cache/cache_policy.dart';
import '../../../core/cache/cache_result.dart';
import '../../../core/cache/cache_scope.dart';
import '../../../core/cache/cache_store.dart';
import '../../../data/datasources/local/app_database.dart';
import '../../../domain/entities/source_health.dart';

class SourceHealthCacheKeyBuilder {
  const SourceHealthCacheKeyBuilder();

  AppCacheKey build({required String sourceId, String checkMode = 'overall'}) {
    return AppCacheKey(
      scope: AppCacheScope.sourceHealth,
      owner: 'source_health',
      parts: <String, Object?>{'sourceId': sourceId, 'checkMode': checkMode},
    );
  }
}

class SourceHealthPersistenceService implements AppCacheStore {
  SourceHealthPersistenceService({
    SharedPreferences? preferences,
    AppDatabase? database,
  }) : _preferencesFuture =
           preferences == null
               ? SharedPreferences.getInstance()
               : Future.value(preferences),
       _database = database ?? AppDatabase.instance;

  static const String _storageKey = 'source.health.snapshots.v1';
  static const int _schemaVersion = 1;
  static const SourceHealthCacheKeyBuilder keyBuilder =
      SourceHealthCacheKeyBuilder();

  final Future<SharedPreferences> _preferencesFuture;
  final AppDatabase _database;

  Future<Map<String, SourceHealthSnapshot>> loadSnapshots() async {
    final stored = await _database.listSourceHealthSnapshots();
    if (stored.isNotEmpty) {
      return stored;
    }

    final prefs = await _preferencesFuture;
    final raw = (prefs.getString(_storageKey) ?? '').trim();
    if (raw.isEmpty) {
      return <String, SourceHealthSnapshot>{};
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return <String, SourceHealthSnapshot>{};
      }
      final snapshots = <String, SourceHealthSnapshot>{};
      for (final entry in decoded.entries) {
        final sourceId = entry.key.toString().trim();
        final value = entry.value;
        if (sourceId.isEmpty || value is! Map) {
          continue;
        }
        snapshots[sourceId] = SourceHealthSnapshot.fromJson(
          Map<String, dynamic>.from(
            value.map((key, item) => MapEntry(key.toString(), item)),
          ),
        );
      }
      await _database.replaceSourceHealthSnapshots(snapshots);
      await prefs.remove(_storageKey);
      return snapshots;
    } catch (_) {
      return <String, SourceHealthSnapshot>{};
    }
  }

  Future<void> saveSnapshots(
    Map<String, SourceHealthSnapshot> snapshots,
  ) async {
    await _database.replaceSourceHealthSnapshots(snapshots);
    final prefs = await _preferencesFuture;
    await prefs.remove(_storageKey);
  }

  @override
  AppCacheScope get scope => AppCacheScope.sourceHealth;

  @override
  String get backendName => 'drift.source_health_snapshots';

  @override
  Future<AppCacheReadResult> read(
    AppCacheKey key, {
    AppCachePolicy? policy,
  }) async {
    final stopwatch = Stopwatch()..start();
    final sourceId = key.parts['sourceId'] ?? '';
    if (sourceId.isEmpty) {
      return AppCacheReadResult.miss(
        key: key,
        backend: backendName,
        cost: stopwatch.elapsed,
      );
    }
    try {
      final row = await _database.getStoredSourceHealthSnapshot(sourceId);
      if (row == null || row.payloadJson.trim().isEmpty) {
        return AppCacheReadResult.miss(
          key: key,
          backend: backendName,
          cost: stopwatch.elapsed,
        );
      }
      final snapshot = _decodeSnapshot(row.payloadJson);
      final entry = AppCacheEntry(
        key: key,
        payload: snapshot,
        createdAt: row.updatedAt,
        updatedAt: row.updatedAt,
        lastAccessedAt: DateTime.now(),
        expiresAt: (policy ?? AppCachePolicies.sourceHealth).expiresAtFor(
          row.updatedAt,
        ),
        version: _schemaVersion,
        sizeBytes: row.sourceId.length + row.payloadJson.length,
        metadata: <String, Object?>{
          'sourceId': row.sourceId,
          'checkMode': key.parts['checkMode'] ?? 'overall',
          'level': snapshot.level.name,
        },
      );
      final expectedVersion = policy?.version ?? _schemaVersion;
      if (!entry.hasVersion(expectedVersion)) {
        return AppCacheReadResult.versionMismatch(
          key: key,
          backend: backendName,
          entry: entry,
          cost: stopwatch.elapsed,
        );
      }
      if (entry.isExpired(DateTime.now())) {
        return AppCacheReadResult.stale(
          key: key,
          backend: backendName,
          entry: entry,
          invalidReason: AppCacheInvalidReason.ttlExpired,
          cost: stopwatch.elapsed,
        );
      }
      return AppCacheReadResult.hit(
        key: key,
        backend: backendName,
        entry: entry,
        cost: stopwatch.elapsed,
      );
    } on FormatException catch (error, stackTrace) {
      return AppCacheReadResult.decodeFailed(
        key: key,
        backend: backendName,
        error: error,
        stackTrace: stackTrace,
        cost: stopwatch.elapsed,
      );
    } catch (error, stackTrace) {
      return AppCacheReadResult.backendError(
        key: key,
        backend: backendName,
        error: error,
        stackTrace: stackTrace,
        cost: stopwatch.elapsed,
      );
    }
  }

  @override
  Future<AppCacheWriteResult> write(
    AppCacheEntry entry, {
    AppCachePolicy? policy,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      final snapshot = _snapshotFromPayload(entry.payload);
      if (snapshot == null || snapshot.sourceId.trim().isEmpty) {
        return AppCacheWriteResult.skipped(
          key: entry.key,
          backend: backendName,
          cost: stopwatch.elapsed,
        );
      }
      await _database.upsertSourceHealthSnapshot(snapshot);
      return AppCacheWriteResult.written(
        key: entry.key,
        backend: backendName,
        sizeBytes: entry.sizeBytes,
        cost: stopwatch.elapsed,
      );
    } catch (error, stackTrace) {
      return AppCacheWriteResult.backendError(
        key: entry.key,
        backend: backendName,
        error: error,
        stackTrace: stackTrace,
        cost: stopwatch.elapsed,
      );
    }
  }

  @override
  Future<AppCacheDeleteResult> delete(AppCacheKey key) async {
    final stopwatch = Stopwatch()..start();
    try {
      final deleted = await _database.deleteSourceHealthSnapshot(
        key.parts['sourceId'] ?? '',
      );
      return AppCacheDeleteResult.deleted(
        scope: scope,
        backend: backendName,
        key: key,
        deletedEntries: deleted,
        cost: stopwatch.elapsed,
      );
    } catch (error, stackTrace) {
      return AppCacheDeleteResult.backendError(
        scope: scope,
        backend: backendName,
        key: key,
        error: error,
        stackTrace: stackTrace,
        cost: stopwatch.elapsed,
      );
    }
  }

  @override
  Future<AppCacheDeleteResult> clearScope({String? owner}) async {
    final stopwatch = Stopwatch()..start();
    final deleted = await _database.clearSourceHealthSnapshots();
    return AppCacheDeleteResult.deleted(
      scope: scope,
      backend: backendName,
      deletedEntries: deleted,
      cost: stopwatch.elapsed,
    );
  }

  @override
  Future<AppCacheStats> stats({String? owner}) async {
    return AppCacheStats(
      scope: scope,
      backend: backendName,
      entries: await _database.countSourceHealthSnapshots(),
      bytes: await _database.estimateSourceHealthSnapshotsBytes(),
    );
  }

  @override
  Future<AppCachePruneResult> prune(AppCachePolicy policy) async {
    final stopwatch = Stopwatch()..start();
    final deleted = await _database.pruneSourceHealthSnapshotsByBudget(
      maxEntries: policy.maxEntries ?? 0,
      maxBytes: policy.maxBytes ?? 0,
      stalePeriod: policy.ttl,
    );
    return AppCachePruneResult(
      scope: scope,
      backend: backendName,
      deletedEntries: deleted,
      cost: stopwatch.elapsed,
    );
  }

  SourceHealthSnapshot _decodeSnapshot(String payloadJson) {
    final decoded = jsonDecode(payloadJson);
    if (decoded is! Map) {
      throw const FormatException('Invalid source health payload.');
    }
    return SourceHealthSnapshot.fromJson(
      decoded.map((key, value) => MapEntry(key.toString(), value)),
    );
  }

  SourceHealthSnapshot? _snapshotFromPayload(Object? payload) {
    if (payload is SourceHealthSnapshot) {
      return payload;
    }
    if (payload is Map) {
      return SourceHealthSnapshot.fromJson(
        payload.map((key, value) => MapEntry(key.toString(), value)),
      );
    }
    return null;
  }
}

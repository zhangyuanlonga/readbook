import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuxiang_reading_next/core/cache/cache_entry.dart';
import 'package:shuxiang_reading_next/core/cache/cache_policy.dart';
import 'package:shuxiang_reading_next/core/cache/cache_result.dart';
import 'package:shuxiang_reading_next/data/datasources/local/app_database.dart';
import 'package:shuxiang_reading_next/domain/entities/source_health.dart';
import 'package:shuxiang_reading_next/features/source/application/source_health_persistence_service.dart';

void main() {
  group('SourceHealthPersistenceService', () {
    late AppDatabase database;

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      database = AppDatabase(executor: NativeDatabase.memory());
    });

    tearDown(() async {
      await database.close();
    });

    test('migrates legacy SharedPreferences snapshots into database', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'source.health.snapshots.v1',
        '{"source_a":{"sourceId":"source_a","level":"healthy","enabled":true,"totalSuccesses":3}}',
      );
      final service = SourceHealthPersistenceService(
        preferences: prefs,
        database: database,
      );

      final snapshots = await service.loadSnapshots();

      expect(snapshots, hasLength(1));
      expect(snapshots['source_a']?.totalSuccesses, 3);
      expect(prefs.containsKey('source.health.snapshots.v1'), isFalse);

      final stored = await database.listSourceHealthSnapshots();
      expect(stored, hasLength(1));
      expect(stored['source_a']?.level, SourceHealthLevel.healthy);
    });

    test('writes and reads snapshots through AppCacheStore', () async {
      final service = SourceHealthPersistenceService(database: database);
      final key = SourceHealthPersistenceService.keyBuilder.build(
        sourceId: 'source_a',
      );
      final snapshot = SourceHealthSnapshot(
        sourceId: 'source_a',
        level: SourceHealthLevel.warning,
        enabled: true,
        totalFailures: 2,
        lastFailureReason: '解析失败',
      );

      final writeResult = await service.write(
        AppCacheEntry(
          key: key,
          payload: snapshot,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          lastAccessedAt: DateTime.now(),
        ),
        policy: AppCachePolicies.sourceHealth,
      );
      final readResult = await service.read(
        key,
        policy: AppCachePolicies.sourceHealth,
      );

      expect(writeResult.status, AppCacheWriteStatus.written);
      expect(readResult.status, AppCacheReadStatus.hit);
      expect(
        (readResult.entry?.payload as SourceHealthSnapshot).lastFailureReason,
        '解析失败',
      );
      expect((await service.stats()).entries, 1);
    });

    test('returns stale when snapshot exceeds TTL', () async {
      final service = SourceHealthPersistenceService(database: database);
      await service.write(
        AppCacheEntry(
          key: SourceHealthPersistenceService.keyBuilder.build(
            sourceId: 'source_a',
          ),
          payload: const SourceHealthSnapshot(
            sourceId: 'source_a',
            level: SourceHealthLevel.healthy,
            enabled: true,
            totalSuccesses: 3,
          ),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          lastAccessedAt: DateTime.now(),
        ),
        policy: AppCachePolicies.sourceHealth,
      );
      final staleAt = DateTime.now().subtract(const Duration(hours: 13));
      await (database.update(database.storedSourceHealthSnapshots)..where(
        (table) => table.sourceId.equals('source_a'),
      )).write(StoredSourceHealthSnapshotsCompanion(updatedAt: Value(staleAt)));

      final result = await service.read(
        SourceHealthPersistenceService.keyBuilder.build(sourceId: 'source_a'),
        policy: AppCachePolicies.sourceHealth,
      );

      expect(result.status, AppCacheReadStatus.stale);
      expect(result.invalidReason, AppCacheInvalidReason.ttlExpired);
    });

    test('deletes clears and prunes source health snapshots', () async {
      final service = SourceHealthPersistenceService(database: database);
      for (final sourceId in <String>['source_a', 'source_b']) {
        await service.write(
          AppCacheEntry(
            key: SourceHealthPersistenceService.keyBuilder.build(
              sourceId: sourceId,
            ),
            payload: SourceHealthSnapshot(
              sourceId: sourceId,
              level: SourceHealthLevel.healthy,
              enabled: true,
              totalSuccesses: 1,
            ),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            lastAccessedAt: DateTime.now(),
          ),
          policy: AppCachePolicies.sourceHealth,
        );
      }

      expect((await service.stats()).entries, 2);
      final pruneResult = await service.prune(
        const AppCachePolicy(maxEntries: 1, maxBytes: 4096),
      );
      expect(pruneResult.deletedEntries, 1);
      expect((await service.stats()).entries, 1);

      final key = SourceHealthPersistenceService.keyBuilder.build(
        sourceId: 'source_b',
      );
      final deleted = await service.delete(key);
      expect(deleted.deletedEntries, 1);
      expect((await service.stats()).entries, 0);

      await service.write(
        AppCacheEntry(
          key: key,
          payload: const SourceHealthSnapshot(
            sourceId: 'source_b',
            level: SourceHealthLevel.unavailable,
            enabled: true,
            totalFailures: 5,
          ),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          lastAccessedAt: DateTime.now(),
        ),
      );
      final clearResult = await service.clearScope();
      expect(clearResult.deletedEntries, 1);
      expect((await service.stats()).entries, 0);
    });
  });
}

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  });
}

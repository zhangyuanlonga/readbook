import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuxiang_reading_next/data/datasources/local/app_database.dart';
import 'package:shuxiang_reading_next/features/mine/application/remote_access_snapshot_service.dart';

void main() {
  group('RemoteAccessSnapshotService', () {
    late AppDatabase database;

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      database = AppDatabase(executor: NativeDatabase.memory());
    });

    tearDown(() async {
      await database.close();
    });

    test('migrates legacy SharedPreferences snapshot into database', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'remote.access.snapshot.v1.user_1',
        '{"showSourceEntry":true,"hasMembership":true,"hasThemeCustom":false,"sourceImportLimit":42,"cachedAt":"2026-05-21T00:00:00.000Z"}',
      );
      final service = RemoteAccessSnapshotService(
        preferences: prefs,
        database: database,
      );

      final snapshot = await service.load('user_1');

      expect(snapshot, isNotNull);
      expect(snapshot!.showSourceEntry, isTrue);
      expect(snapshot.sourceImportLimit, 42);
      expect(prefs.containsKey('remote.access.snapshot.v1.user_1'), isFalse);

      final stored = await database.getRemoteAccessSnapshot('user_1');
      expect(stored, isNotNull);
      expect(stored!.hasMembership, isTrue);
    });
  });
}

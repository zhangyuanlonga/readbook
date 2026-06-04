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
      expect(snapshot!.serverSourceGatewayEnabled, isTrue);
      expect(snapshot.serverSourceGatewayLimit, 42);
      expect(prefs.containsKey('remote.access.snapshot.v1.user_1'), isFalse);

      final stored = await database.getRemoteAccessSnapshot('user_1');
      expect(stored, isNotNull);
      expect(stored!.hasMembership, isTrue);
      expect(stored.hasThemeCustom, isTrue);
    });

    test('normalizes stale membership snapshot theme access', () async {
      await database.upsertRemoteAccessSnapshot(
        userId: 'user_1',
        serverSourceGatewayEnabled: true,
        hasMembership: true,
        hasThemeCustom: false,
        serverSourceGatewayLimit: 10,
        cachedAt: DateTime.utc(2026, 6, 2),
      );
      final prefs = await SharedPreferences.getInstance();
      final service = RemoteAccessSnapshotService(
        preferences: prefs,
        database: database,
      );

      final snapshot = await service.load('user_1');

      expect(snapshot, isNotNull);
      expect(snapshot!.hasMembership, isTrue);
      expect(snapshot.hasThemeCustom, isTrue);
      final stored = await database.getRemoteAccessSnapshot('user_1');
      expect(stored!.hasThemeCustom, isTrue);
    });

    test(
      'persists membership metadata in database instead of prefs sidecar',
      () async {
        final prefs = await SharedPreferences.getInstance();
        final service = RemoteAccessSnapshotService(
          preferences: prefs,
          database: database,
        );

        await service.save(
          'user_1',
          RemoteAccessSnapshot(
            serverSourceGatewayEnabled: true,
            hasMembership: true,
            hasThemeCustom: true,
            serverSourceGatewayLimit: 12,
            cachedAt: DateTime.utc(2026, 6, 2),
            vipExpireAt: DateTime.utc(2026, 12, 31),
            membershipPlanType: 'premium',
          ),
        );

        final stored = await database.getRemoteAccessSnapshot('user_1');
        expect(stored, isNotNull);
        expect(stored!.vipExpireAt?.toUtc(), DateTime.utc(2026, 12, 31));
        expect(stored.membershipPlanType, 'premium');
        expect(
          prefs.containsKey('remote.access.membership.v1.user_1'),
          isFalse,
        );

        final loaded = await service.load('user_1');
        expect(loaded, isNotNull);
        expect(loaded!.vipExpireAt?.toUtc(), DateTime.utc(2026, 12, 31));
        expect(loaded.membershipPlanType, 'premium');
      },
    );

    test('hydrates and clears legacy membership sidecar', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'remote.access.membership.v1.user_1',
        '{"vipExpireAt":"2026-12-31T00:00:00.000Z","membershipPlanType":"premium"}',
      );
      await database.upsertRemoteAccessSnapshot(
        userId: 'user_1',
        serverSourceGatewayEnabled: true,
        hasMembership: true,
        hasThemeCustom: false,
        serverSourceGatewayLimit: 10,
        cachedAt: DateTime.utc(2026, 6, 2),
      );
      final service = RemoteAccessSnapshotService(
        preferences: prefs,
        database: database,
      );

      final loaded = await service.load('user_1');

      expect(loaded, isNotNull);
      expect(loaded!.vipExpireAt, DateTime.utc(2026, 12, 31));
      expect(loaded.membershipPlanType, 'premium');
      expect(prefs.containsKey('remote.access.membership.v1.user_1'), isFalse);

      final stored = await database.getRemoteAccessSnapshot('user_1');
      expect(stored!.vipExpireAt?.toUtc(), DateTime.utc(2026, 12, 31));
      expect(stored.membershipPlanType, 'premium');
    });
  });
}

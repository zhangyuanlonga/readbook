import 'package:shuxiang_reading_next/features/source/application/source_health_persistence_service.dart';
import 'package:shuxiang_reading_next/domain/entities/source_health.dart';
import 'package:shuxiang_reading_next/features/source/application/source_health_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SourceHealthService', () {
    late SourceHealthService service;

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      service = SourceHealthService();
    });

    test('records success into snapshot', () {
      service.markSearchSuccess(sourceId: 'source_a', latencyMs: 320);

      final snapshot = service.snapshotFor('source_a');
      expect(snapshot.totalSuccesses, 1);
      expect(snapshot.avgSearchLatencyMs, 320);
      expect(snapshot.level, SourceHealthLevel.healthy);
    });

    test('records repeated failure and enters cooldown', () {
      service.markSearchFailure(
        sourceId: 'source_a',
        message: 'browser challenge failed',
        markCooldown: true,
      );
      service.markSearchFailure(
        sourceId: 'source_a',
        message: 'browser challenge failed',
        markCooldown: true,
      );

      final snapshot = service.snapshotFor('source_a');
      expect(snapshot.totalFailures, 2);
      expect(snapshot.coolingDown, isTrue);
      expect(snapshot.level, SourceHealthLevel.unavailable);
    });

    test('hydrates persisted snapshots from storage', () async {
      final prefs = await SharedPreferences.getInstance();
      final persistence = SourceHealthPersistenceService(preferences: prefs);
      await persistence.saveSnapshots(<String, SourceHealthSnapshot>{
        'source_a': SourceHealthSnapshot(
          sourceId: 'source_a',
          level: SourceHealthLevel.warning,
          enabled: true,
          totalFailures: 1,
          lastFailureReason: 'timeout',
          lastFailureKind: SourceHealthFailureKind.timeout,
          lastFailureAt: DateTime.now(),
        ),
      });
      final hydrated = SourceHealthService(persistenceService: persistence);

      await hydrated.hydrate();

      final snapshot = hydrated.snapshotFor('source_a');
      expect(snapshot.totalFailures, 1);
      expect(snapshot.lastFailureKind, SourceHealthFailureKind.timeout);
    });

    test('clears expired cooldown and decays stale failures on read', () {
      service.upsert(
        SourceHealthSnapshot(
          sourceId: 'source_a',
          level: SourceHealthLevel.unavailable,
          enabled: true,
          cooldownUntil: DateTime.now().subtract(const Duration(minutes: 1)),
          totalFailures: 3,
          consecutiveFailures: 2,
          browserRiskCount: 2,
          challengeCount: 1,
          timeoutCount: 1,
          lastFailureReason: 'browser challenge failed',
          lastFailureKind: SourceHealthFailureKind.browserChallenge,
          lastFailureAt: DateTime.now().subtract(const Duration(days: 8)),
        ),
      );

      final snapshot = service.snapshotFor('source_a');
      expect(snapshot.coolingDown, isFalse);
      expect(snapshot.consecutiveFailures, 0);
      expect(snapshot.totalFailures, 0);
      expect(snapshot.browserRiskCount, 0);
      expect(snapshot.challengeCount, 0);
      expect(snapshot.timeoutCount, 0);
      expect(snapshot.lastFailureReason, isNull);
      expect(snapshot.level, SourceHealthLevel.unchecked);
    });
  });
}

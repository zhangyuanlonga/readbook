import 'package:flutter_appread/domain/entities/source_health.dart';
import 'package:flutter_appread/features/source/application/source_health_snapshot_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SourceHealthSnapshotResolver', () {
    const resolver = SourceHealthSnapshotResolver();

    test('marks snapshot healthy after success', () {
      final snapshot = SourceHealthSnapshot(
        sourceId: 'source_1',
        level: SourceHealthLevel.warning,
        enabled: true,
        totalFailures: 1,
        consecutiveFailures: 1,
      );

      final next = resolver.recordSuccess(
        snapshot,
        step: SourceHealthStep.search,
        occurredAt: DateTime.parse('2026-04-05T10:00:00.000Z'),
        latencyMs: 300,
      );

      expect(next.level, SourceHealthLevel.warning);
      expect(next.consecutiveFailures, 0);
      expect(next.avgSearchLatencyMs, 300);
    });

    test('marks snapshot risky after repeated browser failures', () {
      final snapshot = SourceHealthSnapshot(
        sourceId: 'source_1',
        level: SourceHealthLevel.healthy,
        enabled: true,
        totalFailures: 1,
        consecutiveFailures: 1,
        browserRiskCount: 1,
      );

      final next = resolver.recordFailure(
        snapshot,
        failureKind: SourceHealthFailureKind.browserChallenge,
        message: 'captcha required',
        occurredAt: DateTime.parse('2026-04-05T10:00:00.000Z'),
      );

      expect(next.level, SourceHealthLevel.risky);
      expect(next.browserRiskCount, 2);
      expect(next.challengeCount, 1);
    });

    test('marks snapshot unavailable when cooldown is active', () {
      final snapshot = SourceHealthSnapshot(
        sourceId: 'source_1',
        level: SourceHealthLevel.warning,
        enabled: true,
      );

      final next = resolver.recordFailure(
        snapshot,
        failureKind: SourceHealthFailureKind.timeout,
        message: 'timeout',
        occurredAt: DateTime.now(),
        markCooldown: true,
        cooldownUntil: DateTime.now().add(const Duration(minutes: 2)),
      );

      expect(next.level, SourceHealthLevel.unavailable);
      expect(next.coolingDown, isTrue);
    });
  });
}

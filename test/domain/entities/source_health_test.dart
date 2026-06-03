import 'package:shuxiang_reading_next/domain/entities/source_health.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SourceHealthSnapshot', () {
    test('serializes and restores optional fields', () {
      final snapshot = SourceHealthSnapshot(
        sourceId: 'source_1',
        level: SourceHealthLevel.risky,
        enabled: true,
        cooldownUntil: DateTime.parse('2026-04-05T10:00:00.000Z'),
        totalSuccesses: 3,
        totalFailures: 5,
        consecutiveFailures: 2,
        browserRiskCount: 1,
        challengeCount: 1,
        timeoutCount: 2,
        avgSearchLatencyMs: 320,
        avgDetailLatencyMs: 640,
        lastSuccessAt: DateTime.parse('2026-04-05T09:00:00.000Z'),
        lastFailureAt: DateTime.parse('2026-04-05T09:30:00.000Z'),
        lastFailureReason: 'timeout',
        lastFailureKind: SourceHealthFailureKind.timeout,
        userDisabled: false,
        userScoreAdjustment: -2,
      );

      final restored = SourceHealthSnapshot.fromJson(snapshot.toJson());

      expect(restored.sourceId, snapshot.sourceId);
      expect(restored.level, snapshot.level);
      expect(restored.totalFailures, 5);
      expect(restored.avgSearchLatencyMs, 320);
      expect(restored.lastFailureKind, SourceHealthFailureKind.timeout);
      expect(restored.userScoreAdjustment, -2);
    });

    test('copyWith can clear nullable fields with null', () {
      final snapshot = SourceHealthSnapshot(
        sourceId: 'source_1',
        level: SourceHealthLevel.warning,
        enabled: true,
        cooldownUntil: DateTime.parse('2026-04-05T10:00:00.000Z'),
        avgSearchLatencyMs: 320,
        lastFailureAt: DateTime.parse('2026-04-05T09:30:00.000Z'),
        lastFailureReason: 'timeout',
        lastFailureKind: SourceHealthFailureKind.timeout,
      );

      final cleared = snapshot.copyWith(
        cooldownUntil: null,
        avgSearchLatencyMs: null,
        lastFailureAt: null,
        lastFailureReason: null,
        lastFailureKind: null,
      );

      expect(cleared.cooldownUntil, isNull);
      expect(cleared.avgSearchLatencyMs, isNull);
      expect(cleared.lastFailureAt, isNull);
      expect(cleared.lastFailureReason, isNull);
      expect(cleared.lastFailureKind, isNull);
    });
  });
}

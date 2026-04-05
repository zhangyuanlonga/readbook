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
  });
}

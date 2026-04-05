import '../../../domain/entities/source_health.dart';

enum SourceHealthStep {
  search,
  detail,
  chapters,
  content,
  discoverCategories,
  discoverBooks,
  check,
}

class SourceHealthSnapshotResolver {
  const SourceHealthSnapshotResolver();

  SourceHealthSnapshot resolveLevel(SourceHealthSnapshot snapshot) {
    return _resolveLevel(snapshot);
  }

  SourceHealthSnapshot recordSuccess(
    SourceHealthSnapshot snapshot, {
    required SourceHealthStep step,
    required DateTime occurredAt,
    int? latencyMs,
  }) {
    return _resolveLevel(
      snapshot.copyWith(
        totalSuccesses: snapshot.totalSuccesses + 1,
        consecutiveFailures: 0,
        cooldownUntil: null,
        lastSuccessAt: occurredAt,
        avgSearchLatencyMs:
            step == SourceHealthStep.search
                ? _mergeAvg(snapshot.avgSearchLatencyMs, latencyMs)
                : snapshot.avgSearchLatencyMs,
        avgDetailLatencyMs:
            step == SourceHealthStep.detail
                ? _mergeAvg(snapshot.avgDetailLatencyMs, latencyMs)
                : snapshot.avgDetailLatencyMs,
      ),
    );
  }

  SourceHealthSnapshot recordBrowserRiskObservation(
    SourceHealthSnapshot snapshot,
  ) {
    return _resolveLevel(
      snapshot.copyWith(challengeCount: snapshot.challengeCount + 1),
    );
  }

  SourceHealthSnapshot recordFailure(
    SourceHealthSnapshot snapshot, {
    required SourceHealthFailureKind failureKind,
    required String? message,
    required DateTime occurredAt,
    bool markCooldown = false,
    DateTime? cooldownUntil,
  }) {
    return _resolveLevel(
      snapshot.copyWith(
        totalFailures: snapshot.totalFailures + 1,
        consecutiveFailures: snapshot.consecutiveFailures + 1,
        browserRiskCount:
            failureKind == SourceHealthFailureKind.browserChallenge
                ? snapshot.browserRiskCount + 1
                : snapshot.browserRiskCount,
        challengeCount:
            failureKind == SourceHealthFailureKind.browserChallenge
                ? snapshot.challengeCount + 1
                : snapshot.challengeCount,
        timeoutCount:
            failureKind == SourceHealthFailureKind.timeout
                ? snapshot.timeoutCount + 1
                : snapshot.timeoutCount,
        lastFailureAt: occurredAt,
        lastFailureReason: message,
        lastFailureKind: failureKind,
        cooldownUntil: markCooldown ? cooldownUntil : snapshot.cooldownUntil,
      ),
    );
  }

  SourceHealthSnapshot clearCooldown(SourceHealthSnapshot snapshot) {
    return _resolveLevel(
      snapshot.copyWith(cooldownUntil: null, consecutiveFailures: 0),
    );
  }

  SourceHealthSnapshot _resolveLevel(SourceHealthSnapshot snapshot) {
    if (snapshot.userDisabled || snapshot.coolingDown) {
      return snapshot.copyWith(level: SourceHealthLevel.unavailable);
    }
    if (snapshot.totalSuccesses <= 0 && snapshot.totalFailures <= 0) {
      return snapshot.copyWith(level: SourceHealthLevel.unchecked);
    }
    if (snapshot.consecutiveFailures >= 2 || snapshot.browserRiskCount >= 2) {
      return snapshot.copyWith(level: SourceHealthLevel.risky);
    }
    if (snapshot.challengeCount > 0) {
      return snapshot.copyWith(level: SourceHealthLevel.warning);
    }
    if (snapshot.totalFailures > 0) {
      return snapshot.copyWith(level: SourceHealthLevel.warning);
    }
    return snapshot.copyWith(level: SourceHealthLevel.healthy);
  }

  int? _mergeAvg(int? current, int? next) {
    if (next == null) {
      return current;
    }
    if (current == null) {
      return next;
    }
    return ((current + next) / 2).round();
  }
}

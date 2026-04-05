import 'dart:async';

import '../../../domain/entities/source_health.dart';
import 'source_health_persistence_service.dart';
import 'source_health_reason_classifier.dart';
import 'source_health_snapshot_resolver.dart';

class SourceHealthService {
  SourceHealthService({
    SourceHealthSnapshotResolver? snapshotResolver,
    SourceHealthReasonClassifier? reasonClassifier,
    SourceHealthPersistenceService? persistenceService,
  }) : _snapshotResolver =
           snapshotResolver ?? const SourceHealthSnapshotResolver(),
       _reasonClassifier =
           reasonClassifier ?? const SourceHealthReasonClassifier(),
       _persistenceService =
           persistenceService ?? SourceHealthPersistenceService();

  static final SourceHealthService instance = SourceHealthService();

  final SourceHealthSnapshotResolver _snapshotResolver;
  final SourceHealthReasonClassifier _reasonClassifier;
  final SourceHealthPersistenceService _persistenceService;
  final Map<String, SourceHealthSnapshot> _snapshots =
      <String, SourceHealthSnapshot>{};
  Future<void>? _hydrateFuture;
  Timer? _persistDebounceTimer;

  static const Duration _persistDebounce = Duration(milliseconds: 300);
  static const Duration _consecutiveFailureResetAfter = Duration(hours: 6);
  static const Duration _failureDecayAfter = Duration(days: 7);
  static const Duration _staleSnapshotTtl = Duration(days: 30);

  Future<void> hydrate() {
    final existing = _hydrateFuture;
    if (existing != null) {
      return existing;
    }

    final future = _hydrateFromStorage();
    _hydrateFuture = future;
    return future;
  }

  Future<void> persistNow() async {
    _persistDebounceTimer?.cancel();
    await _persistenceService.saveSnapshots(
      _normalizedSnapshotsForPersistence(),
    );
  }

  SourceHealthSnapshot snapshotFor(String sourceId, {bool enabled = true}) {
    final normalizedSourceId = sourceId.trim();
    if (normalizedSourceId.isEmpty) {
      return SourceHealthSnapshot(
        sourceId: normalizedSourceId,
        level: SourceHealthLevel.healthy,
        enabled: enabled,
      );
    }

    final existing = _snapshots[normalizedSourceId];
    if (existing != null) {
      final normalized = _normalizeSnapshot(existing);
      if (normalized == null) {
        _snapshots.remove(normalizedSourceId);
        _schedulePersist();
      } else if (normalized != existing) {
        _snapshots[normalizedSourceId] = normalized;
        _schedulePersist();
      }
      return normalized ??
          SourceHealthSnapshot(
            sourceId: normalizedSourceId,
            level: SourceHealthLevel.healthy,
            enabled: enabled,
          );
    }

    return SourceHealthSnapshot(
      sourceId: normalizedSourceId,
      level: SourceHealthLevel.healthy,
      enabled: enabled,
    );
  }

  Map<String, SourceHealthSnapshot> snapshotsFor(Iterable<String> sourceIds) {
    final result = <String, SourceHealthSnapshot>{};
    for (final sourceId in sourceIds) {
      result[sourceId] = snapshotFor(sourceId);
    }
    return result;
  }

  void markSearchSuccess({
    required String sourceId,
    bool enabled = true,
    int? latencyMs,
  }) {
    final normalizedSourceId = sourceId.trim();
    final current = snapshotFor(normalizedSourceId, enabled: enabled);
    _snapshots[normalizedSourceId] = _snapshotResolver.recordSuccess(
      current,
      step: SourceHealthStep.search,
      occurredAt: DateTime.now(),
      latencyMs: latencyMs,
    );
    _schedulePersist();
  }

  void markSearchFailure({
    required String sourceId,
    required String? message,
    bool enabled = true,
    Object? error,
    bool markCooldown = false,
  }) {
    final normalizedSourceId = sourceId.trim();
    final current = snapshotFor(normalizedSourceId, enabled: enabled);
    final kind = _reasonClassifier.classify(error: error, message: message);
    _snapshots[normalizedSourceId] = _snapshotResolver.recordFailure(
      current,
      failureKind: kind,
      message: message,
      occurredAt: DateTime.now(),
      markCooldown: markCooldown,
      cooldownUntil:
          markCooldown ? DateTime.now().add(const Duration(minutes: 2)) : null,
    );
    _schedulePersist();
  }

  void upsert(SourceHealthSnapshot snapshot) {
    final normalized = _normalizeSnapshot(snapshot);
    if (normalized == null) {
      _snapshots.remove(snapshot.sourceId);
    } else {
      _snapshots[snapshot.sourceId] = normalized;
    }
    _schedulePersist();
  }

  void clear() {
    _snapshots.clear();
    _schedulePersist();
  }

  Future<void> _hydrateFromStorage() async {
    final stored = await _persistenceService.loadSnapshots();
    _snapshots
      ..clear()
      ..addAll(_normalizedSnapshots(stored));
  }

  Map<String, SourceHealthSnapshot> _normalizedSnapshots(
    Map<String, SourceHealthSnapshot> snapshots,
  ) {
    final normalized = <String, SourceHealthSnapshot>{};
    for (final entry in snapshots.entries) {
      final snapshot = _normalizeSnapshot(entry.value);
      if (snapshot == null) {
        continue;
      }
      normalized[entry.key] = snapshot;
    }
    return normalized;
  }

  Map<String, SourceHealthSnapshot> _normalizedSnapshotsForPersistence() {
    final normalized = _normalizedSnapshots(_snapshots);
    _snapshots
      ..clear()
      ..addAll(normalized);
    return normalized;
  }

  SourceHealthSnapshot? _normalizeSnapshot(SourceHealthSnapshot snapshot) {
    final now = DateTime.now();
    final latestActivityAt = _latestActivityAt(snapshot);
    if (latestActivityAt != null &&
        now.difference(latestActivityAt) >= _staleSnapshotTtl) {
      return null;
    }

    var next = snapshot;
    if (!next.coolingDown && next.cooldownUntil != null) {
      next = next.copyWith(cooldownUntil: null, consecutiveFailures: 0);
    }

    final lastFailureAt = next.lastFailureAt;
    if (lastFailureAt != null) {
      final failureAge = now.difference(lastFailureAt);
      if (failureAge >= _consecutiveFailureResetAfter &&
          next.consecutiveFailures != 0) {
        next = next.copyWith(consecutiveFailures: 0);
      }
      if (failureAge >= _failureDecayAfter &&
          (next.totalFailures != 0 ||
              next.browserRiskCount != 0 ||
              next.challengeCount != 0 ||
              next.timeoutCount != 0 ||
              next.lastFailureReason != null ||
              next.lastFailureKind != null)) {
        next = next.copyWith(
          totalFailures: 0,
          browserRiskCount: 0,
          challengeCount: 0,
          timeoutCount: 0,
          lastFailureReason: null,
          lastFailureKind: null,
        );
      }
    }

    return _snapshotResolver.resolveLevel(next);
  }

  DateTime? _latestActivityAt(SourceHealthSnapshot snapshot) {
    final successAt = snapshot.lastSuccessAt;
    final failureAt = snapshot.lastFailureAt;
    if (successAt == null) {
      return failureAt;
    }
    if (failureAt == null) {
      return successAt;
    }
    return successAt.isAfter(failureAt) ? successAt : failureAt;
  }

  void _schedulePersist() {
    _persistDebounceTimer?.cancel();
    _persistDebounceTimer = Timer(_persistDebounce, () {
      unawaited(
        _persistenceService.saveSnapshots(_normalizedSnapshotsForPersistence()),
      );
    });
  }
}

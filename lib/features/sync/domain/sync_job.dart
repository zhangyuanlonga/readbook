enum SyncJobTriggerKind { manual, appStart, foreground }

enum SyncJobStatus { running, success, partial, failed }

class SyncJob {
  const SyncJob({
    required this.id,
    required this.profileId,
    required this.triggerKind,
    required this.status,
    required this.startedAt,
    this.endedAt,
    this.summaryJson,
    this.errorMessage,
  });

  final String id;
  final String profileId;
  final SyncJobTriggerKind triggerKind;
  final SyncJobStatus status;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String? summaryJson;
  final String? errorMessage;

  SyncJob copyWith({
    String? id,
    String? profileId,
    SyncJobTriggerKind? triggerKind,
    SyncJobStatus? status,
    DateTime? startedAt,
    DateTime? endedAt,
    bool clearEndedAt = false,
    String? summaryJson,
    bool clearSummaryJson = false,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return SyncJob(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      triggerKind: triggerKind ?? this.triggerKind,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      endedAt: clearEndedAt ? null : (endedAt ?? this.endedAt),
      summaryJson: clearSummaryJson ? null : (summaryJson ?? this.summaryJson),
      errorMessage:
          clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

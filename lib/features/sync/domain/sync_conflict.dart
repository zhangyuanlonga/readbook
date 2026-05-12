import 'sync_scope.dart';

enum SyncConflictResolution { unresolved, localWon, remoteWon, merged, skipped }

class SyncConflict {
  const SyncConflict({
    required this.id,
    required this.profileId,
    required this.scope,
    required this.recordKey,
    this.basePayloadJson,
    this.localPayloadJson,
    this.remotePayloadJson,
    this.resolution = SyncConflictResolution.unresolved,
    required this.createdAt,
    this.resolvedAt,
  });

  final String id;
  final String profileId;
  final SyncScope scope;
  final String recordKey;
  final String? basePayloadJson;
  final String? localPayloadJson;
  final String? remotePayloadJson;
  final SyncConflictResolution resolution;
  final DateTime createdAt;
  final DateTime? resolvedAt;

  bool get isResolved => resolution != SyncConflictResolution.unresolved;
}

import 'sync_scope.dart';

class SyncScopeState {
  const SyncScopeState({
    required this.profileId,
    required this.scope,
    this.lastBaseSnapshotJson,
    this.lastRemoteRevision,
    this.lastRemoteHash,
    this.lastLocalHash,
    this.lastSyncedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String profileId;
  final SyncScope scope;
  final String? lastBaseSnapshotJson;
  final String? lastRemoteRevision;
  final String? lastRemoteHash;
  final String? lastLocalHash;
  final DateTime? lastSyncedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
}

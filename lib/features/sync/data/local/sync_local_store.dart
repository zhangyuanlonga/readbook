import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../../data/datasources/local/app_database.dart';
import '../../domain/sync_conflict.dart';
import '../../domain/sync_job.dart';
import '../../domain/sync_profile.dart';
import '../../domain/sync_scope.dart';
import '../../domain/sync_scope_state.dart';

class SyncLocalStore {
  SyncLocalStore(this._database);

  final AppDatabase _database;

  Stream<List<SyncProfile>> watchProfiles() {
    return _database.watchAllSyncProfiles().map(
      (rows) => rows.map(_mapProfile).toList(growable: false),
    );
  }

  Future<List<SyncProfile>> listProfiles() async {
    final rows = await _database.getAllSyncProfiles();
    return rows.map(_mapProfile).toList(growable: false);
  }

  Future<SyncProfile?> getProfileById(String id) async {
    final row = await _database.getSyncProfileById(id);
    return row == null ? null : _mapProfile(row);
  }

  Future<void> saveProfile(SyncProfile profile) {
    return _database.upsertSyncProfile(
      StoredSyncProfilesCompanion(
        id: Value(profile.id),
        name: Value(profile.name),
        driverType: Value(profile.driverType.name),
        endpointUrl: Value(profile.endpointUrl),
        basePath: Value(profile.basePath),
        username: Value(profile.username),
        secretRef: Value(profile.secretRef),
        enabledScopesJson: Value(
          jsonEncode(profile.enabledScopes.map((item) => item.name).toList()),
        ),
        scopeConfigJson: Value(profile.scopeConfigJson),
        isAutoSyncEnabled: Value(profile.isAutoSyncEnabled),
        lastSyncAt: Value(profile.lastSyncAt),
        createdAt: Value(profile.createdAt),
        updatedAt: Value(profile.updatedAt),
      ),
    );
  }

  Future<void> deleteProfile(String id) => _database.deleteSyncProfile(id);

  Future<SyncScopeState?> getScopeState({
    required String profileId,
    required SyncScope scope,
  }) async {
    final row = await _database.getSyncScopeState(
      profileId: profileId,
      scope: scope.name,
    );
    return row == null ? null : _mapScopeState(row);
  }

  Future<void> saveScopeState(SyncScopeState state) {
    return _database.upsertSyncScopeState(
      StoredSyncScopeStatesCompanion(
        profileId: Value(state.profileId),
        scope: Value(state.scope.name),
        lastBaseSnapshotJson: Value(state.lastBaseSnapshotJson),
        lastRemoteRevision: Value(state.lastRemoteRevision),
        lastRemoteHash: Value(state.lastRemoteHash),
        lastLocalHash: Value(state.lastLocalHash),
        lastSyncedAt: Value(state.lastSyncedAt),
        createdAt: Value(state.createdAt),
        updatedAt: Value(state.updatedAt),
      ),
    );
  }

  Stream<List<SyncJob>> watchJobs({String? profileId}) {
    return _database
        .watchSyncJobs(profileId: profileId)
        .map((rows) => rows.map(_mapJob).toList(growable: false));
  }

  Future<void> saveJob(SyncJob job) {
    return _database.upsertSyncJob(
      StoredSyncJobsCompanion(
        id: Value(job.id),
        profileId: Value(job.profileId),
        triggerKind: Value(job.triggerKind.name),
        direction: const Value('bidirectional'),
        status: Value(job.status.name),
        startedAt: Value(job.startedAt),
        endedAt: Value(job.endedAt),
        summaryJson: Value(job.summaryJson),
        errorMessage: Value(job.errorMessage),
      ),
    );
  }

  Stream<List<SyncConflict>> watchConflicts({String? profileId}) {
    return _database
        .watchSyncConflicts(profileId: profileId)
        .map((rows) => rows.map(_mapConflict).toList(growable: false));
  }

  Future<void> saveConflict(SyncConflict conflict) {
    return _database.upsertSyncConflict(
      StoredSyncConflictsCompanion(
        id: Value(conflict.id),
        profileId: Value(conflict.profileId),
        scope: Value(conflict.scope.name),
        recordKey: Value(conflict.recordKey),
        basePayloadJson: Value(conflict.basePayloadJson),
        localPayloadJson: Value(conflict.localPayloadJson),
        remotePayloadJson: Value(conflict.remotePayloadJson),
        resolution: Value(conflict.resolution.name),
        createdAt: Value(conflict.createdAt),
        resolvedAt: Value(conflict.resolvedAt),
      ),
    );
  }

  SyncProfile _mapProfile(StoredSyncProfile row) {
    return SyncProfile(
      id: row.id,
      name: row.name,
      driverType: SyncDriverType.values.firstWhere(
        (item) => item.name == row.driverType,
        orElse: () => SyncDriverType.webdav,
      ),
      endpointUrl: row.endpointUrl,
      basePath: row.basePath,
      username: row.username,
      secretRef: _nullableString(row.secretRef),
      enabledScopes: _decodeScopes(row.enabledScopesJson),
      scopeConfigJson: _nullableString(row.scopeConfigJson),
      isAutoSyncEnabled: row.isAutoSyncEnabled,
      lastSyncAt: row.lastSyncAt,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  SyncScopeState _mapScopeState(StoredSyncScopeState row) {
    return SyncScopeState(
      profileId: row.profileId,
      scope: SyncScope.values.firstWhere(
        (item) => item.name == row.scope,
        orElse: () => SyncScope.readingProgress,
      ),
      lastBaseSnapshotJson: _nullableString(row.lastBaseSnapshotJson),
      lastRemoteRevision: _nullableString(row.lastRemoteRevision),
      lastRemoteHash: _nullableString(row.lastRemoteHash),
      lastLocalHash: _nullableString(row.lastLocalHash),
      lastSyncedAt: row.lastSyncedAt,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  SyncJob _mapJob(StoredSyncJob row) {
    return SyncJob(
      id: row.id,
      profileId: row.profileId,
      triggerKind: SyncJobTriggerKind.values.firstWhere(
        (item) => item.name == row.triggerKind,
        orElse: () => SyncJobTriggerKind.manual,
      ),
      status: SyncJobStatus.values.firstWhere(
        (item) => item.name == row.status,
        orElse: () => SyncJobStatus.failed,
      ),
      startedAt: row.startedAt,
      endedAt: row.endedAt,
      summaryJson: _nullableString(row.summaryJson),
      errorMessage: _nullableString(row.errorMessage),
    );
  }

  SyncConflict _mapConflict(StoredSyncConflict row) {
    return SyncConflict(
      id: row.id,
      profileId: row.profileId,
      scope: SyncScope.values.firstWhere(
        (item) => item.name == row.scope,
        orElse: () => SyncScope.readingProgress,
      ),
      recordKey: row.recordKey,
      basePayloadJson: _nullableString(row.basePayloadJson),
      localPayloadJson: _nullableString(row.localPayloadJson),
      remotePayloadJson: _nullableString(row.remotePayloadJson),
      resolution: SyncConflictResolution.values.firstWhere(
        (item) => item.name == row.resolution,
        orElse: () => SyncConflictResolution.unresolved,
      ),
      createdAt: row.createdAt,
      resolvedAt: row.resolvedAt,
    );
  }

  List<SyncScope> _decodeScopes(String raw) {
    final normalized = raw.trim();
    if (normalized.isEmpty) {
      return const <SyncScope>[];
    }
    try {
      final decoded = jsonDecode(normalized);
      if (decoded is! List) {
        return const <SyncScope>[];
      }
      final payload = decoded
          .map((item) => item?.toString().trim() ?? '')
          .where((item) => item.isNotEmpty);
      final scopes = <SyncScope>[];
      for (final item in payload) {
        for (final scope in SyncScope.values) {
          if (scope.name == item) {
            scopes.add(scope);
            break;
          }
        }
      }
      return List<SyncScope>.unmodifiable(scopes);
    } catch (_) {
      return const <SyncScope>[];
    }
  }

  String? _nullableString(String? value) {
    final normalized = (value ?? '').trim();
    return normalized.isEmpty ? null : normalized;
  }
}

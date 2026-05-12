import '../../../core/auth/auth_session_store.dart';
import '../../../core/mobile_features/mobile_feature_module.dart';
import '../../../core/mobile_features/mobile_feature_service.dart';
import '../../mine/application/remote_access_snapshot_service.dart';

class SourcePageFeatureAccess {
  const SourcePageFeatureAccess({
    required this.canAccessSourcePage,
    required this.sourceImportLimit,
    required this.shouldRefreshRemoteAccess,
  });

  final bool canAccessSourcePage;
  final int sourceImportLimit;
  final bool shouldRefreshRemoteAccess;
}

class SourcePageAccessService {
  SourcePageAccessService({
    required AuthSessionStore authSessionStore,
    required MobileFeatureService mobileFeatureService,
    required RemoteAccessSnapshotService remoteAccessSnapshotService,
  }) : _authSessionStore = authSessionStore,
       _mobileFeatureService = mobileFeatureService,
       _remoteAccessSnapshotService = remoteAccessSnapshotService;

  final AuthSessionStore _authSessionStore;
  final MobileFeatureService _mobileFeatureService;
  final RemoteAccessSnapshotService _remoteAccessSnapshotService;

  Future<SourcePageFeatureAccess> loadFeatureAccess({
    bool refreshRemote = true,
  }) async {
    final session = await _authSessionStore.getSession();
    if (!refreshRemote) {
      final snapshot = await _loadSnapshot(session?.userId);
      return _snapshotToAccess(snapshot);
    }
    final modules = await (session == null
            ? _mobileFeatureService.fetchPublicModules()
            : _mobileFeatureService.fetchMyModules())
        .timeout(const Duration(seconds: 5));
    final sourceEntry = _findFeatureModule(modules, 'source_entry');
    final sourceImport = _findFeatureModule(modules, 'source_import');
    if (session?.userId?.trim().isNotEmpty ?? false) {
      await _remoteAccessSnapshotService.saveMergedModules(
        userId: session!.userId!.trim(),
        modules: modules,
      );
      final snapshot = await _loadSnapshot(session.userId);
      return _snapshotToAccess(snapshot);
    }
    return SourcePageFeatureAccess(
      canAccessSourcePage: _isSourceEntryAccessible(sourceEntry),
      sourceImportLimit: sourceImport?.quotaLimit ?? 10,
      shouldRefreshRemoteAccess: false,
    );
  }

  bool canAddSource({
    required bool isLoading,
    required int sourceImportLimit,
    required int currentSourceCount,
  }) {
    if (isLoading) {
      return false;
    }
    if (sourceImportLimit < 0) {
      return true;
    }
    return currentSourceCount < sourceImportLimit;
  }

  int remainingSourceImportSlots({
    required int sourceImportLimit,
    required int currentSourceCount,
  }) {
    if (sourceImportLimit < 0) {
      return -1;
    }
    final remaining = sourceImportLimit - currentSourceCount;
    return remaining < 0 ? 0 : remaining;
  }

  MobileFeatureModule? _findFeatureModule(
    List<MobileFeatureModule> modules,
    String code,
  ) {
    for (final item in modules) {
      if (item.code == code) {
        return item;
      }
    }
    return null;
  }

  bool _isSourceEntryAccessible(MobileFeatureModule? sourceEntry) {
    if (sourceEntry == null) {
      return true;
    }
    return sourceEntry.visible && sourceEntry.enabled;
  }

  SourcePageFeatureAccess get _defaultAccess {
    return const SourcePageFeatureAccess(
      canAccessSourcePage: true,
      sourceImportLimit: 10,
      shouldRefreshRemoteAccess: true,
    );
  }

  Future<RemoteAccessSnapshot?> _loadSnapshot(String? userId) async {
    final normalizedUserId = userId?.trim() ?? '';
    if (normalizedUserId.isEmpty) {
      return null;
    }
    return _remoteAccessSnapshotService.load(normalizedUserId);
  }

  SourcePageFeatureAccess _snapshotToAccess(RemoteAccessSnapshot? snapshot) {
    if (snapshot == null) {
      return _defaultAccess;
    }
    return SourcePageFeatureAccess(
      canAccessSourcePage: snapshot.showSourceEntry,
      sourceImportLimit: snapshot.sourceImportLimit,
      shouldRefreshRemoteAccess: !snapshot.isFresh(),
    );
  }
}

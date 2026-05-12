import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/auth/auth_session.dart';
import '../../../core/auth/auth_session_store.dart';
import '../../../core/media/image_selection_service.dart';
import '../../../core/membership/membership_service.dart';
import '../../../core/mobile_features/mobile_feature_service.dart';
import 'remote_access_snapshot_service.dart';

class MinePageSessionSnapshot {
  const MinePageSessionSnapshot({
    required this.session,
    required this.localAvatarPath,
    required this.showSourceEntry,
    required this.hasMembership,
    required this.hasThemeCustom,
    required this.sourceImportLimit,
    required this.isRemoteAccessResolved,
    required this.shouldRefreshRemoteAccess,
  });

  final AuthSession? session;
  final String? localAvatarPath;
  final bool showSourceEntry;
  final bool hasMembership;
  final bool hasThemeCustom;
  final int sourceImportLimit;
  final bool isRemoteAccessResolved;
  final bool shouldRefreshRemoteAccess;
}

class MinePageSessionPriming {
  MinePageSessionPriming._();

  static AuthSession? _primedSession;

  static void prime(SharedPreferences prefs) {
    _primedSession = AuthSessionStore.readSession(prefs);
  }

  static AuthSession? take() {
    return _primedSession;
  }
}

class MinePageSessionService {
  const MinePageSessionService({
    required AuthSessionStore authSessionStore,
    required MobileFeatureService mobileFeatureService,
    required MembershipService membershipService,
    required RemoteAccessSnapshotService remoteAccessSnapshotService,
  }) : _authSessionStore = authSessionStore,
       _mobileFeatureService = mobileFeatureService,
       _membershipService = membershipService,
       _remoteAccessSnapshotService = remoteAccessSnapshotService;

  final AuthSessionStore _authSessionStore;
  final MobileFeatureService _mobileFeatureService;
  final MembershipService _membershipService;
  final RemoteAccessSnapshotService _remoteAccessSnapshotService;

  Future<MinePageSessionSnapshot> loadSession({
    bool refreshRemote = true,
  }) async {
    final session = await _authSessionStore.getSession();
    if (session == null) {
      return const MinePageSessionSnapshot(
        session: null,
        localAvatarPath: null,
        showSourceEntry: false,
        hasMembership: false,
        hasThemeCustom: false,
        sourceImportLimit: 10,
        isRemoteAccessResolved: true,
        shouldRefreshRemoteAccess: false,
      );
    }

    final localAvatarPath = await loadLocalAvatarPath(session.userId);
    final normalizedUserId = session.userId?.trim() ?? '';
    final cachedRemoteSnapshot =
        normalizedUserId.isEmpty
            ? null
            : await _remoteAccessSnapshotService.load(normalizedUserId);
    if (!refreshRemote) {
      return _buildSnapshot(
        session: session,
        localAvatarPath: localAvatarPath,
        remoteSnapshot: cachedRemoteSnapshot,
      );
    }

    try {
      final modules = await _mobileFeatureService.fetchMyModules();
      final entitlement = await _membershipService.fetchEntitlement();
      final remoteSnapshot = _remoteAccessSnapshotService
          .buildFromModulesAndEntitlement(
            modules: modules,
            entitlement: entitlement,
          );
      if (normalizedUserId.isNotEmpty) {
        await _remoteAccessSnapshotService.save(
          normalizedUserId,
          remoteSnapshot,
        );
      }
      return _buildSnapshot(
        session: session,
        localAvatarPath: localAvatarPath,
        remoteSnapshot: remoteSnapshot,
      );
    } catch (_) {
      return _buildSnapshot(
        session: session,
        localAvatarPath: localAvatarPath,
        remoteSnapshot: cachedRemoteSnapshot,
      );
    }
  }

  Future<String?> loadLocalAvatarPath(String? userId) async {
    final normalizedUserId = userId?.trim() ?? '';
    if (normalizedUserId.isEmpty) {
      return null;
    }
    final prefs = await SharedPreferences.getInstance();
    final rawPath =
        prefs.getString(_profileAvatarStorageKey(normalizedUserId))?.trim();
    if (rawPath == null || rawPath.isEmpty) {
      return null;
    }
    final file = File(rawPath);
    if (await file.exists()) {
      return rawPath;
    }
    await prefs.remove(_profileAvatarStorageKey(normalizedUserId));
    return null;
  }

  Future<String> saveLocalAvatar({
    required String userId,
    required PickedImageData picked,
    String? existingPath,
  }) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final avatarDir = Directory('${docsDir.path}/profile_avatars');
    if (!await avatarDir.exists()) {
      await avatarDir.create(recursive: true);
    }

    final normalizedExistingPath = existingPath?.trim() ?? '';
    if (normalizedExistingPath.isNotEmpty) {
      final existingFile = File(normalizedExistingPath);
      if (await existingFile.exists()) {
        await existingFile.delete();
      }
    }

    final extension = avatarExtensionForName(picked.name);
    final targetPath = '${avatarDir.path}/${userId.trim()}.$extension';
    final targetFile = File(targetPath);
    await targetFile.writeAsBytes(picked.bytes, flush: true);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileAvatarStorageKey(userId.trim()), targetPath);
    return targetPath;
  }

  Future<void> removeLocalAvatar({
    required String userId,
    String? existingPath,
  }) async {
    final normalizedExistingPath = existingPath?.trim() ?? '';
    if (normalizedExistingPath.isNotEmpty) {
      final file = File(normalizedExistingPath);
      if (await file.exists()) {
        await file.delete();
      }
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_profileAvatarStorageKey(userId.trim()));
  }

  Future<String?> restoreLayoutMode(String storageKey) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(storageKey);
  }

  Future<void> persistLayoutMode({
    required String storageKey,
    required String value,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, value);
  }

  String avatarExtensionForName(String fileName) {
    final trimmed = fileName.trim().toLowerCase();
    if (trimmed.endsWith('.png')) {
      return 'png';
    }
    if (trimmed.endsWith('.webp')) {
      return 'webp';
    }
    if (trimmed.endsWith('.jpeg')) {
      return 'jpeg';
    }
    return 'jpg';
  }

  String _profileAvatarStorageKey(String userId) =>
      'mine.profile.avatar.path.$userId';

  MinePageSessionSnapshot _buildSnapshot({
    required AuthSession session,
    required String? localAvatarPath,
    required RemoteAccessSnapshot? remoteSnapshot,
  }) {
    return MinePageSessionSnapshot(
      session: session,
      localAvatarPath: localAvatarPath,
      showSourceEntry: remoteSnapshot?.showSourceEntry ?? false,
      hasMembership: remoteSnapshot?.hasMembership ?? false,
      hasThemeCustom: remoteSnapshot?.hasThemeCustom ?? false,
      sourceImportLimit: remoteSnapshot?.sourceImportLimit ?? 10,
      isRemoteAccessResolved: remoteSnapshot != null,
      shouldRefreshRemoteAccess:
          remoteSnapshot == null || !remoteSnapshot.isFresh(),
    );
  }
}

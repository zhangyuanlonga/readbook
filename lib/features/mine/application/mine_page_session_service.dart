import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/auth/auth_session.dart';
import '../../../core/auth/auth_session_store.dart';
import '../../../core/media/image_selection_service.dart';
import '../../../core/membership/membership_features.dart';
import '../../../core/membership/membership_service.dart';
import '../../../core/mobile_features/mobile_feature_service.dart';
import '../../../core/storage/managed_asset_store.dart';
import '../../../core/user/user_profile.dart';
import '../../../core/user/user_profile_service.dart';
import '../../../data/datasources/local/app_database.dart';
import '../../../domain/entities/managed_asset.dart';
import 'remote_access_snapshot_service.dart';

class MinePageSessionSnapshot {
  const MinePageSessionSnapshot({
    required this.session,
    required this.localAvatarPath,
    required this.serverSourceGatewayEnabled,
    required this.hasMembership,
    required this.hasThemeCustom,
    required this.serverSourceGatewayLimit,
    required this.isRemoteAccessResolved,
    required this.shouldRefreshRemoteAccess,
    required this.vipExpireAt,
    required this.membershipPlanType,
    required this.totalReadingHours,
    required this.readingStreakDays,
  });

  final AuthSession? session;
  final String? localAvatarPath;
  final bool serverSourceGatewayEnabled;
  final bool hasMembership;
  final bool hasThemeCustom;
  final int serverSourceGatewayLimit;
  final bool isRemoteAccessResolved;
  final bool shouldRefreshRemoteAccess;
  final DateTime? vipExpireAt;
  final String? membershipPlanType;
  final int totalReadingHours;
  final int readingStreakDays;
}

class MinePageSessionPriming {
  MinePageSessionPriming._();

  static AuthSession? _primedSession;

  static void prime(SharedPreferences prefs) {
    _primedSession = AuthSessionStore.readDisplaySession(prefs);
  }

  static AuthSession? take() {
    final session = _primedSession;
    _primedSession = null;
    return session;
  }
}

class MinePageSessionService {
  MinePageSessionService({
    required AuthSessionStore authSessionStore,
    required MobileFeatureService mobileFeatureService,
    required MembershipService membershipService,
    required UserProfileService userProfileService,
    required RemoteAccessSnapshotService remoteAccessSnapshotService,
    AppDatabase? database,
    ManagedAssetStore? assetStore,
  }) : _authSessionStore = authSessionStore,
       _mobileFeatureService = mobileFeatureService,
       _membershipService = membershipService,
       _userProfileService = userProfileService,
       _remoteAccessSnapshotService = remoteAccessSnapshotService,
       _database = database ?? AppDatabase.instance,
       _assetStore = assetStore ?? ManagedAssetStore();

  final AuthSessionStore _authSessionStore;
  final MobileFeatureService _mobileFeatureService;
  final MembershipService _membershipService;
  final UserProfileService _userProfileService;
  final RemoteAccessSnapshotService _remoteAccessSnapshotService;
  final AppDatabase _database;
  final ManagedAssetStore _assetStore;

  Future<MinePageSessionSnapshot> loadSession({
    bool refreshRemote = true,
  }) async {
    final persistedSession = await _authSessionStore.getSession();
    final syncedIdentity = await _syncSessionIdentity(persistedSession);
    if (syncedIdentity == null) {
      return const MinePageSessionSnapshot(
        session: null,
        localAvatarPath: null,
        serverSourceGatewayEnabled: false,
        hasMembership: false,
        hasThemeCustom: false,
        serverSourceGatewayLimit: 10,
        isRemoteAccessResolved: true,
        shouldRefreshRemoteAccess: false,
        vipExpireAt: null,
        membershipPlanType: null,
        totalReadingHours: 0,
        readingStreakDays: 0,
      );
    }
    final session = syncedIdentity.session;
    final profile = syncedIdentity.profile;

    final localAvatarPath = await loadLocalAvatarPath(session.userId);
    final readingSummary = await _loadReadingSummary();
    final normalizedUserId = session.userId?.trim() ?? '';
    final cachedRemoteSnapshot =
        normalizedUserId.isEmpty
            ? null
            : await _remoteAccessSnapshotService.load(normalizedUserId);
    if (!refreshRemote) {
      final mergedSnapshot = _mergeProfileMembershipAccess(
        cachedRemoteSnapshot,
        profile,
      );
      return _buildSnapshot(
        session: session,
        localAvatarPath: localAvatarPath,
        remoteSnapshot: mergedSnapshot,
        vipExpireAt: mergedSnapshot?.vipExpireAt?.toLocal(),
        membershipPlanType: mergedSnapshot?.membershipPlanType,
        readingSummary: readingSummary,
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
      final mergedSnapshot =
          _mergeProfileMembershipAccess(remoteSnapshot, profile) ??
          remoteSnapshot;
      if (normalizedUserId.isNotEmpty) {
        await _remoteAccessSnapshotService.save(
          normalizedUserId,
          mergedSnapshot,
        );
      }
      return _buildSnapshot(
        session: session,
        localAvatarPath: localAvatarPath,
        remoteSnapshot: mergedSnapshot,
        vipExpireAt:
            mergedSnapshot.vipExpireAt?.toLocal() ??
            entitlement.expireAt?.toLocal(),
        membershipPlanType: mergedSnapshot.membershipPlanType,
        readingSummary: readingSummary,
      );
    } catch (_) {
      final mergedSnapshot = _mergeProfileMembershipAccess(
        cachedRemoteSnapshot,
        profile,
      );
      return _buildSnapshot(
        session: session,
        localAvatarPath: localAvatarPath,
        remoteSnapshot: mergedSnapshot,
        vipExpireAt: mergedSnapshot?.vipExpireAt?.toLocal(),
        membershipPlanType: mergedSnapshot?.membershipPlanType,
        readingSummary: readingSummary,
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
    final resolvedPath = await _assetStore.resolvePersistedPath(rawPath);
    final file = File(resolvedPath ?? rawPath);
    if (await file.exists()) {
      return file.path;
    }
    await prefs.remove(_profileAvatarStorageKey(normalizedUserId));
    return null;
  }

  Future<String> saveLocalAvatar({
    required String userId,
    required PickedImageData picked,
    String? existingPath,
  }) async {
    // 替换头像必须先清理旧 asset，再登记新 managed relative path；prefs 只存
    // 路径引用，不承载图片字节，避免回滚或缓存清理时误判用户资产位置。
    final normalizedUserId = userId.trim();
    final normalizedExistingPath = existingPath?.trim() ?? '';
    final removablePath =
        normalizedExistingPath.isNotEmpty
            ? normalizedExistingPath
            : await loadLocalAvatarPath(normalizedUserId);
    await _assetStore.deletePath(removablePath);

    final extension = avatarExtensionForName(picked.name);
    final ref = await _assetStore.persistBytes(
      type: ManagedAssetType.profileAvatar,
      scope: ManagedAssetScope.userProfile,
      bytes: picked.bytes,
      fileName:
          '${normalizedUserId.isEmpty ? 'avatar' : normalizedUserId}.$extension',
      collectionId: normalizedUserId,
      assetId: normalizedUserId,
      displayName: picked.name,
      targetNamePrefix: normalizedUserId,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _profileAvatarStorageKey(normalizedUserId),
      ref.relativePath,
    );
    return ref.resolvedPath ??
        await _assetStore.resolvePersistedPath(ref.relativePath) ??
        ref.relativePath;
  }

  /// 用户头像是长期用户资产，保存时只在 prefs 中登记受管相对路径。
  ///
  /// 删除和替换必须先通过 `ManagedAssetStore` 解析旧绝对路径 / 相对路径，以便
  /// 旧版本 Documents/profile_avatars 路径可回收，新版本 policy 路径可迁移。
  Future<void> removeLocalAvatar({
    required String userId,
    String? existingPath,
  }) async {
    final normalizedExistingPath = existingPath?.trim() ?? '';
    final removablePath =
        normalizedExistingPath.isNotEmpty
            ? normalizedExistingPath
            : await loadLocalAvatarPath(userId);
    await _assetStore.deletePath(removablePath);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_profileAvatarStorageKey(userId.trim()));
  }

  Future<void> clearUserScopedCache(String? userId) async {
    final normalizedUserId = userId?.trim() ?? '';
    if (normalizedUserId.isEmpty) {
      return;
    }
    final existingAvatarPath = await loadLocalAvatarPath(normalizedUserId);
    await removeLocalAvatar(
      userId: normalizedUserId,
      existingPath: existingAvatarPath,
    );
    await _remoteAccessSnapshotService.clear(normalizedUserId);
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
    required DateTime? vipExpireAt,
    required String? membershipPlanType,
    required _MineReadingSummary readingSummary,
  }) {
    return MinePageSessionSnapshot(
      session: session,
      localAvatarPath: localAvatarPath,
      serverSourceGatewayEnabled:
          remoteSnapshot?.serverSourceGatewayEnabled ?? false,
      hasMembership: remoteSnapshot?.hasMembership ?? false,
      hasThemeCustom: remoteSnapshot?.hasThemeCustom ?? false,
      serverSourceGatewayLimit: remoteSnapshot?.serverSourceGatewayLimit ?? 10,
      isRemoteAccessResolved: remoteSnapshot != null,
      shouldRefreshRemoteAccess:
          remoteSnapshot == null || !remoteSnapshot.isFresh(),
      vipExpireAt: vipExpireAt,
      membershipPlanType: membershipPlanType,
      totalReadingHours: readingSummary.totalReadingHours,
      readingStreakDays: readingSummary.readingStreakDays,
    );
  }

  RemoteAccessSnapshot? _mergeProfileMembershipAccess(
    RemoteAccessSnapshot? snapshot,
    UserProfile? profile,
  ) {
    if (!MembershipFeatures.hasActiveProfileMembership(profile)) {
      return snapshot;
    }
    final shouldUseProfileMembership = snapshot?.hasMembership != true;
    final merged = (snapshot ?? _defaultProfileMembershipSnapshot()).copyWith(
      hasMembership: true,
      hasThemeCustom:
          snapshot?.hasThemeCustom == true ||
          MembershipFeatures.hasProfileFeature(
            profile,
            MembershipFeatures.themeCustom,
          ),
      vipExpireAt:
          shouldUseProfileMembership
              ? profile?.vipExpireAt
              : snapshot?.vipExpireAt ?? profile?.vipExpireAt,
      membershipPlanType:
          shouldUseProfileMembership
              ? profile?.planType
              : snapshot?.membershipPlanType ?? profile?.planType,
      cachedAt: DateTime.now().toUtc(),
    );
    return merged.normalizedMembershipAccess();
  }

  RemoteAccessSnapshot _defaultProfileMembershipSnapshot() {
    return RemoteAccessSnapshot(
      serverSourceGatewayEnabled: false,
      hasMembership: false,
      hasThemeCustom: false,
      serverSourceGatewayLimit: 10,
      cachedAt: DateTime.now().toUtc(),
    );
  }

  Future<({AuthSession session, UserProfile? profile})?> _syncSessionIdentity(
    AuthSession? session,
  ) async {
    if (session == null) {
      return null;
    }
    try {
      final profile = await _userProfileService.fetchMe();
      final nextSession = AuthSession(
        accessToken: session.accessToken,
        refreshToken: session.refreshToken,
        accessExpiresAt: session.accessExpiresAt,
        refreshExpiresAt: session.refreshExpiresAt,
        userId: profile.userId,
        username: profile.username,
        account: profile.account,
        displayName:
            profile.displayName?.trim().isNotEmpty == true
                ? profile.displayName
                : profile.username,
      );
      if (_isSameIdentity(session, nextSession)) {
        return (session: session, profile: profile);
      }
      await _authSessionStore.saveSession(nextSession);
      return (session: nextSession, profile: profile);
    } catch (_) {
      return (session: session, profile: null);
    }
  }

  bool _isSameIdentity(AuthSession a, AuthSession b) {
    return (a.userId?.trim() ?? '') == (b.userId?.trim() ?? '') &&
        (a.username?.trim() ?? '') == (b.username?.trim() ?? '') &&
        (a.account?.trim() ?? '') == (b.account?.trim() ?? '') &&
        (a.displayName?.trim() ?? '') == (b.displayName?.trim() ?? '');
  }

  Future<_MineReadingSummary> _loadReadingSummary() async {
    final dailyRecords = await _database.listAllReadingRecordDays();
    if (dailyRecords.isEmpty) {
      return const _MineReadingSummary(
        totalReadingHours: 0,
        readingStreakDays: 0,
      );
    }

    final totalMillis = dailyRecords.fold<int>(
      0,
      (sum, item) => sum + (item.readMillis < 0 ? 0 : item.readMillis),
    );
    final dateKeys = dailyRecords
      .map((item) => item.dateKey.trim())
      .where((item) => item.isNotEmpty)
      .toSet()
      .toList(growable: false)..sort();

    return _MineReadingSummary(
      totalReadingHours: Duration(milliseconds: totalMillis).inHours,
      readingStreakDays: _calculateReadingStreakDays(dateKeys),
    );
  }

  int _calculateReadingStreakDays(List<String> sortedDateKeys) {
    if (sortedDateKeys.isEmpty) {
      return 0;
    }

    final today = _dateOnly(DateTime.now());
    final uniqueDates = sortedDateKeys
      .map(DateTime.tryParse)
      .whereType<DateTime>()
      .map(_dateOnly)
      .toSet()
      .toList(growable: false)..sort((a, b) => b.compareTo(a));

    if (uniqueDates.isEmpty) {
      return 0;
    }

    final first = uniqueDates.first;
    if (today.difference(first).inDays > 1) {
      return 0;
    }

    var streak = 0;
    var cursor = first;
    for (final date in uniqueDates) {
      if (_isSameDay(date, cursor)) {
        streak += 1;
        cursor = cursor.subtract(const Duration(days: 1));
        continue;
      }
      break;
    }
    return streak;
  }

  DateTime _dateOnly(DateTime time) {
    final local = time.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _MineReadingSummary {
  const _MineReadingSummary({
    required this.totalReadingHours,
    required this.readingStreakDays,
  });

  final int totalReadingHours;
  final int readingStreakDays;
}

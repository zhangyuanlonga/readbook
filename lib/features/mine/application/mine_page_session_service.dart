import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/auth/auth_session.dart';
import '../../../core/auth/auth_session_store.dart';
import '../../../core/media/image_selection_service.dart';
import '../../../core/membership/membership_service.dart';
import '../../../core/mobile_features/mobile_feature_service.dart';
import '../../../data/datasources/local/app_database.dart';
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
    return _primedSession;
  }
}

class MinePageSessionService {
  MinePageSessionService({
    required AuthSessionStore authSessionStore,
    required MobileFeatureService mobileFeatureService,
    required MembershipService membershipService,
    required RemoteAccessSnapshotService remoteAccessSnapshotService,
    AppDatabase? database,
  }) : _authSessionStore = authSessionStore,
       _mobileFeatureService = mobileFeatureService,
       _membershipService = membershipService,
       _remoteAccessSnapshotService = remoteAccessSnapshotService,
       _database = database ?? AppDatabase.instance;

  final AuthSessionStore _authSessionStore;
  final MobileFeatureService _mobileFeatureService;
  final MembershipService _membershipService;
  final RemoteAccessSnapshotService _remoteAccessSnapshotService;
  final AppDatabase _database;

  Future<MinePageSessionSnapshot> loadSession({
    bool refreshRemote = true,
  }) async {
    final session = await _authSessionStore.getSession();
    if (session == null) {
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

    final localAvatarPath = await loadLocalAvatarPath(session.userId);
    final readingSummary = await _loadReadingSummary();
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
        vipExpireAt: cachedRemoteSnapshot?.vipExpireAt?.toLocal(),
        membershipPlanType: cachedRemoteSnapshot?.membershipPlanType,
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
        vipExpireAt: entitlement.expireAt?.toLocal(),
        membershipPlanType: entitlement.planType,
        readingSummary: readingSummary,
      );
    } catch (_) {
      return _buildSnapshot(
        session: session,
        localAvatarPath: localAvatarPath,
        remoteSnapshot: cachedRemoteSnapshot,
        vipExpireAt: cachedRemoteSnapshot?.vipExpireAt?.toLocal(),
        membershipPlanType: cachedRemoteSnapshot?.membershipPlanType,
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

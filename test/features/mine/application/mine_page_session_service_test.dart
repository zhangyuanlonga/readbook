import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuxiang_reading_next/core/auth/auth_session.dart';
import 'package:shuxiang_reading_next/core/auth/auth_session_secret_store.dart';
import 'package:shuxiang_reading_next/core/auth/auth_session_store.dart';
import 'package:shuxiang_reading_next/core/media/image_selection_service.dart';
import 'package:shuxiang_reading_next/core/membership/membership_entitlement.dart';
import 'package:shuxiang_reading_next/core/membership/membership_service.dart';
import 'package:shuxiang_reading_next/core/mobile_features/mobile_feature_module.dart';
import 'package:shuxiang_reading_next/core/mobile_features/mobile_feature_service.dart';
import 'package:shuxiang_reading_next/core/storage/managed_asset_store.dart';
import 'package:shuxiang_reading_next/core/user/user_profile.dart';
import 'package:shuxiang_reading_next/core/user/user_profile_service.dart';
import 'package:shuxiang_reading_next/data/datasources/local/app_database.dart';
import 'package:shuxiang_reading_next/features/mine/application/mine_page_session_service.dart';
import 'package:shuxiang_reading_next/features/mine/application/remote_access_snapshot_service.dart';

import '../../../test_utils/fake_auth_session_secret_store.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test(
    'prime ignores display-only prefs without token for startup preheat',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'auth.user_id': 'user_prime',
        'auth.username': 'reader_prime',
        'auth.display_name': 'Reader Prime',
      });
      final prefs = await SharedPreferences.getInstance();

      MinePageSessionPriming.prime(prefs);
      final primed = MinePageSessionPriming.take();

      expect(primed, isNull);
    },
  );

  test(
    'prime reads display prefs when a desktop fallback token exists',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        authSecretFallbackAccessTokenStorageKey: 'desktop_access',
        'auth.user_id': 'user_prime',
        'auth.username': 'reader_prime',
        'auth.display_name': 'Reader Prime',
      });
      final prefs = await SharedPreferences.getInstance();

      MinePageSessionPriming.prime(prefs);
      final primed = MinePageSessionPriming.take();

      expect(primed, isNotNull);
      expect(primed?.accessToken, isEmpty);
      expect(primed?.userId, 'user_prime');
      expect(primed?.displayName, 'Reader Prime');
    },
  );

  test(
    'loads session snapshot with membership and source visibility',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final store = AuthSessionStore(
        preferences: prefs,
        secretStore: FakeAuthSessionSecretStore(),
      );
      await store.saveSession(
        const AuthSession(
          accessToken: 'token',
          userId: 'user_1',
          username: 'tester',
        ),
      );

      final service = MinePageSessionService(
        authSessionStore: store,
        mobileFeatureService: _FakeMobileFeatureService(),
        membershipService: _FakeMembershipService(),
        userProfileService: _FakeUserProfileService(
          userId: 'user_1',
          username: 'tester',
          account: 'tester',
          displayName: 'Tester',
        ),
        remoteAccessSnapshotService: RemoteAccessSnapshotService(
          preferences: prefs,
        ),
      );

      final snapshot = await service.loadSession(refreshRemote: true);
      expect(snapshot.session?.userId, 'user_1');
      expect(snapshot.serverSourceGatewayEnabled, isTrue);
      expect(snapshot.hasMembership, isTrue);
      expect(snapshot.hasThemeCustom, isTrue);
      expect(snapshot.serverSourceGatewayLimit, 88);
      expect(snapshot.isRemoteAccessResolved, isTrue);
      expect(snapshot.shouldRefreshRemoteAccess, isFalse);
    },
  );

  test('uses cached remote snapshot when remote refresh is disabled', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = AuthSessionStore(
      preferences: prefs,
      secretStore: FakeAuthSessionSecretStore(),
    );
    await store.saveSession(
      const AuthSession(
        accessToken: 'token',
        userId: 'user_cached',
        username: 'tester',
      ),
    );

    final featureService = _FakeMobileFeatureService();
    final membershipService = _FakeMembershipService();
    final service = MinePageSessionService(
      authSessionStore: store,
      mobileFeatureService: featureService,
      membershipService: membershipService,
      userProfileService: _FakeUserProfileService(
        userId: 'user_cached',
        username: 'tester',
        account: 'tester',
        displayName: 'Tester',
      ),
      remoteAccessSnapshotService: RemoteAccessSnapshotService(
        preferences: prefs,
      ),
    );

    final refreshed = await service.loadSession(refreshRemote: true);
    final cached = await service.loadSession(refreshRemote: false);

    expect(refreshed.hasThemeCustom, isTrue);
    expect(cached.hasThemeCustom, isTrue);
    expect(cached.serverSourceGatewayEnabled, isTrue);
    expect(cached.serverSourceGatewayLimit, 88);
    expect(cached.isRemoteAccessResolved, isTrue);
    expect(cached.shouldRefreshRemoteAccess, isFalse);
    expect(featureService.fetchCount, 1);
    expect(membershipService.fetchCount, 1);
  });

  test('does not let stale profile sync overwrite a newer session', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = AuthSessionStore(
      preferences: prefs,
      secretStore: FakeAuthSessionSecretStore(),
    );
    const oldSession = AuthSession(
      accessToken: 'old_access',
      refreshToken: 'old_refresh',
      userId: 'old_user',
      username: 'old@example.com',
      account: 'old@example.com',
      displayName: 'Old Reader',
    );
    const newSession = AuthSession(
      accessToken: 'new_access',
      refreshToken: 'new_refresh',
      userId: 'new_user',
      username: 'new@example.com',
      account: 'new@example.com',
      displayName: 'New Reader',
    );
    await store.saveSession(oldSession);

    final profileService = _DelayedUserProfileService();
    final service = MinePageSessionService(
      authSessionStore: store,
      mobileFeatureService: _FakeMobileFeatureService(),
      membershipService: _FakeMembershipService(),
      userProfileService: profileService,
      remoteAccessSnapshotService: RemoteAccessSnapshotService(
        preferences: prefs,
      ),
    );

    final loadFuture = service.loadSession(refreshRemote: false);
    await profileService.requestStarted.future;
    expect(profileService.capturedAccessToken, 'old_access');
    expect(profileService.capturedEnableAuthRefresh, isFalse);

    await store.saveSession(newSession);
    profileService.complete(
      UserProfile(
        userId: 'old_user',
        username: 'old@example.com',
        account: 'old@example.com',
        displayName: 'Old Remote Reader',
        phone: null,
        email: null,
        role: null,
        createdAt: null,
        vipLevel: 'none',
        planType: 'month',
        vipStatus: 'expired',
        vipExpireAt: null,
        features: <String>[],
      ),
    );

    final snapshot = await loadFuture;
    final storedSession = await store.getSession();
    expect(storedSession?.userId, 'new_user');
    expect(storedSession?.displayName, 'New Reader');
    expect(storedSession?.accessToken, 'new_access');
    expect(snapshot.session?.userId, 'new_user');
    expect(snapshot.session?.displayName, 'New Reader');
  });

  test(
    'uses account profile membership when entitlement payload is incomplete',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final store = AuthSessionStore(
        preferences: prefs,
        secretStore: FakeAuthSessionSecretStore(),
      );
      await store.saveSession(
        const AuthSession(
          accessToken: 'token',
          userId: 'user_profile_member',
          username: 'tester',
        ),
      );

      final service = MinePageSessionService(
        authSessionStore: store,
        mobileFeatureService: _FakeMobileFeatureService(),
        membershipService: _UnknownMembershipService(),
        userProfileService: _FakeUserProfileService(
          userId: 'user_profile_member',
          username: 'tester',
          account: 'tester',
          displayName: 'Tester',
          vipLevel: 'pro',
          planType: 'lifetime',
          vipStatus: 'active',
        ),
        remoteAccessSnapshotService: RemoteAccessSnapshotService(
          preferences: prefs,
        ),
      );

      final snapshot = await service.loadSession(refreshRemote: true);

      expect(snapshot.hasMembership, isTrue);
      expect(snapshot.hasThemeCustom, isTrue);
      expect(snapshot.membershipPlanType, 'lifetime');
      expect(snapshot.vipExpireAt, isNull);
    },
  );

  test(
    'explicit inactive entitlement is not overridden by stale profile membership',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final store = AuthSessionStore(
        preferences: prefs,
        secretStore: FakeAuthSessionSecretStore(),
      );
      await store.saveSession(
        const AuthSession(
          accessToken: 'token',
          userId: 'user_profile_stale_member',
          username: 'tester',
        ),
      );

      final service = MinePageSessionService(
        authSessionStore: store,
        mobileFeatureService: _FakeMobileFeatureService(),
        membershipService: _InactiveMembershipService(),
        userProfileService: _FakeUserProfileService(
          userId: 'user_profile_stale_member',
          username: 'tester',
          account: 'tester',
          displayName: 'Tester',
          vipLevel: 'pro',
          planType: 'lifetime',
          vipStatus: 'active',
        ),
        remoteAccessSnapshotService: RemoteAccessSnapshotService(
          preferences: prefs,
        ),
      );

      final snapshot = await service.loadSession(refreshRemote: true);

      expect(snapshot.hasMembership, isFalse);
      expect(snapshot.hasThemeCustom, isFalse);
      expect(snapshot.membershipPlanType, isNull);
      expect(snapshot.vipExpireAt, isNull);
    },
  );

  test(
    'remote refresh replaces stale member cache when current account is inactive',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final database = AppDatabase(executor: NativeDatabase.memory());
      addTearDown(database.close);
      final remoteSnapshotService = RemoteAccessSnapshotService(
        preferences: prefs,
        database: database,
      );
      await remoteSnapshotService.save(
        'user_inactive',
        RemoteAccessSnapshot(
          serverSourceGatewayEnabled: true,
          hasMembership: true,
          hasThemeCustom: true,
          serverSourceGatewayLimit: 88,
          cachedAt: DateTime.utc(2026, 6, 1),
          vipExpireAt: DateTime.utc(2026, 12, 31),
          membershipPlanType: 'premium',
        ),
      );
      final store = AuthSessionStore(
        preferences: prefs,
        secretStore: FakeAuthSessionSecretStore(),
      );
      await store.saveSession(
        const AuthSession(
          accessToken: 'token',
          userId: 'user_inactive',
          username: 'tester',
        ),
      );

      final service = MinePageSessionService(
        authSessionStore: store,
        mobileFeatureService: _FakeMobileFeatureService(),
        membershipService: _InactiveMembershipService(),
        userProfileService: _FakeUserProfileService(
          userId: 'user_inactive',
          username: 'tester',
          account: 'tester',
          displayName: 'Tester',
          vipLevel: 'none',
          planType: 'month',
          vipStatus: 'expired',
        ),
        remoteAccessSnapshotService: remoteSnapshotService,
        database: database,
      );

      final snapshot = await service.loadSession(refreshRemote: true);

      expect(snapshot.session?.userId, 'user_inactive');
      expect(snapshot.hasMembership, isFalse);
      expect(snapshot.hasThemeCustom, isFalse);
      expect(snapshot.vipExpireAt, isNull);
      expect(snapshot.membershipPlanType, isNull);

      final cached = await remoteSnapshotService.load('user_inactive');
      expect(cached, isNotNull);
      expect(cached!.hasMembership, isFalse);
      expect(cached.hasThemeCustom, isFalse);
      expect(cached.vipExpireAt, isNull);
      expect(cached.membershipPlanType, isNull);
    },
  );

  test('stores and removes local avatar through managed asset store', () async {
    final prefs = await SharedPreferences.getInstance();
    final documentsDir = await Directory.systemTemp.createTemp(
      'mine_avatar_docs_',
    );
    final supportDir = await Directory.systemTemp.createTemp(
      'mine_avatar_support_',
    );
    try {
      final assetStore = ManagedAssetStore(
        documentsDirectoryProvider: () async => documentsDir,
        supportDirectoryProvider: () async => supportDir,
      );
      final service = MinePageSessionService(
        authSessionStore: AuthSessionStore(
          preferences: prefs,
          secretStore: FakeAuthSessionSecretStore(),
        ),
        mobileFeatureService: _FakeMobileFeatureService(),
        membershipService: _FakeMembershipService(),
        userProfileService: _FakeUserProfileService(
          userId: 'user_avatar',
          username: 'tester',
          account: 'tester',
          displayName: 'Tester',
        ),
        remoteAccessSnapshotService: RemoteAccessSnapshotService(
          preferences: prefs,
        ),
        assetStore: assetStore,
      );

      final legacyFile = File('${documentsDir.path}/profile_avatars/old.jpg');
      await legacyFile.parent.create(recursive: true);
      await legacyFile.writeAsBytes(const <int>[9, 9, 9], flush: true);

      final savedPath = await service.saveLocalAvatar(
        userId: 'user_avatar',
        picked: PickedImageData(
          bytes: Uint8List.fromList(const <int>[1, 2, 3]),
          name: 'avatar.png',
        ),
        existingPath: legacyFile.path,
      );

      expect(await legacyFile.exists(), isFalse);
      expect(await File(savedPath).exists(), isTrue);
      expect(savedPath, contains('profile_avatars'));
      final persistedPath = prefs.getString(
        'mine.profile.avatar.path.user_avatar',
      );
      expect(persistedPath, startsWith('profile_avatars/user_avatar/'));

      final loadedPath = await service.loadLocalAvatarPath('user_avatar');
      expect(
        loadedPath?.replaceAll('\\', '/'),
        savedPath.replaceAll('\\', '/'),
      );

      await service.removeLocalAvatar(userId: 'user_avatar');

      expect(await File(savedPath).exists(), isFalse);
      expect(prefs.getString('mine.profile.avatar.path.user_avatar'), isNull);
    } finally {
      if (await documentsDir.exists()) {
        await documentsDir.delete(recursive: true);
      }
      if (await supportDir.exists()) {
        await supportDir.delete(recursive: true);
      }
    }
  });
}

class _FakeMobileFeatureService extends MobileFeatureService {
  _FakeMobileFeatureService() : super(baseUrl: 'https://example.com');

  int fetchCount = 0;

  @override
  Future<List<MobileFeatureModule>> fetchMyModules() async {
    fetchCount += 1;
    return const [
      MobileFeatureModule(
        code: 'source_entry',
        name: 'source entry',
        description: null,
        category: 'general',
        visible: true,
        enabled: true,
        requiresAuth: false,
        requiresMembership: false,
        requiredFeature: null,
        quotaLimit: -1,
        reason: null,
      ),
      MobileFeatureModule(
        code: 'source_import',
        name: 'source import',
        description: null,
        category: 'general',
        visible: true,
        enabled: true,
        requiresAuth: false,
        requiresMembership: false,
        requiredFeature: null,
        quotaLimit: 88,
        reason: null,
      ),
    ];
  }
}

class _FakeMembershipService extends MembershipService {
  _FakeMembershipService() : super(baseUrl: 'https://example.com');

  int fetchCount = 0;

  @override
  Future<MembershipEntitlement> fetchEntitlement() async {
    fetchCount += 1;
    return const MembershipEntitlement(
      vipLevel: 'pro',
      vipStatus: 'active',
      planType: 'year',
      membershipLevel: 'pro',
      grantType: 'manual_grant',
      grantSubtype: 'test',
      grantLabel: '测试会员',
      isCustomExpire: false,
      expireAt: null,
      source: 'test',
      isTrial: false,
      maxDevices: 3,
      features: ['theme_custom'],
    );
  }
}

class _InactiveMembershipService extends MembershipService {
  _InactiveMembershipService() : super(baseUrl: 'https://example.com');

  @override
  Future<MembershipEntitlement> fetchEntitlement() async {
    return const MembershipEntitlement(
      vipLevel: 'none',
      vipStatus: 'expired',
      planType: 'month',
      membershipLevel: 'none',
      grantType: null,
      grantSubtype: null,
      grantLabel: null,
      isCustomExpire: false,
      expireAt: null,
      source: null,
      isTrial: false,
      maxDevices: 1,
      features: <String>[],
    );
  }
}

class _UnknownMembershipService extends MembershipService {
  _UnknownMembershipService() : super(baseUrl: 'https://example.com');

  @override
  Future<MembershipEntitlement> fetchEntitlement() async {
    return const MembershipEntitlement(
      vipLevel: 'none',
      vipStatus: 'expired',
      planType: 'month',
      membershipLevel: 'none',
      grantType: null,
      grantSubtype: null,
      grantLabel: null,
      isCustomExpire: false,
      expireAt: null,
      source: null,
      isTrial: false,
      maxDevices: 1,
      features: <String>[],
      hasExplicitMembershipState: false,
    );
  }
}

class _DelayedUserProfileService extends UserProfileService {
  _DelayedUserProfileService() : super(baseUrl: 'https://example.com');

  final Completer<void> requestStarted = Completer<void>();
  final Completer<UserProfile> _profileCompleter = Completer<UserProfile>();
  String? capturedAccessToken;
  bool? capturedEnableAuthRefresh;

  void complete(UserProfile profile) {
    _profileCompleter.complete(profile);
  }

  @override
  Future<UserProfile> fetchMe({
    String? accessToken,
    bool enableAuthRefresh = true,
  }) {
    capturedAccessToken = accessToken;
    capturedEnableAuthRefresh = enableAuthRefresh;
    if (!requestStarted.isCompleted) {
      requestStarted.complete();
    }
    return _profileCompleter.future;
  }
}

class _FakeUserProfileService extends UserProfileService {
  _FakeUserProfileService({
    required this.userId,
    required this.username,
    required this.account,
    required this.displayName,
    this.vipLevel,
    this.planType,
    this.vipStatus,
  }) : super(baseUrl: 'https://example.com');

  final String userId;
  final String username;
  final String account;
  final String displayName;
  final String? vipLevel;
  final String? planType;
  final String? vipStatus;

  @override
  Future<UserProfile> fetchMe({
    String? accessToken,
    bool enableAuthRefresh = true,
  }) async {
    return UserProfile(
      userId: userId,
      username: username,
      account: account,
      displayName: displayName,
      phone: null,
      email: null,
      role: null,
      createdAt: null,
      vipLevel: vipLevel,
      planType: planType,
      vipStatus: vipStatus,
      vipExpireAt: null,
      features: <String>[],
    );
  }
}

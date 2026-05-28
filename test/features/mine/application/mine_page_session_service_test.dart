import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuxiang_reading_next/core/auth/auth_session.dart';
import 'package:shuxiang_reading_next/core/auth/auth_session_store.dart';
import 'package:shuxiang_reading_next/core/membership/membership_entitlement.dart';
import 'package:shuxiang_reading_next/core/membership/membership_service.dart';
import 'package:shuxiang_reading_next/core/mobile_features/mobile_feature_module.dart';
import 'package:shuxiang_reading_next/core/mobile_features/mobile_feature_service.dart';
import 'package:shuxiang_reading_next/core/user/user_profile.dart';
import 'package:shuxiang_reading_next/core/user/user_profile_service.dart';
import 'package:shuxiang_reading_next/features/mine/application/mine_page_session_service.dart';
import 'package:shuxiang_reading_next/features/mine/application/remote_access_snapshot_service.dart';

import '../../../test_utils/fake_auth_session_secret_store.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test(
    'prime reads display-only prefs without token for startup preheat',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
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

  test('persists and restores layout mode', () async {
    final service = MinePageSessionService(
      authSessionStore: AuthSessionStore(
        secretStore: FakeAuthSessionSecretStore(),
      ),
      mobileFeatureService: _FakeMobileFeatureService(),
      membershipService: _FakeMembershipService(),
      userProfileService: _FakeUserProfileService(
        userId: 'layout_user',
        username: 'layout_user',
        account: 'layout_user',
        displayName: 'Layout User',
      ),
      remoteAccessSnapshotService: RemoteAccessSnapshotService(),
    );

    await service.persistLayoutMode(storageKey: 'layout', value: 'grid');
    expect(await service.restoreLayoutMode('layout'), 'grid');
  });

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

class _FakeUserProfileService extends UserProfileService {
  _FakeUserProfileService({
    required this.userId,
    required this.username,
    required this.account,
    required this.displayName,
  }) : super(baseUrl: 'https://example.com');

  final String userId;
  final String username;
  final String account;
  final String displayName;

  @override
  Future<UserProfile> fetchMe() async {
    return UserProfile(
      userId: userId,
      username: username,
      account: account,
      displayName: displayName,
      phone: null,
      email: null,
      role: null,
      createdAt: null,
      vipLevel: null,
      planType: null,
      vipStatus: null,
      vipExpireAt: null,
      features: <String>[],
    );
  }
}

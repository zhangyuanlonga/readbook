import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuxiang_reading_next/core/auth/auth_session.dart';
import 'package:shuxiang_reading_next/core/auth/auth_session_store.dart';
import 'package:shuxiang_reading_next/core/membership/membership_entitlement.dart';
import 'package:shuxiang_reading_next/core/membership/membership_service.dart';
import 'package:shuxiang_reading_next/core/mobile_features/mobile_feature_module.dart';
import 'package:shuxiang_reading_next/core/mobile_features/mobile_feature_service.dart';
import 'package:shuxiang_reading_next/features/mine/application/mine_page_session_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test(
    'loads session snapshot with membership and source visibility',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final store = AuthSessionStore(preferences: prefs);
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
      );

      final snapshot = await service.loadSession();
      expect(snapshot.session?.userId, 'user_1');
      expect(snapshot.showSourceEntry, isTrue);
      expect(snapshot.hasMembership, isTrue);
      expect(snapshot.hasThemeCustom, isTrue);
      expect(snapshot.sourceImportLimit, 88);
    },
  );

  test('persists and restores layout mode', () async {
    final service = MinePageSessionService(
      authSessionStore: AuthSessionStore(),
      mobileFeatureService: _FakeMobileFeatureService(),
      membershipService: _FakeMembershipService(),
    );

    await service.persistLayoutMode(storageKey: 'layout', value: 'grid');
    expect(await service.restoreLayoutMode('layout'), 'grid');
  });
}

class _FakeMobileFeatureService extends MobileFeatureService {
  _FakeMobileFeatureService() : super(baseUrl: 'https://example.com');

  @override
  Future<List<MobileFeatureModule>> fetchMyModules() async {
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

  @override
  Future<MembershipEntitlement> fetchEntitlement() async {
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

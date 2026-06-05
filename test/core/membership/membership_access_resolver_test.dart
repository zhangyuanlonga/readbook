import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuxiang_reading_next/core/auth/auth_session.dart';
import 'package:shuxiang_reading_next/core/auth/auth_session_store.dart';
import 'package:shuxiang_reading_next/core/errors/app_exception.dart';
import 'package:shuxiang_reading_next/core/errors/error_codes.dart';
import 'package:shuxiang_reading_next/core/errors/error_stage.dart';
import 'package:shuxiang_reading_next/core/membership/membership_access_resolver.dart';
import 'package:shuxiang_reading_next/core/membership/membership_access_service.dart';
import 'package:shuxiang_reading_next/core/membership/membership_entitlement.dart';
import 'package:shuxiang_reading_next/core/membership/membership_service.dart';
import 'package:shuxiang_reading_next/core/user/user_profile.dart';
import 'package:shuxiang_reading_next/core/user/user_profile_service.dart';

import '../../test_utils/fake_auth_session_secret_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('membership_active true wins over inactive legacy fields', () {
    final access = MembershipAccessResolver.fromEntitlement(
      MembershipEntitlement.fromJson(<String, dynamic>{
        'membership_active': true,
        'vip_level': 'none',
        'vip_status': 'expired',
        'features': const <String>[],
      }),
    );

    expect(access.hasMembership, isTrue);
    expect(access.hasOnlineService, isTrue);
    expect(access.hasThemeCustom, isTrue);
  });

  test(
    'explicit inactive entitlement is not overridden by profile or session',
    () {
      final access = MembershipAccessResolver.resolve(
        session: const AuthSession(
          accessToken: 'token',
          membershipActive: true,
          vipLevel: 'pro',
          vipStatus: 'active',
        ),
        profile: _profile(
          membershipActive: true,
          vipLevel: 'pro',
          vipStatus: 'active',
        ),
        entitlement: const MembershipEntitlement(
          vipLevel: 'none',
          vipStatus: 'expired',
          planType: 'month',
          expireAt: null,
          source: null,
          membershipLevel: 'none',
          grantType: null,
          grantSubtype: null,
          grantLabel: null,
          isCustomExpire: false,
          isTrial: false,
          maxDevices: 1,
          features: <String>[],
          membershipActive: false,
        ),
      );

      expect(access.hasExplicitMembershipState, isTrue);
      expect(access.hasMembership, isFalse);
      expect(access.hasOnlineService, isFalse);
    },
  );

  test('unknown entitlement falls back to profile membership', () {
    final access = MembershipAccessResolver.resolve(
      profile: _profile(
        membershipActive: true,
        vipLevel: 'pro',
        vipStatus: 'active',
        planType: 'lifetime',
      ),
      entitlement: const MembershipEntitlement(
        vipLevel: 'none',
        vipStatus: 'expired',
        planType: 'month',
        expireAt: null,
        source: null,
        membershipLevel: 'none',
        grantType: null,
        grantSubtype: null,
        grantLabel: null,
        isCustomExpire: false,
        isTrial: false,
        maxDevices: 1,
        features: <String>[],
        hasExplicitMembershipState: false,
      ),
    );

    expect(access.hasMembership, isTrue);
    expect(access.hasOnlineService, isTrue);
    expect(access.planType, 'lifetime');
  });

  test('access service stops at explicit inactive entitlement', () async {
    final profileService = _FakeUserProfileService(
      profile: _profile(
        membershipActive: true,
        vipLevel: 'pro',
        vipStatus: 'active',
      ),
    );
    final service = MembershipAccessService(
      sessionStore: await _sessionStore(),
      membershipService: _FakeMembershipService(
        entitlement: const MembershipEntitlement(
          vipLevel: 'none',
          vipStatus: 'expired',
          planType: 'month',
          expireAt: null,
          source: null,
          membershipLevel: 'none',
          grantType: null,
          grantSubtype: null,
          grantLabel: null,
          isCustomExpire: false,
          isTrial: false,
          maxDevices: 1,
          features: <String>[],
          membershipActive: false,
        ),
      ),
      userProfileService: profileService,
    );

    final access = await service.fetchCurrentAccess(
      session: const AuthSession(accessToken: 'token'),
    );

    expect(access.hasMembership, isFalse);
    expect(profileService.fetchCount, 0);
  });

  test(
    'access service falls back to profile when entitlement request fails',
    () async {
      final service = MembershipAccessService(
        sessionStore: await _sessionStore(),
        membershipService: _FakeMembershipService(
          error: _membershipCheckFailed,
        ),
        userProfileService: _FakeUserProfileService(
          profile: _profile(
            membershipActive: true,
            vipLevel: 'pro',
            vipStatus: 'active',
          ),
        ),
      );

      final access = await service.fetchCurrentAccess(
        session: const AuthSession(accessToken: 'token'),
      );

      expect(access.hasMembership, isTrue);
      expect(access.hasOnlineService, isTrue);
    },
  );

  test(
    'access service falls back to session when remote checks fail',
    () async {
      final service = MembershipAccessService(
        sessionStore: await _sessionStore(),
        membershipService: _FakeMembershipService(
          error: _membershipCheckFailed,
        ),
        userProfileService: _FakeUserProfileService(error: _profileCheckFailed),
      );

      final access = await service.fetchCurrentAccess(
        session: const AuthSession(
          accessToken: 'token',
          membershipActive: true,
          vipLevel: 'pro',
          vipStatus: 'active',
        ),
      );

      expect(access.hasMembership, isTrue);
      expect(access.hasOnlineService, isTrue);
    },
  );
}

const _membershipCheckFailed = AppException(
  code: ErrorCode.network,
  briefMessage: '会员状态校验失败。',
  stage: ErrorStage.unknown,
);

const _profileCheckFailed = AppException(
  code: ErrorCode.network,
  briefMessage: '用户信息校验失败。',
  stage: ErrorStage.unknown,
);

Future<AuthSessionStore> _sessionStore() async {
  final prefs = await SharedPreferences.getInstance();
  return AuthSessionStore(
    preferences: prefs,
    secretStore: FakeAuthSessionSecretStore(),
  );
}

UserProfile _profile({
  bool? membershipActive,
  String? vipLevel,
  String? vipStatus,
  String? planType,
}) {
  return UserProfile(
    userId: 'user_1',
    username: 'reader',
    account: 'reader',
    displayName: 'Reader',
    phone: null,
    email: null,
    role: 'user',
    createdAt: null,
    membershipActive: membershipActive,
    vipLevel: vipLevel,
    planType: planType,
    vipStatus: vipStatus,
    vipExpireAt: null,
    features: const <String>[],
  );
}

class _FakeMembershipService extends MembershipService {
  _FakeMembershipService({this.entitlement, this.error})
    : super(baseUrl: 'https://example.com');

  final MembershipEntitlement? entitlement;
  final Object? error;

  @override
  Future<MembershipEntitlement> fetchEntitlement() async {
    final error = this.error;
    if (error != null) {
      throw error;
    }
    return entitlement!;
  }
}

class _FakeUserProfileService extends UserProfileService {
  _FakeUserProfileService({this.profile, this.error})
    : super(baseUrl: 'https://example.com');

  final UserProfile? profile;
  final Object? error;
  int fetchCount = 0;

  @override
  Future<UserProfile> fetchMe() async {
    fetchCount += 1;
    final error = this.error;
    if (error != null) {
      throw error;
    }
    return profile!;
  }
}

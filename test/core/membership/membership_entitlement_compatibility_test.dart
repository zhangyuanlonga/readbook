import 'package:flutter_test/flutter_test.dart';

import 'package:shuxiang_reading_next/core/membership/membership_entitlement.dart';
import 'package:shuxiang_reading_next/core/membership/membership_features.dart';
import 'package:shuxiang_reading_next/core/membership/membership_service.dart';
import 'package:shuxiang_reading_next/core/network/api_client.dart';
import 'package:shuxiang_reading_next/core/user/user_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('MembershipEntitlement keeps legacy fields as source of truth', () {
    final entitlement = MembershipEntitlement.fromJson(<String, dynamic>{
      'vip_level': 'svip',
      'vip_status': 'active',
      'plan_type': 'lifetime',
      'expire_at': '',
      'source': 'activation_code',
      'is_trial': false,
      'max_devices': 3,
      'features': <String>['theme_custom', 'cloud_backup'],
      'membership_level': 'svip',
      'grant_type': 'activation_code',
      'grant_subtype': 'campaign_trial',
      'grant_label': '活动体验码',
      'is_custom_expire': false,
    });

    expect(entitlement.vipLevel, 'svip');
    expect(entitlement.vipStatus, 'active');
    expect(entitlement.planType, 'lifetime');
    expect(entitlement.source, 'activation_code');
    expect(entitlement.isTrial, isFalse);
    expect(entitlement.maxDevices, 3);
    expect(entitlement.features, <String>['theme_custom', 'cloud_backup']);
  });

  test('MembershipEntitlement prefers new grant label fields for display', () {
    final entitlement = MembershipEntitlement.fromJson(<String, dynamic>{
      'vip_level': 'pro',
      'membership_level': 'pro',
      'vip_status': 'active',
      'plan_type': 'custom',
      'source': 'activation_code',
      'grant_type': 'activation_code',
      'grant_subtype': 'campaign_trial',
      'grant_label': '活动体验码',
      'is_custom_expire': true,
      'is_trial': false,
      'max_devices': 1,
      'features': const <String>[],
    });

    expect(entitlement.displayLevel, 'Pro');
    expect(entitlement.displaySourceLabel, '活动体验码');
    expect(entitlement.isCustomExpire, isTrue);
    expect(entitlement.isCampaignTrial, isTrue);
    expect(entitlement.isTrialLike, isTrue);
    expect(entitlement.displayBenefitKind, '活动体验权益');
  });

  test('MembershipEntitlement reads authoritative nested field names', () {
    final entitlement = MembershipEntitlement.fromJson(<String, dynamic>{
      'active': true,
      'level': 'svip',
      'status': 'active',
      'plan_type': 'lifetime',
      'expire_at': null,
      'source': 'manual_grant',
      'label': '手动发放',
      'is_trial': false,
      'max_devices': 3,
      'features': <String>['theme_custom', 'online_service'],
    });

    expect(entitlement.membershipActive, isTrue);
    expect(entitlement.vipLevel, 'svip');
    expect(entitlement.membershipLevel, 'svip');
    expect(entitlement.vipStatus, 'active');
    expect(entitlement.displaySourceLabel, '手动发放');
    expect(entitlement.maxDevices, 3);
    expect(entitlement.features, <String>['theme_custom', 'online_service']);
  });

  test('active membership keeps default member features without payload', () {
    final entitlement = MembershipEntitlement.fromJson(<String, dynamic>{
      'vip_level': 'pro',
      'membership_level': 'pro',
      'vip_status': 'active',
      'features': const <String>[],
    });

    expect(entitlement.isActive, isTrue);
    expect(
      MembershipFeatures.hasFeature(
        entitlement,
        MembershipFeatures.themeCustom,
      ),
      isTrue,
    );
    expect(MembershipFeatures.hasOnlineServiceAccess(entitlement), isTrue);
  });

  test('free membership level is not treated as active', () {
    final entitlement = MembershipEntitlement.fromJson(<String, dynamic>{
      'vip_level': 'free',
      'membership_level': 'free',
      'vip_status': 'active',
      'features': const <String>['theme_custom'],
    });

    expect(entitlement.isActive, isFalse);
    expect(
      MembershipFeatures.hasFeature(
        entitlement,
        MembershipFeatures.themeCustom,
      ),
      isFalse,
    );
  });

  test('membership level can backfill vip level for active payloads', () {
    final entitlement = MembershipEntitlement.fromJson(<String, dynamic>{
      'membership_level': 'pro',
      'vip_status': 'active',
      'features': const <String>[],
    });

    expect(entitlement.vipLevel, 'pro');
    expect(entitlement.isActive, isTrue);
  });

  test('empty entitlement payload is an unknown membership state', () {
    final entitlement = MembershipEntitlement.fromJson(<String, dynamic>{});

    expect(entitlement.isActive, isFalse);
    expect(entitlement.hasExplicitMembershipState, isFalse);
  });

  test(
    'MembershipService keeps free entitlement inactive without status',
    () async {
      final service = MembershipService(
        baseUrl: 'https://example.com',
        client: _MembershipPayloadApiClient(const <String, dynamic>{
          'entitlement': <String, dynamic>{
            'vip_level': 'free',
            'membership_level': 'free',
            'features': <String>['theme_custom'],
          },
        }),
      );

      final entitlement = await service.fetchEntitlement();

      expect(entitlement.vipStatus, 'expired');
      expect(entitlement.isActive, isFalse);
    },
  );

  test(
    'MembershipService treats member levels without status as active',
    () async {
      final service = MembershipService(
        baseUrl: 'https://example.com',
        client: _MembershipPayloadApiClient(const <String, dynamic>{
          'membership': <String, dynamic>{
            'membership_level': 'pro',
            'features': <String>[],
          },
        }),
      );

      final entitlement = await service.fetchEntitlement();

      expect(entitlement.vipLevel, 'pro');
      expect(entitlement.vipStatus, 'active');
      expect(entitlement.isActive, isTrue);
    },
  );

  test('MembershipService reads nested membership payloads', () async {
    final service = MembershipService(
      baseUrl: 'https://example.com',
      client: _MembershipPayloadApiClient(const <String, dynamic>{
        'membership': <String, dynamic>{
          'active': true,
          'level': 'pro',
          'status': 'active',
          'plan_type': 'year',
          'label': '手动发放',
          'max_devices': 2,
          'features': <String>['theme_custom'],
        },
      }),
    );

    final entitlement = await service.fetchEntitlement();

    expect(entitlement.isActive, isTrue);
    expect(entitlement.vipLevel, 'pro');
    expect(entitlement.vipStatus, 'active');
    expect(entitlement.planType, 'year');
    expect(entitlement.displaySourceLabel, '手动发放');
    expect(entitlement.maxDevices, 2);
  });

  test('profile membership matches account page vip fields', () {
    const profile = UserProfile(
      userId: 'user_profile_member',
      username: 'reader',
      account: 'reader',
      displayName: 'Reader',
      phone: null,
      email: null,
      role: 'user',
      createdAt: null,
      vipLevel: 'pro',
      planType: 'lifetime',
      vipStatus: 'active',
      vipExpireAt: null,
      features: <String>[],
    );

    expect(MembershipFeatures.hasActiveProfileMembership(profile), isTrue);
    expect(
      MembershipFeatures.hasProfileFeature(
        profile,
        MembershipFeatures.themeCustom,
      ),
      isTrue,
    );
    expect(MembershipFeatures.hasProfileOnlineServiceAccess(profile), isTrue);
  });

  test('profile free level does not unlock membership features', () {
    const profile = UserProfile(
      userId: 'user_profile_free',
      username: 'reader',
      account: 'reader',
      displayName: 'Reader',
      phone: null,
      email: null,
      role: 'user',
      createdAt: null,
      vipLevel: 'free',
      planType: 'month',
      vipStatus: 'active',
      vipExpireAt: null,
      features: <String>['theme_custom'],
    );

    expect(MembershipFeatures.hasActiveProfileMembership(profile), isFalse);
    expect(
      MembershipFeatures.hasProfileFeature(
        profile,
        MembershipFeatures.themeCustom,
      ),
      isFalse,
    );
  });
}

class _MembershipPayloadApiClient extends ApiClient {
  _MembershipPayloadApiClient(this.payload);

  final Map<String, dynamic> payload;

  @override
  Future<T> request<T>({
    required ApiMethod method,
    required String path,
    Map<String, dynamic> queryParameters = const {},
    Object? body,
    Map<String, String> headers = const {},
    Duration? timeout,
    int? maxRetries,
    bool enableRetry = true,
    bool enableCache = false,
    ApiCachePolicy cachePolicy = ApiCachePolicy.realtime,
    Duration? cacheTtl,
    bool attachAccessToken = false,
    bool enableAuthRefresh = true,
    dynamic stage,
    T Function(Object? data)? decoder,
  }) async {
    if (decoder != null) {
      return decoder(payload);
    }
    return payload as T;
  }
}

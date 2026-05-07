import 'package:flutter_test/flutter_test.dart';

import 'package:shuxiang_reading_next/core/membership/membership_entitlement.dart';

void main() {
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
}

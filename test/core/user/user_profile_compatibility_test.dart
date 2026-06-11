import 'package:flutter_test/flutter_test.dart';

import 'package:shuxiang_reading_next/core/user/user_profile.dart';

void main() {
  test(
    'UserProfile keeps reading legacy membership fields with extra new fields',
    () {
      final profile = UserProfile.fromJson(<String, dynamic>{
        'user': <String, dynamic>{
          'user_id': 'usr_1',
          'username': 'user001',
          'role': 'user',
          'created_at': '2026-05-05T00:00:00Z',
          'vip_level': 'pro',
          'plan_type': 'year',
          'vip_status': 'active',
          'vip_expire_at': '2027-05-05T00:00:00Z',
          'membership_level': 'pro',
          'grant_type': 'manual_grant',
          'grant_subtype': '',
          'grant_label': '手动发放',
          'is_custom_expire': false,
          'features': <String>['theme_custom'],
        },
      });

      expect(profile.userId, 'usr_1');
      expect(profile.username, 'user001');
      expect(profile.vipLevel, 'pro');
      expect(profile.planType, 'year');
      expect(profile.vipStatus, 'active');
      expect(profile.features, <String>['theme_custom']);
    },
  );

  test('UserProfile reads authoritative nested membership payloads', () {
    final profile = UserProfile.fromJson(<String, dynamic>{
      'user': <String, dynamic>{
        'user_id': 'usr_nested',
        'username': 'reader001',
        'role': 'user',
        'created_at': '2026-06-11T00:00:00Z',
        'membership': <String, dynamic>{
          'active': true,
          'level': 'svip',
          'plan_type': 'lifetime',
          'status': 'active',
          'expire_at': null,
          'source': 'manual_grant',
          'label': '手动发放',
          'is_trial': false,
          'max_devices': 3,
          'features': <String>['theme_custom', 'online_service'],
        },
      },
    });

    expect(profile.membershipActive, isTrue);
    expect(profile.vipLevel, 'svip');
    expect(profile.planType, 'lifetime');
    expect(profile.vipStatus, 'active');
    expect(profile.vipExpireAt, isNull);
    expect(profile.features, <String>['theme_custom', 'online_service']);
  });

  test('UserProfile accepts account-only profile payloads', () {
    final profile = UserProfile.fromJson(<String, dynamic>{
      'user': <String, dynamic>{
        'user_id': 'usr_2',
        'account': 'reader002',
        'display_name': ' Reader Two ',
        'features': <Object?>[' theme_custom ', '', null],
      },
    });

    expect(profile.userId, 'usr_2');
    expect(profile.username, 'reader002');
    expect(profile.account, 'reader002');
    expect(profile.displayName, 'Reader Two');
    expect(profile.features, <String>['theme_custom']);
  });
}

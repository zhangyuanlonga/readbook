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
}

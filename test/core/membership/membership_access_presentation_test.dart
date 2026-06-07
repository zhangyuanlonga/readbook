import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/core/membership/membership_access_presentation.dart';

void main() {
  group('MembershipAccessPresentation', () {
    test('resolves account badge labels', () {
      expect(
        MembershipAccessPresentation.accountBadge(
          isLoggedIn: false,
          hasMembership: false,
        ),
        '未登录',
      );
      expect(
        MembershipAccessPresentation.accountBadge(
          isLoggedIn: true,
          hasMembership: false,
        ),
        '普通用户',
      );
      expect(
        MembershipAccessPresentation.accountBadge(
          isLoggedIn: true,
          hasMembership: true,
        ),
        'PRO',
      );
    });

    test('keeps feature gate copy centralized', () {
      expect(
        MembershipAccessPresentation.unavailableMessage(
          MembershipFeatureGate.onlineSearch,
          isLoggedIn: false,
        ),
        '登录并开通会员后可使用在线搜索。',
      );
      expect(
        MembershipAccessPresentation.unavailableMessage(
          MembershipFeatureGate.switchSource,
          isLoggedIn: true,
        ),
        '切换书源为会员服务，开通会员后可使用。',
      );
      expect(
        MembershipAccessPresentation.featureDescription(
          MembershipFeatureGate.advancedTheme,
        ),
        contains('创建、导入、导出并管理高级主题'),
      );
    });

    test('resolves theme entitlement display value', () {
      expect(MembershipAccessPresentation.themeEntitlementValue(true), '已开启');
      expect(MembershipAccessPresentation.themeEntitlementValue(false), '未开启');
    });
  });
}

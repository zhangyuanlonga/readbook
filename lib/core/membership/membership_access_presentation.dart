enum MembershipFeatureGate { advancedTheme, onlineSearch, switchSource }

class MembershipAccessPresentation {
  const MembershipAccessPresentation._();

  static const String premiumBadge = 'PRO';
  static const String normalBadge = '普通用户';
  static const String loggedOutBadge = '未登录';
  static const String vipTag = 'VIP';
  static const String upgradeTitle = '开通会员可用';
  static const String membershipButtonLabel = '前往会员页';
  static const String retryCheckLabel = '重新检查';
  static const String checkFailedMessage = '会员状态校验失败，请稍后重试。';

  static String accountBadge({
    required bool isLoggedIn,
    required bool hasMembership,
  }) {
    if (!isLoggedIn) {
      return loggedOutBadge;
    }
    return hasMembership ? premiumBadge : normalBadge;
  }

  static String themeEntitlementValue(bool hasThemeCustom) {
    return hasThemeCustom ? '已开启' : '未开启';
  }

  static String featureTitle(MembershipFeatureGate gate) {
    return switch (gate) {
      MembershipFeatureGate.advancedTheme => '高级主题为会员专属功能',
      MembershipFeatureGate.onlineSearch => '会员可用在线搜索',
      MembershipFeatureGate.switchSource => '切换书源为会员服务',
    };
  }

  static String featureDescription(MembershipFeatureGate gate) {
    return switch (gate) {
      MembershipFeatureGate.advancedTheme =>
        '开通会员后可创建、导入、导出并管理高级主题，打造更完整的阅读界面风格。',
      MembershipFeatureGate.onlineSearch => '开通会员后可使用服务器书源网关搜索。',
      MembershipFeatureGate.switchSource => '开通会员后可在阅读器中切换书源。',
    };
  }

  static String unavailableMessage(
    MembershipFeatureGate gate, {
    required bool isLoggedIn,
  }) {
    if (!isLoggedIn) {
      return switch (gate) {
        MembershipFeatureGate.advancedTheme => '登录并开通会员后可使用高级主题。',
        MembershipFeatureGate.onlineSearch => '登录并开通会员后可使用在线搜索。',
        MembershipFeatureGate.switchSource => '切换书源为会员服务，请先登录并开通会员。',
      };
    }
    return switch (gate) {
      MembershipFeatureGate.advancedTheme => '高级主题为会员专属功能，开通后可用。',
      MembershipFeatureGate.onlineSearch => '在线搜索为会员服务，开通会员后即可使用。',
      MembershipFeatureGate.switchSource => '切换书源为会员服务，开通会员后可使用。',
    };
  }

  static String actionBlockedMessage(MembershipFeatureGate gate) {
    return unavailableMessage(gate, isLoggedIn: true);
  }
}

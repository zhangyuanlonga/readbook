import 'membership_entitlement.dart';
import '../user/user_profile.dart';

class MembershipFeatures {
  const MembershipFeatures._();

  static const String themeCustom = 'theme_custom';
  static const String onlineService = 'online_service';
  static const String cloudBackup = 'cloud_backup';
  static const String advancedRule = 'advanced_rule';

  static const Set<String> _activeMembershipDefaultFeatures = <String>{
    themeCustom,
    onlineService,
    cloudBackup,
    advancedRule,
  };

  static bool hasActiveMembership(MembershipEntitlement? entitlement) {
    return entitlement?.isActive ?? false;
  }

  static bool hasActiveProfileMembership(UserProfile? profile) {
    final level = profile?.vipLevel?.trim().toLowerCase() ?? '';
    final status = profile?.vipStatus?.trim().toLowerCase() ?? '';
    return status == 'active' && !_isInactiveLevel(level);
  }

  static bool hasFeature(MembershipEntitlement? entitlement, String feature) {
    if (entitlement == null || !entitlement.isActive) {
      return false;
    }
    final normalized = feature.trim();
    if (normalized.isEmpty) {
      return false;
    }
    if (entitlement.features.contains(normalized)) {
      return true;
    }

    // 高级主题、在线服务等属于会员基础能力。旧接口、桌面端同步链或赠送会员账号
    // 可能只返回 active 会员状态，不补齐 features 明细；基础会员能力按有效会员兜底。
    return _activeMembershipDefaultFeatures.contains(normalized);
  }

  static bool hasProfileFeature(UserProfile? profile, String feature) {
    if (!hasActiveProfileMembership(profile)) {
      return false;
    }
    final normalized = feature.trim();
    if (normalized.isEmpty) {
      return false;
    }
    if (profile!.features.contains(normalized)) {
      return true;
    }

    // 账号信息页以 vip_level/vip_status 作为会员展示来源；当该来源已确认
    // 会员有效但 features 明细缺失时，基础会员能力必须和账号信息页保持一致。
    return _activeMembershipDefaultFeatures.contains(normalized);
  }

  static bool hasOnlineServiceAccess(MembershipEntitlement? entitlement) {
    return hasFeature(entitlement, onlineService);
  }

  static bool hasProfileOnlineServiceAccess(UserProfile? profile) {
    return hasProfileFeature(profile, onlineService);
  }

  static bool _isInactiveLevel(String level) {
    switch (level) {
      case '':
      case 'none':
      case 'free':
      case 'basic':
      case 'normal':
      case 'guest':
      case 'expired':
        return true;
      default:
        return false;
    }
  }
}

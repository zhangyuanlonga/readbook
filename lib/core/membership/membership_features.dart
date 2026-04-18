import 'membership_entitlement.dart';

class MembershipFeatures {
  const MembershipFeatures._();

  static const String themeCustom = 'theme_custom';
  static const String onlineService = 'online_service';
  static const String cloudBackup = 'cloud_backup';
  static const String advancedRule = 'advanced_rule';

  static bool hasFeature(MembershipEntitlement? entitlement, String feature) {
    if (entitlement == null || !entitlement.isActive) {
      return false;
    }
    return entitlement.features.contains(feature);
  }
}

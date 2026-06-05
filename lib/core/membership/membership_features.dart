import '../auth/auth_session.dart';
import 'membership_entitlement.dart';
import '../user/user_profile.dart';
import 'membership_access_resolver.dart';

class MembershipFeatures {
  const MembershipFeatures._();

  static const String themeCustom = MembershipAccessResolver.themeCustomFeature;
  static const String onlineService =
      MembershipAccessResolver.onlineServiceFeature;
  static const String cloudBackup = MembershipAccessResolver.cloudBackupFeature;
  static const String advancedRule =
      MembershipAccessResolver.advancedRuleFeature;

  static const Set<String> activeMembershipDefaultFeatures =
      MembershipAccessResolver.activeMembershipDefaultFeatures;

  static bool hasActiveMembership(MembershipEntitlement? entitlement) {
    return MembershipAccessResolver.fromEntitlement(entitlement).hasMembership;
  }

  static bool hasActiveProfileMembership(UserProfile? profile) {
    return MembershipAccessResolver.fromProfile(profile).hasMembership;
  }

  static bool hasActiveSessionMembership(AuthSession? session) {
    return MembershipAccessResolver.fromSession(session).hasMembership;
  }

  static bool hasFeature(MembershipEntitlement? entitlement, String feature) {
    return MembershipAccessResolver.fromEntitlement(
      entitlement,
    ).hasFeature(feature);
  }

  static bool hasProfileFeature(UserProfile? profile, String feature) {
    return MembershipAccessResolver.fromProfile(profile).hasFeature(feature);
  }

  static bool hasSessionFeature(AuthSession? session, String feature) {
    return MembershipAccessResolver.fromSession(session).hasFeature(feature);
  }

  static bool hasOnlineServiceAccess(MembershipEntitlement? entitlement) {
    return hasFeature(entitlement, onlineService);
  }

  static bool hasProfileOnlineServiceAccess(UserProfile? profile) {
    return hasProfileFeature(profile, onlineService);
  }

  static bool hasSessionOnlineServiceAccess(AuthSession? session) {
    return hasSessionFeature(session, onlineService);
  }
}

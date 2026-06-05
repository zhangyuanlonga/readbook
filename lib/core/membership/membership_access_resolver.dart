import '../auth/auth_session.dart';
import '../user/user_profile.dart';
import 'membership_entitlement.dart';

const Object _membershipAccessUnset = Object();

class MembershipAccessSnapshot {
  const MembershipAccessSnapshot({
    required this.hasMembership,
    required this.hasExplicitMembershipState,
    this.vipExpireAt,
    this.planType,
    this.features = const <String>{},
  });

  final bool hasMembership;
  final bool hasExplicitMembershipState;
  final DateTime? vipExpireAt;
  final String? planType;
  final Set<String> features;

  bool get hasThemeCustom =>
      hasFeature(MembershipAccessResolver.themeCustomFeature);

  bool get hasOnlineService =>
      hasFeature(MembershipAccessResolver.onlineServiceFeature);

  bool hasFeature(String feature) {
    if (!hasMembership) {
      return false;
    }
    final normalized = feature.trim();
    if (normalized.isEmpty) {
      return false;
    }
    return features.contains(normalized) ||
        MembershipAccessResolver.activeMembershipDefaultFeatures.contains(
          normalized,
        );
  }

  MembershipAccessSnapshot copyWith({
    bool? hasMembership,
    bool? hasExplicitMembershipState,
    Object? vipExpireAt = _membershipAccessUnset,
    Object? planType = _membershipAccessUnset,
    Set<String>? features,
  }) {
    return MembershipAccessSnapshot(
      hasMembership: hasMembership ?? this.hasMembership,
      hasExplicitMembershipState:
          hasExplicitMembershipState ?? this.hasExplicitMembershipState,
      vipExpireAt:
          identical(vipExpireAt, _membershipAccessUnset)
              ? this.vipExpireAt
              : vipExpireAt as DateTime?,
      planType:
          identical(planType, _membershipAccessUnset)
              ? this.planType
              : planType as String?,
      features: features ?? this.features,
    );
  }
}

class MembershipAccessResolver {
  const MembershipAccessResolver._();

  static const String themeCustomFeature = 'theme_custom';
  static const String onlineServiceFeature = 'online_service';
  static const String cloudBackupFeature = 'cloud_backup';
  static const String advancedRuleFeature = 'advanced_rule';

  static const Set<String> activeMembershipDefaultFeatures = <String>{
    themeCustomFeature,
    onlineServiceFeature,
    cloudBackupFeature,
    advancedRuleFeature,
  };

  static const MembershipAccessSnapshot unknown = MembershipAccessSnapshot(
    hasMembership: false,
    hasExplicitMembershipState: false,
  );

  static MembershipAccessSnapshot fromEntitlement(
    MembershipEntitlement? entitlement,
  ) {
    if (entitlement == null) {
      return unknown;
    }
    final hasMembership = entitlement.isActive;
    return MembershipAccessSnapshot(
      hasMembership: hasMembership,
      hasExplicitMembershipState: entitlement.hasExplicitMembershipState,
      vipExpireAt: hasMembership ? entitlement.expireAt : null,
      planType: hasMembership ? entitlement.planType : null,
      features: _normalizeFeatures(hasMembership ? entitlement.features : null),
    );
  }

  static MembershipAccessSnapshot fromProfile(UserProfile? profile) {
    if (profile == null) {
      return unknown;
    }
    final hasMembership = profile.hasActiveMembership;
    return MembershipAccessSnapshot(
      hasMembership: hasMembership,
      hasExplicitMembershipState:
          profile.membershipActive != null ||
          _hasText(profile.vipLevel) ||
          _hasText(profile.vipStatus),
      vipExpireAt: hasMembership ? profile.vipExpireAt : null,
      planType: hasMembership ? profile.planType : null,
      features: _normalizeFeatures(hasMembership ? profile.features : null),
    );
  }

  static MembershipAccessSnapshot fromSession(AuthSession? session) {
    if (session == null) {
      return unknown;
    }
    final hasMembership = session.hasActiveMembership;
    return MembershipAccessSnapshot(
      hasMembership: hasMembership,
      hasExplicitMembershipState:
          session.membershipActive != null ||
          _hasText(session.vipLevel) ||
          _hasText(session.vipStatus),
      vipExpireAt: hasMembership ? session.vipExpireAt : null,
      planType: hasMembership ? session.planType : null,
    );
  }

  static MembershipAccessSnapshot resolve({
    AuthSession? session,
    UserProfile? profile,
    MembershipEntitlement? entitlement,
  }) {
    final entitlementAccess = fromEntitlement(entitlement);
    final profileAccess = fromProfile(profile);
    final sessionAccess = fromSession(session);
    final fallbacks = <MembershipAccessSnapshot>[
      profileAccess,
      sessionAccess,
      entitlementAccess,
    ];

    if (entitlementAccess.hasExplicitMembershipState) {
      return _withMetadataFallback(entitlementAccess, fallbacks);
    }
    if (profileAccess.hasExplicitMembershipState) {
      return _withMetadataFallback(profileAccess, <MembershipAccessSnapshot>[
        sessionAccess,
        entitlementAccess,
      ]);
    }
    if (sessionAccess.hasExplicitMembershipState) {
      return _withMetadataFallback(sessionAccess, <MembershipAccessSnapshot>[
        entitlementAccess,
      ]);
    }
    if (entitlementAccess.hasMembership) {
      return _withMetadataFallback(entitlementAccess, fallbacks);
    }
    if (profileAccess.hasMembership) {
      return _withMetadataFallback(profileAccess, <MembershipAccessSnapshot>[
        sessionAccess,
      ]);
    }
    if (sessionAccess.hasMembership) {
      return sessionAccess;
    }
    return unknown;
  }

  static bool hasOnlineServiceAccess({
    AuthSession? session,
    UserProfile? profile,
    MembershipEntitlement? entitlement,
  }) {
    return resolve(
      session: session,
      profile: profile,
      entitlement: entitlement,
    ).hasOnlineService;
  }

  static MembershipAccessSnapshot _withMetadataFallback(
    MembershipAccessSnapshot primary,
    List<MembershipAccessSnapshot> fallbacks,
  ) {
    if (!primary.hasMembership) {
      return primary.copyWith(
        vipExpireAt: null,
        planType: null,
        features: const <String>{},
      );
    }

    DateTime? vipExpireAt = primary.vipExpireAt;
    String? planType = _normalizeText(primary.planType);
    final features = <String>{...primary.features};
    for (final fallback in fallbacks) {
      if (!fallback.hasMembership) {
        continue;
      }
      vipExpireAt ??= fallback.vipExpireAt;
      planType ??= _normalizeText(fallback.planType);
      features.addAll(fallback.features);
    }
    return primary.copyWith(
      vipExpireAt: vipExpireAt,
      planType: planType,
      features: features,
    );
  }

  static Set<String> _normalizeFeatures(List<String>? values) {
    if (values == null || values.isEmpty) {
      return const <String>{};
    }
    return values
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet();
  }

  static String? _normalizeText(String? value) {
    final normalized = value?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }

  static bool _hasText(String? value) => _normalizeText(value) != null;
}

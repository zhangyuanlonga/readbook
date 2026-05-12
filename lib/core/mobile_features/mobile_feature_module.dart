class MobileFeatureModule {
  const MobileFeatureModule({
    required this.code,
    required this.name,
    required this.description,
    required this.category,
    required this.visible,
    required this.enabled,
    required this.requiresAuth,
    required this.requiresMembership,
    required this.requiredFeature,
    required this.quotaLimit,
    required this.reason,
  });

  final String code;
  final String name;
  final String? description;
  final String category;
  final bool visible;
  final bool enabled;
  final bool requiresAuth;
  final bool requiresMembership;
  final String? requiredFeature;
  final int quotaLimit;
  final String? reason;

  bool get isUnlimitedQuota => quotaLimit < 0;

  factory MobileFeatureModule.fromJson(Map<String, dynamic> json) {
    int readInt(String key, int fallback) {
      final raw = json[key];
      if (raw is num) {
        return raw.toInt();
      }
      return int.tryParse(raw?.toString() ?? '') ?? fallback;
    }

    String? readOptionalString(String key) {
      final raw = json[key]?.toString().trim() ?? '';
      return raw.isEmpty ? null : raw;
    }

    return MobileFeatureModule(
      code: json['code']?.toString().trim() ?? '',
      name: json['name']?.toString().trim() ?? '',
      description: readOptionalString('description'),
      category: json['category']?.toString().trim() ?? 'general',
      visible: json['visible'] == true,
      enabled: json['enabled'] == true,
      requiresAuth: json['requires_auth'] == true,
      requiresMembership: json['requires_membership'] == true,
      requiredFeature: readOptionalString('required_feature'),
      quotaLimit: readInt('quota_limit', -1),
      reason: readOptionalString('reason'),
    );
  }
}

class MembershipEntitlement {
  const MembershipEntitlement({
    required this.vipLevel,
    required this.vipStatus,
    required this.planType,
    required this.expireAt,
    required this.source,
    required this.membershipLevel,
    required this.grantType,
    required this.grantSubtype,
    required this.grantLabel,
    required this.isCustomExpire,
    required this.isTrial,
    required this.maxDevices,
    required this.features,
  });

  final String vipLevel;
  final String vipStatus;
  final String planType;
  final DateTime? expireAt;
  final String? source;
  final String membershipLevel;
  final String? grantType;
  final String? grantSubtype;
  final String? grantLabel;
  final bool isCustomExpire;
  final bool isTrial;
  final int maxDevices;
  final List<String> features;

  bool get isActive =>
      vipStatus.trim().toLowerCase() == 'active' && !_isInactiveLevel(vipLevel);

  bool get isCampaignTrial => (grantSubtype?.trim() ?? '') == 'campaign_trial';

  bool get isSystemTrial => (grantSubtype?.trim() ?? '') == 'system_trial';

  bool get isTrialLike => isTrial || isCampaignTrial || isSystemTrial;

  String get displayLevel {
    switch (membershipLevel) {
      case 'svip':
        return 'SVIP';
      case 'pro':
        return 'Pro';
      default:
        return '未开通';
    }
  }

  String get displaySourceLabel {
    final label = grantLabel?.trim() ?? '';
    if (label.isNotEmpty) {
      return label;
    }

    switch (grantSubtype?.trim()) {
      case 'campaign_trial':
        return '活动体验';
      case 'system_trial':
        return '系统试用';
    }

    switch (grantType?.trim() ?? source?.trim()) {
      case 'activation_code':
        return '许可证';
      case 'trial':
        return '试用';
      case 'manual_grant':
        return '手工赠送';
      default:
        return '-';
    }
  }

  String get displayBenefitKind {
    if (isCampaignTrial) {
      return '活动体验权益';
    }
    if (isSystemTrial || isTrial) {
      return '试用权益';
    }
    if (isActive) {
      return '正式权益';
    }
    return '未开通';
  }

  factory MembershipEntitlement.fromJson(Map<String, dynamic> json) {
    DateTime? readTime(String key) {
      final raw = json[key]?.toString().trim() ?? '';
      if (raw.isEmpty) {
        return null;
      }
      return DateTime.tryParse(raw)?.toUtc();
    }

    List<String> readFeatures(Object? raw) {
      if (raw is! List) {
        return const <String>[];
      }
      return raw
          .map((item) => item?.toString().trim() ?? '')
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }

    final maxDevicesRaw = json['max_devices'];
    final maxDevices =
        maxDevicesRaw is num
            ? maxDevicesRaw.toInt()
            : int.tryParse(maxDevicesRaw?.toString() ?? '') ?? 1;

    final vipLevel = _firstNonEmpty(<Object?>[
      json['vip_level'],
      json['membership_level'],
    ]);
    final vipStatus = _firstNonEmpty(<Object?>[json['vip_status']]);

    return MembershipEntitlement(
      vipLevel: vipLevel ?? 'none',
      vipStatus: vipStatus ?? 'expired',
      planType: (json['plan_type']?.toString().trim() ?? 'month'),
      expireAt: readTime('expire_at'),
      source:
          (json['source']?.toString().trim().isEmpty ?? true)
              ? null
              : json['source']!.toString().trim(),
      membershipLevel:
          (json['membership_level']?.toString().trim() ??
                  json['vip_level']?.toString().trim() ??
                  'none')
              .trim(),
      grantType:
          (json['grant_type']?.toString().trim().isEmpty ?? true)
              ? null
              : json['grant_type']!.toString().trim(),
      grantSubtype:
          (json['grant_subtype']?.toString().trim().isEmpty ?? true)
              ? null
              : json['grant_subtype']!.toString().trim(),
      grantLabel:
          (json['grant_label']?.toString().trim().isEmpty ?? true)
              ? null
              : json['grant_label']!.toString().trim(),
      isCustomExpire: json['is_custom_expire'] == true,
      isTrial: json['is_trial'] == true,
      maxDevices: maxDevices <= 0 ? 1 : maxDevices,
      features: readFeatures(json['features']),
    );
  }

  static String? _firstNonEmpty(List<Object?> values) {
    for (final value in values) {
      final normalized = value?.toString().trim() ?? '';
      if (normalized.isNotEmpty) {
        return normalized;
      }
    }
    return null;
  }

  static bool _isInactiveLevel(String level) {
    switch (level.trim().toLowerCase()) {
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

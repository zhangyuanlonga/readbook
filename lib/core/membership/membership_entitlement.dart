class MembershipEntitlement {
  const MembershipEntitlement({
    required this.vipLevel,
    required this.vipStatus,
    required this.planType,
    required this.expireAt,
    required this.source,
    required this.isTrial,
    required this.maxDevices,
    required this.features,
  });

  final String vipLevel;
  final String vipStatus;
  final String planType;
  final DateTime? expireAt;
  final String? source;
  final bool isTrial;
  final int maxDevices;
  final List<String> features;

  bool get isActive => vipStatus == 'active' && vipLevel != 'none';

  String get displayLevel {
    switch (vipLevel) {
      case 'svip':
        return 'SVIP';
      case 'pro':
        return 'Pro';
      default:
        return '未开通';
    }
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

    return MembershipEntitlement(
      vipLevel: (json['vip_level']?.toString().trim() ?? 'none'),
      vipStatus: (json['vip_status']?.toString().trim() ?? 'expired'),
      planType: (json['plan_type']?.toString().trim() ?? 'month'),
      expireAt: readTime('expire_at'),
      source:
          (json['source']?.toString().trim().isEmpty ?? true)
              ? null
              : json['source']!.toString().trim(),
      isTrial: json['is_trial'] == true,
      maxDevices: maxDevices <= 0 ? 1 : maxDevices,
      features: readFeatures(json['features']),
    );
  }
}

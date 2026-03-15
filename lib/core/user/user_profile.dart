class UserProfile {
  const UserProfile({
    required this.userId,
    required this.username,
    required this.createdAt,
    required this.vipLevel,
    required this.planType,
    required this.vipStatus,
    required this.vipExpireAt,
    required this.features,
  });

  final String userId;
  final String username;
  final DateTime? createdAt;
  final String? vipLevel;
  final String? planType;
  final String? vipStatus;
  final DateTime? vipExpireAt;
  final List<String> features;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> normalize(Map<String, dynamic> raw) {
      final normalized = <String, dynamic>{...raw};
      final user = raw['user'];
      if (user is Map) {
        for (final entry in user.entries) {
          final key = entry.key.toString();
          if (!normalized.containsKey(key) || normalized[key] == null) {
            normalized[key] = entry.value;
          }
        }
      }
      return normalized;
    }

    final data = normalize(json);

    String readString(String key) {
      final value = data[key]?.toString().trim() ?? '';
      if (value.isEmpty) {
        throw FormatException('Missing required field: $key');
      }
      return value;
    }

    String? readOptionalString(String key) {
      final value = data[key]?.toString().trim() ?? '';
      return value.isEmpty ? null : value;
    }

    DateTime? readTime(String key) {
      final raw = data[key]?.toString().trim() ?? '';
      if (raw.isEmpty) {
        return null;
      }
      return DateTime.tryParse(raw)?.toUtc();
    }

    List<String> readFeatures(Object? raw) {
      if (raw is List) {
        return raw
            .map((item) => item?.toString().trim() ?? '')
            .where((item) => item.isNotEmpty)
            .toList(growable: false);
      }
      if (raw is String) {
        return raw
            .split(',')
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList(growable: false);
      }
      return const <String>[];
    }

    return UserProfile(
      userId: readString('user_id'),
      username: readString('username'),
      createdAt: readTime('created_at'),
      vipLevel: readOptionalString('vip_level'),
      planType: readOptionalString('plan_type'),
      vipStatus: readOptionalString('vip_status'),
      vipExpireAt: readTime('vip_expire_at'),
      features: readFeatures(data['features']),
    );
  }
}

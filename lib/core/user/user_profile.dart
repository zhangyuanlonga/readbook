class UserProfile {
  const UserProfile({
    required this.userId,
    required this.username,
    required this.role,
    required this.createdAt,
    required this.vipLevel,
    required this.planType,
    required this.vipStatus,
    required this.vipExpireAt,
    required this.features,
  });

  final String userId;
  final String username;
  final String? role;
  final DateTime? createdAt;
  final String? vipLevel;
  final String? planType;
  final String? vipStatus;
  final DateTime? vipExpireAt;
  final List<String> features;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final rawUser = json['user'];
    if (rawUser is! Map) {
      throw const FormatException('Missing user object in profile response.');
    }
    final data = rawUser.map((key, value) => MapEntry(key.toString(), value));

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
      return const <String>[];
    }

    return UserProfile(
      userId: readString('user_id'),
      username: readString('username'),
      role: readOptionalString('role'),
      createdAt: readTime('created_at'),
      vipLevel: readOptionalString('vip_level'),
      planType: readOptionalString('plan_type'),
      vipStatus: readOptionalString('vip_status'),
      vipExpireAt: readTime('vip_expire_at'),
      features: readFeatures(data['features']),
    );
  }
}

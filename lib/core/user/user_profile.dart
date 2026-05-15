class UserProfile {
  const UserProfile({
    required this.userId,
    required this.username,
    required this.account,
    required this.displayName,
    required this.phone,
    required this.email,
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
  final String account;
  final String? displayName;
  final String? phone;
  final String? email;
  final String? role;
  final DateTime? createdAt;
  final String? vipLevel;
  final String? planType;
  final String? vipStatus;
  final DateTime? vipExpireAt;
  final List<String> features;

  String get loginIdentity {
    final normalizedAccount = account.trim();
    if (normalizedAccount.isNotEmpty) {
      return normalizedAccount;
    }
    return username;
  }

  String get displayIdentity {
    final normalizedDisplayName = displayName?.trim() ?? '';
    if (normalizedDisplayName.isNotEmpty) {
      return normalizedDisplayName;
    }
    return loginIdentity;
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final rawUser = json['user'];
    if (rawUser is! Map) {
      throw const FormatException('Missing user object in profile response.');
    }
    final data = rawUser.map((key, value) => MapEntry(key.toString(), value));

    String? readOptionalString(String key) {
      final value = data[key]?.toString().trim() ?? '';
      return value.isEmpty ? null : value;
    }

    String requireOneOf(List<String> keys) {
      for (final key in keys) {
        final value = readOptionalString(key);
        if (value != null && value.isNotEmpty) {
          return value;
        }
      }
      throw FormatException('Missing required fields: ${keys.join(", ")}');
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
      userId: requireOneOf(const <String>['user_id']),
      username: requireOneOf(const <String>['username', 'account']),
      account: requireOneOf(const <String>['account', 'username']),
      displayName: readOptionalString('display_name'),
      phone: readOptionalString('phone'),
      email: readOptionalString('email'),
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

import 'package:json_annotation/json_annotation.dart';

part 'user_profile.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake, createToJson: false)
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
    this.membershipActive,
    required this.vipLevel,
    required this.planType,
    required this.vipStatus,
    required this.vipExpireAt,
    required this.features,
  });

  @JsonKey(fromJson: _requiredUserIdFromJson)
  final String userId;
  @JsonKey(fromJson: _requiredUsernameFromJson)
  final String username;
  @JsonKey(fromJson: _requiredAccountFromJson)
  final String account;
  @JsonKey(fromJson: _optionalStringFromJson)
  final String? displayName;
  @JsonKey(fromJson: _optionalStringFromJson)
  final String? phone;
  @JsonKey(fromJson: _optionalStringFromJson)
  final String? email;
  @JsonKey(fromJson: _optionalStringFromJson)
  final String? role;
  @JsonKey(fromJson: _optionalUtcDateTimeFromJson)
  final DateTime? createdAt;
  @JsonKey(fromJson: _optionalBoolFromJson)
  final bool? membershipActive;
  @JsonKey(fromJson: _optionalStringFromJson)
  final String? vipLevel;
  @JsonKey(fromJson: _optionalStringFromJson)
  final String? planType;
  @JsonKey(fromJson: _optionalStringFromJson)
  final String? vipStatus;
  @JsonKey(fromJson: _optionalUtcDateTimeFromJson)
  final DateTime? vipExpireAt;
  @JsonKey(fromJson: _featuresFromJson)
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

    if (!_hasText(data['username']) && _hasText(data['account'])) {
      data['username'] = data['account'];
    }
    if (!_hasText(data['account']) && _hasText(data['username'])) {
      data['account'] = data['username'];
    }
    _inlineMembershipFields(data);

    return UserProfile._fromUserJson(data);
  }

  factory UserProfile._fromUserJson(Map<String, dynamic> json) =>
      _$UserProfileFromJson(json);

  static bool _hasText(Object? value) {
    return (value?.toString().trim() ?? '').isNotEmpty;
  }

  static void _inlineMembershipFields(Map<String, dynamic> data) {
    final membership = _readStringKeyMap(data['membership']);
    if (membership == null) {
      return;
    }
    data['membership_active'] ??= membership['active'];
    data['vip_level'] ??= membership['level'];
    data['plan_type'] ??= membership['plan_type'];
    data['vip_status'] ??= membership['status'];
    data['vip_expire_at'] ??= membership['expire_at'];
    data['source'] ??= membership['source'];
    data['max_devices'] ??= membership['max_devices'];
    data['features'] ??= membership['features'];
  }

  static Map<String, dynamic>? _readStringKeyMap(Object? value) {
    if (value is! Map) {
      return null;
    }
    return value.map((key, value) => MapEntry(key.toString(), value));
  }

  static String _requiredUserIdFromJson(Object? value) =>
      _requiredString(value, 'user_id');

  static String _requiredUsernameFromJson(Object? value) =>
      _requiredString(value, 'username, account');

  static String _requiredAccountFromJson(Object? value) =>
      _requiredString(value, 'account, username');

  static String _requiredString(Object? value, String key) {
    final normalized = value?.toString().trim() ?? '';
    if (normalized.isEmpty) {
      throw FormatException('Missing required fields: $key');
    }
    return normalized;
  }

  static String? _optionalStringFromJson(Object? value) {
    final normalized = value?.toString().trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }

  static DateTime? _optionalUtcDateTimeFromJson(Object? value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw)?.toUtc();
  }

  static bool? _optionalBoolFromJson(Object? value) {
    if (value is bool) {
      return value;
    }
    final normalized = value?.toString().trim().toLowerCase() ?? '';
    if (normalized.isEmpty) {
      return null;
    }
    if (normalized == 'true' || normalized == '1') {
      return true;
    }
    if (normalized == 'false' || normalized == '0') {
      return false;
    }
    return null;
  }

  static List<String> _featuresFromJson(Object? value) {
    if (value is! List) {
      return const <String>[];
    }
    return value
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

}

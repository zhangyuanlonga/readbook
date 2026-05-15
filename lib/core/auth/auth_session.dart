class AuthSession {
  const AuthSession({
    required this.accessToken,
    this.refreshToken,
    this.accessExpiresAt,
    this.refreshExpiresAt,
    this.userId,
    this.username,
    this.account,
    this.displayName,
  });

  final String accessToken;
  final String? refreshToken;
  final DateTime? accessExpiresAt;
  final DateTime? refreshExpiresAt;
  final String? userId;
  final String? username;
  final String? account;
  final String? displayName;

  String? get loginIdentity {
    final normalizedAccount = account?.trim();
    if (normalizedAccount != null && normalizedAccount.isNotEmpty) {
      return normalizedAccount;
    }
    final normalizedUsername = username?.trim();
    if (normalizedUsername != null && normalizedUsername.isNotEmpty) {
      return normalizedUsername;
    }
    return null;
  }

  String? get displayIdentity {
    final normalizedDisplayName = displayName?.trim();
    if (normalizedDisplayName != null && normalizedDisplayName.isNotEmpty) {
      return normalizedDisplayName;
    }
    return loginIdentity;
  }

  bool isAccessExpired({Duration skew = const Duration(minutes: 1)}) {
    final expiresAt = accessExpiresAt;
    if (expiresAt == null) {
      return false;
    }
    return DateTime.now().toUtc().isAfter(expiresAt.subtract(skew));
  }

  bool isRefreshExpired({Duration skew = const Duration(minutes: 1)}) {
    final expiresAt = refreshExpiresAt;
    if (expiresAt == null) {
      return false;
    }
    return DateTime.now().toUtc().isAfter(expiresAt.subtract(skew));
  }

  bool get isValid => accessToken.trim().isNotEmpty;
}

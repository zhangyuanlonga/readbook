class AuthSession {
  const AuthSession({
    required this.accessToken,
    this.refreshToken,
    this.accessExpiresAt,
    this.refreshExpiresAt,
    this.userId,
    this.username,
  });

  final String accessToken;
  final String? refreshToken;
  final DateTime? accessExpiresAt;
  final DateTime? refreshExpiresAt;
  final String? userId;
  final String? username;

  bool get isValid => accessToken.trim().isNotEmpty;
}

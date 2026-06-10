import 'auth_session.dart';

class UserSessionState {
  const UserSessionState({
    required this.isLoggedIn,
    this.userId,
    this.username,
    this.account,
    this.displayName,
    this.accessToken,
    this.tokenExpiresAt,
  });

  const UserSessionState.empty()
    : isLoggedIn = false,
      userId = null,
      username = null,
      account = null,
      displayName = null,
      accessToken = null,
      tokenExpiresAt = null;

  final bool isLoggedIn;
  final String? userId;
  final String? username;
  final String? account;
  final String? displayName;
  final String? accessToken;
  final DateTime? tokenExpiresAt;

  factory UserSessionState.fromSession(AuthSession? session) {
    final token = session?.accessToken.trim() ?? '';
    if (session == null || token.isEmpty) {
      return const UserSessionState.empty();
    }
    return UserSessionState(
      isLoggedIn: true,
      userId: _blankToNull(session.userId),
      username: _blankToNull(session.username),
      account: _blankToNull(session.account),
      displayName: _blankToNull(session.displayName),
      accessToken: token,
      tokenExpiresAt: session.accessExpiresAt,
    );
  }

  static String? _blankToNull(String? value) {
    final normalized = value?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }
}

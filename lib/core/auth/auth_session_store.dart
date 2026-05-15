import 'package:shared_preferences/shared_preferences.dart';

import 'auth_session.dart';

class AuthSessionStore {
  AuthSessionStore({SharedPreferences? preferences})
    : _preferencesFuture =
          preferences == null
              ? SharedPreferences.getInstance()
              : Future.value(preferences);

  static const String _accessTokenKey = 'auth.access_token';
  static const String _refreshTokenKey = 'auth.refresh_token';
  static const String _accessExpiresAtKey = 'auth.access_expires_at';
  static const String _refreshExpiresAtKey = 'auth.refresh_expires_at';
  static const String _userIdKey = 'auth.user_id';
  static const String _usernameKey = 'auth.username';
  static const String _accountKey = 'auth.account';
  static const String _displayNameKey = 'auth.display_name';

  final Future<SharedPreferences> _preferencesFuture;

  Future<AuthSession?> getSession() async {
    final prefs = await _preferencesFuture;
    return readSession(prefs);
  }

  static AuthSession? readSession(SharedPreferences prefs) {
    final accessToken = (prefs.getString(_accessTokenKey) ?? '').trim();
    if (accessToken.isEmpty) {
      return null;
    }
    final userId = (prefs.getString(_userIdKey) ?? '').trim();
    final username = (prefs.getString(_usernameKey) ?? '').trim();
    final account = (prefs.getString(_accountKey) ?? '').trim();
    final displayName = (prefs.getString(_displayNameKey) ?? '').trim();
    final refreshToken = (prefs.getString(_refreshTokenKey) ?? '').trim();
    final accessExpiresAt = _parseTime(prefs.getString(_accessExpiresAtKey));
    final refreshExpiresAt = _parseTime(prefs.getString(_refreshExpiresAtKey));
    return AuthSession(
      accessToken: accessToken,
      refreshToken: refreshToken.isEmpty ? null : refreshToken,
      accessExpiresAt: accessExpiresAt,
      refreshExpiresAt: refreshExpiresAt,
      userId: userId.isEmpty ? null : userId,
      username: username.isEmpty ? null : username,
      account: account.isEmpty ? null : account,
      displayName: displayName.isEmpty ? null : displayName,
    );
  }

  Future<String?> getAccessToken() async {
    final prefs = await _preferencesFuture;
    final accessToken = (prefs.getString(_accessTokenKey) ?? '').trim();
    return accessToken.isEmpty ? null : accessToken;
  }

  Future<String?> getRefreshToken() async {
    final prefs = await _preferencesFuture;
    final refreshToken = (prefs.getString(_refreshTokenKey) ?? '').trim();
    return refreshToken.isEmpty ? null : refreshToken;
  }

  Future<String?> getUserId() async {
    final prefs = await _preferencesFuture;
    final userId = (prefs.getString(_userIdKey) ?? '').trim();
    return userId.isEmpty ? null : userId;
  }

  Future<void> saveSession(AuthSession session) async {
    final prefs = await _preferencesFuture;
    final accessToken = session.accessToken.trim();
    if (accessToken.isEmpty) {
      await prefs.remove(_accessTokenKey);
    } else {
      await prefs.setString(_accessTokenKey, accessToken);
    }

    final userId = session.userId?.trim() ?? '';
    if (userId.isEmpty) {
      await prefs.remove(_userIdKey);
    } else {
      await prefs.setString(_userIdKey, userId);
    }

    final username = session.loginIdentity?.trim() ?? '';
    if (username.isEmpty) {
      await prefs.remove(_usernameKey);
    } else {
      await prefs.setString(_usernameKey, username);
    }

    final account = session.account?.trim() ?? '';
    if (account.isEmpty) {
      await prefs.remove(_accountKey);
    } else {
      await prefs.setString(_accountKey, account);
    }

    final displayName = session.displayName?.trim() ?? '';
    if (displayName.isEmpty) {
      await prefs.remove(_displayNameKey);
    } else {
      await prefs.setString(_displayNameKey, displayName);
    }

    final refreshToken = session.refreshToken?.trim() ?? '';
    if (refreshToken.isEmpty) {
      await prefs.remove(_refreshTokenKey);
    } else {
      await prefs.setString(_refreshTokenKey, refreshToken);
    }

    final accessExpiresAt = session.accessExpiresAt?.toUtc().toIso8601String();
    if (accessExpiresAt == null || accessExpiresAt.isEmpty) {
      await prefs.remove(_accessExpiresAtKey);
    } else {
      await prefs.setString(_accessExpiresAtKey, accessExpiresAt);
    }

    final refreshExpiresAt =
        session.refreshExpiresAt?.toUtc().toIso8601String();
    if (refreshExpiresAt == null || refreshExpiresAt.isEmpty) {
      await prefs.remove(_refreshExpiresAtKey);
    } else {
      await prefs.setString(_refreshExpiresAtKey, refreshExpiresAt);
    }
  }

  Future<void> clear() async {
    final prefs = await _preferencesFuture;
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_usernameKey);
    await prefs.remove(_accountKey);
    await prefs.remove(_displayNameKey);
    await prefs.remove(_refreshTokenKey);
    await prefs.remove(_accessExpiresAtKey);
    await prefs.remove(_refreshExpiresAtKey);
  }

  static DateTime? _parseTime(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value)?.toUtc();
  }
}

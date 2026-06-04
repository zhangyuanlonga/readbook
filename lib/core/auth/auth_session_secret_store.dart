import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_session_storage_keys.dart';

const String authSecretFallbackAccessTokenStorageKey =
    'auth.secret_fallback.access_token';
const String authSecretFallbackRefreshTokenStorageKey =
    'auth.secret_fallback.refresh_token';
const String authSecretFallbackAccessExpiresAtStorageKey =
    'auth.secret_fallback.access_expires_at';
const String authSecretFallbackRefreshExpiresAtStorageKey =
    'auth.secret_fallback.refresh_expires_at';

class AuthSessionSecrets {
  const AuthSessionSecrets({
    this.accessToken,
    this.refreshToken,
    this.accessExpiresAt,
    this.refreshExpiresAt,
  });

  final String? accessToken;
  final String? refreshToken;
  final DateTime? accessExpiresAt;
  final DateTime? refreshExpiresAt;

  bool get hasAccessToken => (accessToken?.trim().isNotEmpty ?? false);

  bool get hasAnyValue =>
      hasAccessToken ||
      (refreshToken?.trim().isNotEmpty ?? false) ||
      accessExpiresAt != null ||
      refreshExpiresAt != null;

  AuthSessionSecrets mergeMissing(AuthSessionSecrets fallback) {
    return AuthSessionSecrets(
      accessToken: _pickPrimary(accessToken, fallback.accessToken),
      refreshToken: _pickPrimary(refreshToken, fallback.refreshToken),
      accessExpiresAt: accessExpiresAt ?? fallback.accessExpiresAt,
      refreshExpiresAt: refreshExpiresAt ?? fallback.refreshExpiresAt,
    );
  }

  static String? _pickPrimary(String? primary, String? fallback) {
    final normalizedPrimary = primary?.trim() ?? '';
    if (normalizedPrimary.isNotEmpty) {
      return normalizedPrimary;
    }
    final normalizedFallback = fallback?.trim() ?? '';
    if (normalizedFallback.isNotEmpty) {
      return normalizedFallback;
    }
    return null;
  }
}

abstract class AuthSessionSecretStore {
  Future<AuthSessionSecrets> readSecrets();

  Future<void> writeSecrets(AuthSessionSecrets secrets);

  Future<void> clear();
}

AuthSessionSecretStore createDefaultAuthSessionSecretStore({
  SharedPreferences? preferences,
}) {
  // 桌面和 Web 端不能假设 flutter_secure_storage 一定具备同等能力：
  // Windows / Linux / macOS 先走 SharedPreferences fallback，移动端继续使用系统安全存储。
  if (kIsWeb || _isDesktopPlatform(defaultTargetPlatform)) {
    return SharedPreferencesAuthSessionSecretStore(preferences: preferences);
  }
  return FlutterSecureAuthSessionSecretStore();
}

bool hasPersistedFallbackAuthSecretsSync(SharedPreferences prefs) {
  // 启动路由只能同步判断是否“可能有会话”，不能在这里触发异步迁移。
  // 真正读取和迁移仍由 AuthSessionStore 统一处理，避免启动期多端状态分叉。
  return _readNormalizedPrefsValue(
            prefs,
            authSecretFallbackAccessTokenStorageKey,
          ) !=
          null ||
      _readNormalizedPrefsValue(
            prefs,
            authSecretFallbackRefreshTokenStorageKey,
          ) !=
          null ||
      _readNormalizedPrefsValue(
            prefs,
            authSecretFallbackAccessExpiresAtStorageKey,
          ) !=
          null ||
      _readNormalizedPrefsValue(
            prefs,
            authSecretFallbackRefreshExpiresAtStorageKey,
          ) !=
          null;
}

class FlutterSecureAuthSessionSecretStore implements AuthSessionSecretStore {
  FlutterSecureAuthSessionSecretStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<void> clear() async {
    await _delete(authAccessTokenStorageKey);
    await _delete(authRefreshTokenStorageKey);
    await _delete(authAccessExpiresAtStorageKey);
    await _delete(authRefreshExpiresAtStorageKey);
  }

  @override
  Future<AuthSessionSecrets> readSecrets() async {
    final accessToken = await _read(authAccessTokenStorageKey);
    final refreshToken = await _read(authRefreshTokenStorageKey);
    final accessExpiresAt = _parseTime(
      await _read(authAccessExpiresAtStorageKey),
    );
    final refreshExpiresAt = _parseTime(
      await _read(authRefreshExpiresAtStorageKey),
    );
    return AuthSessionSecrets(
      accessToken: accessToken,
      refreshToken: refreshToken,
      accessExpiresAt: accessExpiresAt,
      refreshExpiresAt: refreshExpiresAt,
    );
  }

  @override
  Future<void> writeSecrets(AuthSessionSecrets secrets) async {
    await _write(authAccessTokenStorageKey, secrets.accessToken);
    await _write(authRefreshTokenStorageKey, secrets.refreshToken);
    await _write(
      authAccessExpiresAtStorageKey,
      secrets.accessExpiresAt?.toUtc().toIso8601String(),
    );
    await _write(
      authRefreshExpiresAtStorageKey,
      secrets.refreshExpiresAt?.toUtc().toIso8601String(),
    );
  }

  Future<void> _delete(String key) async {
    try {
      await _storage.delete(key: key);
    } on MissingPluginException catch (_) {
      throw StateError('当前运行中的应用尚未加载安全存储插件，请完整重启应用后再试。');
    }
  }

  DateTime? _parseTime(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value)?.toUtc();
  }

  Future<String?> _read(String key) async {
    try {
      final value = await _storage.read(key: key);
      final normalized = value?.trim() ?? '';
      return normalized.isEmpty ? null : normalized;
    } on MissingPluginException catch (_) {
      throw StateError('当前运行中的应用尚未加载安全存储插件，请完整重启应用后再试。');
    }
  }

  Future<void> _write(String key, String? value) async {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) {
      await _delete(key);
      return;
    }
    try {
      await _storage.write(key: key, value: normalized);
    } on MissingPluginException catch (_) {
      throw StateError('当前运行中的应用尚未加载安全存储插件，请完整重启应用后再试。');
    }
  }
}

class SharedPreferencesAuthSessionSecretStore
    implements AuthSessionSecretStore {
  SharedPreferencesAuthSessionSecretStore({SharedPreferences? preferences})
    : _preferencesFuture =
          preferences == null
              ? SharedPreferences.getInstance()
              : Future.value(preferences);

  final Future<SharedPreferences> _preferencesFuture;

  @override
  Future<void> clear() async {
    final prefs = await _preferencesFuture;
    await prefs.remove(authSecretFallbackAccessTokenStorageKey);
    await prefs.remove(authSecretFallbackRefreshTokenStorageKey);
    await prefs.remove(authSecretFallbackAccessExpiresAtStorageKey);
    await prefs.remove(authSecretFallbackRefreshExpiresAtStorageKey);
  }

  @override
  Future<AuthSessionSecrets> readSecrets() async {
    final prefs = await _preferencesFuture;
    return AuthSessionSecrets(
      accessToken: _readNormalizedPrefsValue(
        prefs,
        authSecretFallbackAccessTokenStorageKey,
      ),
      refreshToken: _readNormalizedPrefsValue(
        prefs,
        authSecretFallbackRefreshTokenStorageKey,
      ),
      accessExpiresAt: _parseTime(
        _readNormalizedPrefsValue(
          prefs,
          authSecretFallbackAccessExpiresAtStorageKey,
        ),
      ),
      refreshExpiresAt: _parseTime(
        _readNormalizedPrefsValue(
          prefs,
          authSecretFallbackRefreshExpiresAtStorageKey,
        ),
      ),
    );
  }

  @override
  Future<void> writeSecrets(AuthSessionSecrets secrets) async {
    final prefs = await _preferencesFuture;
    await _writeString(
      prefs,
      authSecretFallbackAccessTokenStorageKey,
      secrets.accessToken,
    );
    await _writeString(
      prefs,
      authSecretFallbackRefreshTokenStorageKey,
      secrets.refreshToken,
    );
    await _writeString(
      prefs,
      authSecretFallbackAccessExpiresAtStorageKey,
      secrets.accessExpiresAt?.toUtc().toIso8601String(),
    );
    await _writeString(
      prefs,
      authSecretFallbackRefreshExpiresAtStorageKey,
      secrets.refreshExpiresAt?.toUtc().toIso8601String(),
    );
  }

  DateTime? _parseTime(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value)?.toUtc();
  }

  Future<void> _writeString(
    SharedPreferences prefs,
    String key,
    String? value,
  ) async {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) {
      await prefs.remove(key);
      return;
    }
    await prefs.setString(key, normalized);
  }
}

bool _isDesktopPlatform(TargetPlatform platform) {
  return platform == TargetPlatform.macOS ||
      platform == TargetPlatform.windows ||
      platform == TargetPlatform.linux;
}

String? _readNormalizedPrefsValue(SharedPreferences prefs, String key) {
  final value = prefs.getString(key)?.trim() ?? '';
  return value.isEmpty ? null : value;
}

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'auth_session_storage_keys.dart';

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

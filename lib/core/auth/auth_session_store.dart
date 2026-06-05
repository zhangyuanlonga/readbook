import 'package:shared_preferences/shared_preferences.dart';

import 'auth_session.dart';
import 'auth_session_secret_store.dart';
import 'auth_session_storage_keys.dart';

class AuthSessionStore {
  AuthSessionStore({
    SharedPreferences? preferences,
    AuthSessionSecretStore? secretStore,
    this.enableLegacyCredentialFallback = true,
  }) : _preferencesFuture =
           preferences == null
               ? SharedPreferences.getInstance()
               : Future.value(preferences),
       _secretStore = secretStore ?? FlutterSecureAuthSessionSecretStore();

  final Future<SharedPreferences> _preferencesFuture;
  final AuthSessionSecretStore _secretStore;
  final bool enableLegacyCredentialFallback;

  Future<AuthSession?> getSession() async {
    final prefs = await _preferencesFuture;
    final secrets = await _readSecretsWithMigration(prefs);
    if (!secrets.hasAccessToken) {
      return null;
    }
    final displaySession = readDisplaySession(prefs);
    return AuthSession(
      accessToken: secrets.accessToken!.trim(),
      refreshToken: secrets.refreshToken,
      accessExpiresAt: secrets.accessExpiresAt,
      refreshExpiresAt: secrets.refreshExpiresAt,
      userId: displaySession?.userId,
      username: displaySession?.username,
      account: displaySession?.account,
      displayName: displaySession?.displayName,
      membershipActive: displaySession?.membershipActive,
      vipLevel: displaySession?.vipLevel,
      planType: displaySession?.planType,
      vipStatus: displaySession?.vipStatus,
      vipExpireAt: displaySession?.vipExpireAt,
    );
  }

  static AuthSession? readSession(SharedPreferences prefs) {
    final accessToken =
        (prefs.getString(authAccessTokenStorageKey) ?? '').trim();
    if (accessToken.isEmpty) {
      return null;
    }
    final displaySession = readDisplaySession(prefs);
    final refreshToken =
        (prefs.getString(authRefreshTokenStorageKey) ?? '').trim();
    final accessExpiresAt = _parseTime(
      prefs.getString(authAccessExpiresAtStorageKey),
    );
    final refreshExpiresAt = _parseTime(
      prefs.getString(authRefreshExpiresAtStorageKey),
    );
    return AuthSession(
      accessToken: accessToken,
      refreshToken: refreshToken.isEmpty ? null : refreshToken,
      accessExpiresAt: accessExpiresAt,
      refreshExpiresAt: refreshExpiresAt,
      userId: displaySession?.userId,
      username: displaySession?.username,
      account: displaySession?.account,
      displayName: displaySession?.displayName,
      membershipActive: displaySession?.membershipActive,
      vipLevel: displaySession?.vipLevel,
      planType: displaySession?.planType,
      vipStatus: displaySession?.vipStatus,
      vipExpireAt: displaySession?.vipExpireAt,
    );
  }

  static AuthSession? readDisplaySession(SharedPreferences prefs) {
    final userId = (prefs.getString(authUserIdStorageKey) ?? '').trim();
    final username = (prefs.getString(authUsernameStorageKey) ?? '').trim();
    final account = (prefs.getString(authAccountStorageKey) ?? '').trim();
    final displayName =
        (prefs.getString(authDisplayNameStorageKey) ?? '').trim();
    final vipLevel = (prefs.getString(authVipLevelStorageKey) ?? '').trim();
    final planType = (prefs.getString(authPlanTypeStorageKey) ?? '').trim();
    final vipStatus = (prefs.getString(authVipStatusStorageKey) ?? '').trim();
    final vipExpireAt = _parseTime(prefs.getString(authVipExpireAtStorageKey));
    if (userId.isEmpty &&
        username.isEmpty &&
        account.isEmpty &&
        displayName.isEmpty) {
      return null;
    }
    return AuthSession(
      accessToken: '',
      userId: userId.isEmpty ? null : userId,
      username: username.isEmpty ? null : username,
      account: account.isEmpty ? null : account,
      displayName: displayName.isEmpty ? null : displayName,
      membershipActive: prefs.getBool(authMembershipActiveStorageKey),
      vipLevel: vipLevel.isEmpty ? null : vipLevel,
      planType: planType.isEmpty ? null : planType,
      vipStatus: vipStatus.isEmpty ? null : vipStatus,
      vipExpireAt: vipExpireAt,
    );
  }

  Future<String?> getAccessToken() async {
    final prefs = await _preferencesFuture;
    final secrets = await _readSecretsWithMigration(prefs);
    final accessToken = secrets.accessToken?.trim() ?? '';
    return accessToken.isEmpty ? null : accessToken;
  }

  Future<String?> getRefreshToken() async {
    final prefs = await _preferencesFuture;
    final secrets = await _readSecretsWithMigration(prefs);
    final refreshToken = secrets.refreshToken?.trim() ?? '';
    return refreshToken.isEmpty ? null : refreshToken;
  }

  Future<String?> getUserId() async {
    final prefs = await _preferencesFuture;
    final userId = (prefs.getString(authUserIdStorageKey) ?? '').trim();
    return userId.isEmpty ? null : userId;
  }

  Future<void> saveSession(AuthSession session) async {
    final prefs = await _preferencesFuture;
    await _secretStore.writeSecrets(
      AuthSessionSecrets(
        accessToken: session.accessToken,
        refreshToken: session.refreshToken,
        accessExpiresAt: session.accessExpiresAt,
        refreshExpiresAt: session.refreshExpiresAt,
      ),
    );

    final userId = session.userId?.trim() ?? '';
    if (userId.isEmpty) {
      await prefs.remove(authUserIdStorageKey);
    } else {
      await prefs.setString(authUserIdStorageKey, userId);
    }

    final username = session.loginIdentity?.trim() ?? '';
    if (username.isEmpty) {
      await prefs.remove(authUsernameStorageKey);
    } else {
      await prefs.setString(authUsernameStorageKey, username);
    }

    final account = session.account?.trim() ?? '';
    if (account.isEmpty) {
      await prefs.remove(authAccountStorageKey);
    } else {
      await prefs.setString(authAccountStorageKey, account);
    }

    final displayName = session.displayName?.trim() ?? '';
    if (displayName.isEmpty) {
      await prefs.remove(authDisplayNameStorageKey);
    } else {
      await prefs.setString(authDisplayNameStorageKey, displayName);
    }

    final membershipActive = session.membershipActive;
    if (membershipActive == null) {
      await prefs.remove(authMembershipActiveStorageKey);
    } else {
      await prefs.setBool(authMembershipActiveStorageKey, membershipActive);
    }

    final vipLevel = session.vipLevel?.trim() ?? '';
    if (vipLevel.isEmpty) {
      await prefs.remove(authVipLevelStorageKey);
    } else {
      await prefs.setString(authVipLevelStorageKey, vipLevel);
    }

    final planType = session.planType?.trim() ?? '';
    if (planType.isEmpty) {
      await prefs.remove(authPlanTypeStorageKey);
    } else {
      await prefs.setString(authPlanTypeStorageKey, planType);
    }

    final vipStatus = session.vipStatus?.trim() ?? '';
    if (vipStatus.isEmpty) {
      await prefs.remove(authVipStatusStorageKey);
    } else {
      await prefs.setString(authVipStatusStorageKey, vipStatus);
    }

    final vipExpireAt = session.vipExpireAt;
    if (vipExpireAt == null) {
      await prefs.remove(authVipExpireAtStorageKey);
    } else {
      await prefs.setString(
        authVipExpireAtStorageKey,
        vipExpireAt.toIso8601String(),
      );
    }

    await _clearLegacyCredentialKeys(prefs);
  }

  Future<void> clear() async {
    final prefs = await _preferencesFuture;
    await _secretStore.clear();
    await prefs.remove(authUserIdStorageKey);
    await prefs.remove(authUsernameStorageKey);
    await prefs.remove(authAccountStorageKey);
    await prefs.remove(authDisplayNameStorageKey);
    await prefs.remove(authMembershipActiveStorageKey);
    await prefs.remove(authVipLevelStorageKey);
    await prefs.remove(authPlanTypeStorageKey);
    await prefs.remove(authVipStatusStorageKey);
    await prefs.remove(authVipExpireAtStorageKey);
    await _clearLegacyCredentialKeys(prefs);
  }

  Future<void> _clearLegacyCredentialKeys(SharedPreferences prefs) async {
    await prefs.remove(authAccessTokenStorageKey);
    await prefs.remove(authRefreshTokenStorageKey);
    await prefs.remove(authAccessExpiresAtStorageKey);
    await prefs.remove(authRefreshExpiresAtStorageKey);
  }

  AuthSessionSecrets _readLegacySecrets(SharedPreferences prefs) {
    final accessToken =
        (prefs.getString(authAccessTokenStorageKey) ?? '').trim();
    final refreshToken =
        (prefs.getString(authRefreshTokenStorageKey) ?? '').trim();
    return AuthSessionSecrets(
      accessToken: accessToken.isEmpty ? null : accessToken,
      refreshToken: refreshToken.isEmpty ? null : refreshToken,
      accessExpiresAt: _parseTime(
        prefs.getString(authAccessExpiresAtStorageKey),
      ),
      refreshExpiresAt: _parseTime(
        prefs.getString(authRefreshExpiresAtStorageKey),
      ),
    );
  }

  Future<AuthSessionSecrets> _readSecretsWithMigration(
    SharedPreferences prefs,
  ) async {
    final secureSecrets = await _secretStore.readSecrets();
    if (!enableLegacyCredentialFallback) {
      return secureSecrets;
    }
    // 旧版本曾把 token 直接放在 SharedPreferences。读取时只迁移缺失的字段：
    // 已在新 secret store 中存在的 access token 必须保持优先，避免回退覆盖新会话。
    final legacySecrets = _readLegacySecrets(prefs);
    if (!legacySecrets.hasAnyValue) {
      return secureSecrets;
    }

    final mergedSecrets = secureSecrets.mergeMissing(legacySecrets);
    if (mergedSecrets.hasAccessToken) {
      // 迁移成功后清理 legacy key，避免下一次启动把过期旧凭证再次合并回来。
      await _secretStore.writeSecrets(mergedSecrets);
      await _clearLegacyCredentialKeys(prefs);
      return mergedSecrets;
    }

    return secureSecrets;
  }

  static DateTime? _parseTime(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value)?.toUtc();
  }
}

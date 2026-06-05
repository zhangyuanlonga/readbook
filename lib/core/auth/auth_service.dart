import 'dart:async';

import '../analytics/analytics_service.dart';
import '../device/device_heartbeat_service.dart';
import '../errors/app_exception.dart';
import '../errors/error_codes.dart';
import '../errors/error_stage.dart';
import '../logging/app_logger.dart';
import '../membership/membership_service.dart';
import '../network/api_client.dart';
import '../network/api_config.dart';
import 'auth_event_bus.dart';
import 'auth_session.dart';
import 'auth_session_store.dart';

class AuthService {
  AuthService({
    ApiClient? client,
    String? baseUrl,
    DeviceHeartbeatService? heartbeatService,
    AnalyticsService? analyticsService,
    MembershipService? membershipService,
    AuthSessionStore? sessionStore,
  }) : _baseUrl = (baseUrl ?? AppApiConfig.baseUrl).trim(),
       _client =
           client ??
           ApiClient(baseUrl: (baseUrl ?? AppApiConfig.baseUrl).trim()),
       _heartbeatService =
           heartbeatService ??
           DeviceHeartbeatService(
             baseUrl: (baseUrl ?? AppApiConfig.baseUrl).trim(),
           ),
       _analyticsService =
           analyticsService ??
           AnalyticsService(baseUrl: (baseUrl ?? AppApiConfig.baseUrl).trim()),
       _membershipService =
           membershipService ??
           MembershipService(baseUrl: (baseUrl ?? AppApiConfig.baseUrl).trim()),
       _sessionStore = sessionStore ?? AuthSessionStore();

  final ApiClient _client;
  final String _baseUrl;
  final DeviceHeartbeatService _heartbeatService;
  final AnalyticsService _analyticsService;
  final MembershipService _membershipService;
  final AuthSessionStore _sessionStore;
  final AppLogger _logger = AppLogger.instance;

  Future<AuthSession> login({
    required String account,
    required String password,
  }) async {
    _ensureBaseUrl();
    final normalizedAccount = account.trim();
    final data = await _client.request<Map<String, dynamic>>(
      method: ApiMethod.post,
      path: '/v1/auth/login',
      body: {
        'account': normalizedAccount,
        'username': normalizedAccount,
        'password': password,
      },
      stage: ErrorStage.unknown,
      decoder: _decodeMap,
    );

    return _resolveSessionIdentity(_parseSession(data));
  }

  Future<AuthSession> loginAndStore({
    required String account,
    required String password,
  }) async {
    final session = await login(account: account, password: password);
    await _persistAuthenticatedSession(session);
    return session;
  }

  Future<AuthSession> register({
    required String account,
    required String password,
    String? displayName,
  }) async {
    _ensureBaseUrl();
    final normalizedAccount = account.trim();
    final normalizedDisplayName = (displayName ?? normalizedAccount).trim();
    final data = await _client.request<Map<String, dynamic>>(
      method: ApiMethod.post,
      path: '/v1/auth/register',
      body: {
        'account': normalizedAccount,
        'username': normalizedAccount,
        'display_name': normalizedDisplayName,
        'password': password,
      },
      stage: ErrorStage.unknown,
      decoder: _decodeMap,
    );

    return _resolveSessionIdentity(_parseSession(data));
  }

  Future<AuthSession> registerAndStore({
    required String account,
    required String password,
    String? displayName,
  }) async {
    final session = await register(
      account: account,
      password: password,
      displayName: displayName,
    );
    await _persistAuthenticatedSession(session);
    return session;
  }

  Future<AuthSession> refresh({String? refreshToken}) async {
    _ensureBaseUrl();
    final resolvedRefreshToken =
        (refreshToken == null || refreshToken.trim().isEmpty)
            ? await _sessionStore.getRefreshToken()
            : refreshToken.trim();
    if (resolvedRefreshToken == null || resolvedRefreshToken.isEmpty) {
      throw const AppException(
        code: ErrorCode.validation,
        briefMessage: '缺少 refresh_token，无法刷新登录态。',
        stage: ErrorStage.unknown,
      );
    }

    final data = await _client.request<Map<String, dynamic>>(
      method: ApiMethod.post,
      path: '/v1/auth/refresh',
      body: {'refresh_token': resolvedRefreshToken},
      stage: ErrorStage.unknown,
      enableAuthRefresh: false,
      decoder: _decodeMap,
    );

    final currentSession = await _sessionStore.getSession();
    return _resolveSessionIdentity(
      _mergeSessionIdentity(_parseSession(data), fallback: currentSession),
    );
  }

  Future<AuthSession> refreshAndStore({String? refreshToken}) async {
    final session = await refresh(refreshToken: refreshToken);
    await _sessionStore.saveSession(session);
    return session;
  }

  Future<void> logout({String? refreshToken}) async {
    _ensureBaseUrl();
    final previousSession = await _sessionStore.getSession();
    final resolvedRefreshToken =
        (refreshToken == null || refreshToken.trim().isEmpty)
            ? await _sessionStore.getRefreshToken()
            : refreshToken.trim();
    if (resolvedRefreshToken == null || resolvedRefreshToken.isEmpty) {
      await _sessionStore.clear();
      AuthEventBus.instance.emitLoggedOut('已退出登录。', previousSession);
      return;
    }
    await _client.request<Map<String, dynamic>>(
      method: ApiMethod.post,
      path: '/v1/auth/logout',
      body: {'refresh_token': resolvedRefreshToken},
      stage: ErrorStage.unknown,
      enableAuthRefresh: false,
      decoder: _decodeMap,
    );
    await _sessionStore.clear();
    AuthEventBus.instance.emitLoggedOut('已退出登录。', previousSession);
  }

  Future<void> _persistAuthenticatedSession(AuthSession session) async {
    final previousSession = await _sessionStore.getSession();
    await _sessionStore.saveSession(session);
    AuthEventBus.instance.emitLoggedIn('登录成功。', session, previousSession);
    // 登录 / 注册成功后的 UI 必须先拿到新 session，设备席位、访问统计等后置任务失败不能拖慢或覆盖账号卡片刷新。
    unawaited(_runPostAuthBootstrap());
  }

  Future<void> _runPostAuthBootstrap() async {
    try {
      await _heartbeatService.sendHeartbeat();
    } catch (error, stackTrace) {
      _logger.warn(
        'Post-auth heartbeat failed',
        context: {
          'error': error.toString(),
          'stackTrace': stackTrace.toString(),
        },
      );
    }

    try {
      await _membershipService.syncCurrentDeviceSeat();
    } catch (error, stackTrace) {
      _logger.warn(
        'Post-auth device seat sync failed',
        context: {
          'error': error.toString(),
          'stackTrace': stackTrace.toString(),
        },
      );
    }

    try {
      await _analyticsService.trackVisit(visitCount: 1, visitSeconds: 0);
    } catch (error, stackTrace) {
      _logger.warn(
        'Post-auth visit tracking failed',
        context: {
          'error': error.toString(),
          'stackTrace': stackTrace.toString(),
        },
      );
    }
  }

  void _ensureBaseUrl() {
    if (_baseUrl.isNotEmpty) {
      return;
    }
    throw const AppException(
      code: ErrorCode.validation,
      briefMessage: '缺少认证服务地址，请配置 APPREAD_API_BASE_URL。',
      stage: ErrorStage.unknown,
    );
  }

  Map<String, dynamic> _decodeMap(Object? data) {
    if (data is Map) {
      return data.map((key, value) => MapEntry(key.toString(), value));
    }
    throw const FormatException('Invalid response payload.');
  }

  AuthSession _parseSession(Map<String, dynamic> data) {
    String? readOptionalStringFrom(Map<String, dynamic> source, String key) {
      final raw = source[key]?.toString().trim() ?? '';
      return raw.isEmpty ? null : raw;
    }

    String? firstNonEmpty(List<String?> values) {
      for (final value in values) {
        final normalized = value?.trim();
        if (normalized != null && normalized.isNotEmpty) {
          return normalized;
        }
      }
      return null;
    }

    final rawUser = data['user'];
    final userData =
        rawUser is Map
            ? rawUser.map((key, value) => MapEntry(key.toString(), value))
            : const <String, dynamic>{};

    String requireString(
      String key, {
      List<String> aliases = const <String>[],
    }) {
      final resolved = firstNonEmpty(<String?>[
        readOptionalStringFrom(data, key),
        for (final alias in aliases) readOptionalStringFrom(data, alias),
        readOptionalStringFrom(userData, key),
        for (final alias in aliases) readOptionalStringFrom(userData, alias),
      ]);
      if (resolved == null) {
        throw FormatException('Missing required field: $key');
      }
      return resolved;
    }

    String? readOptionalString(
      String key, {
      List<String> aliases = const <String>[],
    }) {
      return firstNonEmpty(<String?>[
        readOptionalStringFrom(data, key),
        for (final alias in aliases) readOptionalStringFrom(data, alias),
        readOptionalStringFrom(userData, key),
        for (final alias in aliases) readOptionalStringFrom(userData, alias),
      ]);
    }

    DateTime? readOptionalTime(String key) {
      return _parseTime(
        firstNonEmpty(<String?>[
          readOptionalStringFrom(data, key),
          readOptionalStringFrom(userData, key),
        ]),
      );
    }

    bool? readOptionalBool(String key) {
      for (final raw in <Object?>[data[key], userData[key]]) {
        final value = _parseBool(raw);
        if (value != null) {
          return value;
        }
      }
      return null;
    }

    return AuthSession(
      accessToken: requireString('access_token'),
      refreshToken: readOptionalString('refresh_token'),
      accessExpiresAt: _parseTime(data['access_expires_at']),
      refreshExpiresAt: _parseTime(data['refresh_expires_at']),
      userId: readOptionalString('user_id'),
      username: readOptionalString('username', aliases: <String>['account']),
      account: readOptionalString('account', aliases: <String>['username']),
      displayName: readOptionalString(
        'display_name',
        aliases: <String>['username', 'account'],
      ),
      membershipActive: readOptionalBool('membership_active'),
      vipLevel: readOptionalString('vip_level'),
      planType: readOptionalString('plan_type'),
      vipStatus: readOptionalString('vip_status'),
      vipExpireAt: readOptionalTime('vip_expire_at'),
    );
  }

  Future<AuthSession> _resolveSessionIdentity(AuthSession session) async {
    if (_hasResolvedIdentity(session)) {
      return session;
    }

    final profile = await _fetchCurrentUserIdentity(session.accessToken);
    if (profile == null) {
      return session;
    }

    return _mergeSessionIdentity(session, fallback: profile);
  }

  bool _hasResolvedIdentity(AuthSession session) {
    final userId = session.userId?.trim() ?? '';
    final loginIdentity = session.loginIdentity?.trim() ?? '';
    return userId.isNotEmpty && loginIdentity.isNotEmpty;
  }

  Future<AuthSession?> _fetchCurrentUserIdentity(String accessToken) async {
    try {
      final data = await _client.request<Map<String, dynamic>>(
        method: ApiMethod.get,
        path: '/v1/users/me',
        headers: <String, String>{'Authorization': 'Bearer $accessToken'},
        stage: ErrorStage.unknown,
        enableAuthRefresh: false,
        decoder: _decodeMap,
      );
      final rawUser = data['user'];
      if (rawUser is! Map) {
        return null;
      }
      final userData = rawUser.map(
        (key, value) => MapEntry(key.toString(), value),
      );
      String? read(String key) {
        final raw = userData[key]?.toString().trim() ?? '';
        return raw.isEmpty ? null : raw;
      }

      return AuthSession(
        accessToken: accessToken,
        userId: read('user_id'),
        username: read('username') ?? read('account'),
        account: read('account') ?? read('username'),
        displayName:
            read('display_name') ?? read('username') ?? read('account'),
        membershipActive: _parseBool(userData['membership_active']),
        vipLevel: read('vip_level'),
        planType: read('plan_type'),
        vipStatus: read('vip_status'),
        vipExpireAt: _parseTime(read('vip_expire_at')),
      );
    } catch (_) {
      return null;
    }
  }

  AuthSession _mergeSessionIdentity(
    AuthSession session, {
    AuthSession? fallback,
  }) {
    return AuthSession(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken ?? fallback?.refreshToken,
      accessExpiresAt: session.accessExpiresAt ?? fallback?.accessExpiresAt,
      refreshExpiresAt: session.refreshExpiresAt ?? fallback?.refreshExpiresAt,
      userId: session.userId ?? fallback?.userId,
      username: session.username ?? fallback?.username ?? fallback?.account,
      account: session.account ?? fallback?.account ?? fallback?.username,
      displayName:
          session.displayName ??
          fallback?.displayName ??
          fallback?.username ??
          fallback?.account,
      membershipActive: session.membershipActive ?? fallback?.membershipActive,
      vipLevel: session.vipLevel ?? fallback?.vipLevel,
      planType: session.planType ?? fallback?.planType,
      vipStatus: session.vipStatus ?? fallback?.vipStatus,
      vipExpireAt: session.vipExpireAt ?? fallback?.vipExpireAt,
    );
  }

  DateTime? _parseTime(Object? value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw)?.toUtc();
  }

  bool? _parseBool(Object? value) {
    if (value is bool) {
      return value;
    }
    final raw = value?.toString().trim().toLowerCase() ?? '';
    if (raw.isEmpty) {
      return null;
    }
    if (raw == 'true' || raw == '1') {
      return true;
    }
    if (raw == 'false' || raw == '0') {
      return false;
    }
    return null;
  }
}

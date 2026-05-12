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
    required String username,
    required String password,
  }) async {
    _ensureBaseUrl();
    final data = await _client.request<Map<String, dynamic>>(
      method: ApiMethod.post,
      path: '/v1/auth/login',
      body: {'username': username, 'password': password},
      stage: ErrorStage.unknown,
      decoder: _decodeMap,
    );

    return _parseSession(data);
  }

  Future<AuthSession> loginAndStore({
    required String username,
    required String password,
  }) async {
    final session = await login(username: username, password: password);
    await _persistAuthenticatedSession(session);
    return session;
  }

  Future<AuthSession> register({
    required String username,
    required String password,
  }) async {
    _ensureBaseUrl();
    final data = await _client.request<Map<String, dynamic>>(
      method: ApiMethod.post,
      path: '/v1/auth/register',
      body: {'username': username, 'password': password},
      stage: ErrorStage.unknown,
      decoder: _decodeMap,
    );

    return _parseSession(data);
  }

  Future<AuthSession> registerAndStore({
    required String username,
    required String password,
  }) async {
    final session = await register(username: username, password: password);
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

    return _parseSession(data);
  }

  Future<AuthSession> refreshAndStore({String? refreshToken}) async {
    final session = await refresh(refreshToken: refreshToken);
    await _sessionStore.saveSession(session);
    return session;
  }

  Future<void> logout({String? refreshToken}) async {
    _ensureBaseUrl();
    final resolvedRefreshToken =
        (refreshToken == null || refreshToken.trim().isEmpty)
            ? await _sessionStore.getRefreshToken()
            : refreshToken.trim();
    if (resolvedRefreshToken == null || resolvedRefreshToken.isEmpty) {
      await _sessionStore.clear();
      AuthEventBus.instance.emitLoggedOut();
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
    AuthEventBus.instance.emitLoggedOut();
  }

  Future<void> _persistAuthenticatedSession(AuthSession session) async {
    await _sessionStore.saveSession(session);
    await _runPostAuthBootstrap();
    AuthEventBus.instance.emitLoggedIn();
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
    String requireString(String key) {
      final raw = data[key]?.toString().trim() ?? '';
      if (raw.isEmpty) {
        throw FormatException('Missing required field: $key');
      }
      return raw;
    }

    String? readOptionalString(String key) {
      final raw = data[key]?.toString().trim() ?? '';
      return raw.isEmpty ? null : raw;
    }

    return AuthSession(
      accessToken: requireString('access_token'),
      refreshToken: readOptionalString('refresh_token'),
      accessExpiresAt: _parseTime(data['access_expires_at']),
      refreshExpiresAt: _parseTime(data['refresh_expires_at']),
      userId: requireString('user_id'),
      username: requireString('username'),
    );
  }

  DateTime? _parseTime(Object? value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw)?.toUtc();
  }
}

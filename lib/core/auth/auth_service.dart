import '../device/device_identity_service.dart';
import '../errors/app_exception.dart';
import '../errors/error_codes.dart';
import '../errors/error_stage.dart';
import '../network/api_client.dart';
import '../network/api_config.dart';
import 'auth_event_bus.dart';
import 'auth_session.dart';
import 'auth_session_store.dart';

class AuthService {
  AuthService({
    ApiClient? client,
    String? baseUrl,
    DeviceIdentityService? identityService,
    AuthSessionStore? sessionStore,
  }) : _baseUrl = (baseUrl ?? AppApiConfig.baseUrl).trim(),
       _client =
           client ?? ApiClient(baseUrl: (baseUrl ?? AppApiConfig.baseUrl).trim()),
       _identityService = identityService ?? DeviceIdentityService(),
       _sessionStore = sessionStore ?? AuthSessionStore();

  final ApiClient _client;
  final String _baseUrl;
  final DeviceIdentityService _identityService;
  final AuthSessionStore _sessionStore;

  Future<AuthSession> login({
    required String username,
    required String password,
    String? installId,
  }) async {
    _ensureBaseUrl();
    final resolvedInstallId =
        (installId == null || installId.trim().isEmpty)
            ? await _identityService.getInstallId()
            : installId.trim();

    final data = await _client.request<Map<String, dynamic>>(
      method: ApiMethod.post,
      path: '/v1/auth/login',
      body: {
        'username': username,
        'password': password,
        'install_id': resolvedInstallId,
      },
      stage: ErrorStage.unknown,
      decoder: _decodeMap,
    );

    return _parseSession(data);
  }

  Future<AuthSession> loginAndStore({
    required String username,
    required String password,
    String? installId,
  }) async {
    final session = await login(
      username: username,
      password: password,
      installId: installId,
    );
    await _sessionStore.saveSession(session);
    return session;
  }

  Future<AuthSession> register({
    required String username,
    required String password,
    String? installId,
  }) async {
    _ensureBaseUrl();
    final resolvedInstallId =
        (installId == null || installId.trim().isEmpty)
            ? await _identityService.getInstallId()
            : installId.trim();

    final data = await _client.request<Map<String, dynamic>>(
      method: ApiMethod.post,
      path: '/v1/auth/register',
      body: {
        'username': username,
        'password': password,
        'install_id': resolvedInstallId,
      },
      stage: ErrorStage.unknown,
      decoder: _decodeMap,
    );

    return _parseSession(data);
  }

  Future<AuthSession> registerAndStore({
    required String username,
    required String password,
    String? installId,
  }) async {
    final session = await register(
      username: username,
      password: password,
      installId: installId,
    );
    await _sessionStore.saveSession(session);
    return session;
  }

  Future<AuthSession> refresh({
    String? refreshToken,
  }) async {
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

  Future<void> bindDevice({
    String? accessToken,
    String? installId,
  }) async {
    _ensureBaseUrl();
    final token = (accessToken ?? await _sessionStore.getAccessToken())?.trim();
    if (token == null || token.isEmpty) {
      throw const AppException(
        code: ErrorCode.validation,
        briefMessage: '缺少登录态，无法绑定设备。',
        stage: ErrorStage.unknown,
      );
    }

    final resolvedInstallId =
        (installId == null || installId.trim().isEmpty)
            ? await _identityService.getInstallId()
            : installId.trim();

    await _client.request<Map<String, dynamic>>(
      method: ApiMethod.post,
      path: '/v1/auth/bind-device',
      body: {
        'install_id': resolvedInstallId,
      },
      headers: {'Authorization': 'Bearer $token'},
      stage: ErrorStage.unknown,
      decoder: _decodeMap,
    );
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
    if (data['data'] is Map) {
      data =
          (data['data'] as Map).map((key, value) => MapEntry(key.toString(), value));
    }

    String? tryString(Object? value) {
      final raw = value?.toString().trim() ?? '';
      return raw.isEmpty ? null : raw;
    }

    final accessToken =
        tryString(data['access_token']) ??
        tryString(data['accessToken']) ??
        tryString(data['token']);
    if (accessToken == null) {
      throw const FormatException('Missing access_token in response.');
    }

    String? userId = tryString(data['user_id']) ?? tryString(data['userId']);
    if (userId == null && data['user'] is Map) {
      final userMap = data['user'] as Map;
      userId =
          tryString(userMap['id']) ??
          tryString(userMap['user_id']) ??
          tryString(userMap['uid']);
    }

    final refreshToken =
        tryString(data['refresh_token']) ?? tryString(data['refreshToken']);
    final accessExpiresAt = _parseTime(data['access_expires_at']);
    final refreshExpiresAt = _parseTime(data['refresh_expires_at']);
    final username =
        tryString(data['username']) ??
        (data['user'] is Map ? tryString((data['user'] as Map)['username']) : null);

    return AuthSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      accessExpiresAt: accessExpiresAt,
      refreshExpiresAt: refreshExpiresAt,
      userId: userId,
      username: username,
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

import '../auth/auth_session_store.dart';
import '../device/device_identity_service.dart';
import '../errors/app_exception.dart';
import '../errors/error_codes.dart';
import '../errors/error_stage.dart';
import '../network/api_client.dart';
import '../network/api_config.dart';
import '../reader/reader_identity_service.dart';

class AnalyticsService {
  AnalyticsService({
    ApiClient? client,
    String? baseUrl,
    DeviceIdentityService? identityService,
    AuthSessionStore? sessionStore,
    ReaderIdentityService? readerIdentityService,
  }) : _baseUrl = (baseUrl ?? AppApiConfig.baseUrl).trim(),
       _client =
           client ?? ApiClient(baseUrl: (baseUrl ?? AppApiConfig.baseUrl).trim()),
       _identityService = identityService ?? DeviceIdentityService(),
       _sessionStore = sessionStore ?? AuthSessionStore(),
       _readerIdentityService = readerIdentityService ?? ReaderIdentityService();

  static const String _defaultChannel = 'stable';

  final ApiClient _client;
  final String _baseUrl;
  final DeviceIdentityService _identityService;
  final AuthSessionStore _sessionStore;
  final ReaderIdentityService _readerIdentityService;

  Future<void> trackAppOpen({
    String? channel,
    String? userId,
    String? readerId,
    DateTime? occurredAt,
  }) async {
    _ensureBaseUrl();
    final identity = await _identityService.loadIdentity();
    final resolvedUserId = userId ?? await _sessionStore.getUserId();
    final cachedReader = await _readerIdentityService.getCachedIdentity();
    final resolvedReaderId = readerId ?? cachedReader?.id;

    final payload = <String, dynamic>{
      'install_id': identity.installId,
      'platform': identity.platform,
      'channel': (channel == null || channel.trim().isEmpty)
          ? _defaultChannel
          : channel.trim(),
      'app_version': identity.appVersion,
      'occurred_at':
          (occurredAt ?? DateTime.now().toUtc()).toIso8601String(),
    };

    if (resolvedUserId != null && resolvedUserId.trim().isNotEmpty) {
      payload['user_id'] = resolvedUserId.trim();
    }
    if (resolvedReaderId != null && resolvedReaderId.trim().isNotEmpty) {
      payload['reader_id'] = resolvedReaderId.trim();
    }

    await _client.request<Map<String, dynamic>>(
      method: ApiMethod.post,
      path: '/v1/analytics/app-open',
      body: payload,
      stage: ErrorStage.unknown,
      decoder: _decodeMap,
    );
  }

  Future<void> trackVisit({
    String? channel,
    String? userId,
    String? readerId,
    DateTime? occurredAt,
  }) async {
    _ensureBaseUrl();
    final identity = await _identityService.loadIdentity();
    final resolvedUserId = userId ?? await _sessionStore.getUserId();
    final cachedReader = await _readerIdentityService.getCachedIdentity();
    final resolvedReaderId = readerId ?? cachedReader?.id;

    final payload = <String, dynamic>{
      'install_id': identity.installId,
      'platform': identity.platform,
      'channel': (channel == null || channel.trim().isEmpty)
          ? _defaultChannel
          : channel.trim(),
      'app_version': identity.appVersion,
      'occurred_at':
          (occurredAt ?? DateTime.now().toUtc()).toIso8601String(),
    };

    if (resolvedUserId != null && resolvedUserId.trim().isNotEmpty) {
      payload['user_id'] = resolvedUserId.trim();
    }
    if (resolvedReaderId != null && resolvedReaderId.trim().isNotEmpty) {
      payload['reader_id'] = resolvedReaderId.trim();
    }

    await _client.request<Map<String, dynamic>>(
      method: ApiMethod.post,
      path: '/v1/analytics/visit',
      body: payload,
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
      briefMessage: '缺少统计服务地址，请配置 APPREAD_API_BASE_URL。',
      stage: ErrorStage.unknown,
    );
  }

  Map<String, dynamic> _decodeMap(Object? data) {
    if (data is Map) {
      return data.map((key, value) => MapEntry(key.toString(), value));
    }
    return const <String, dynamic>{};
  }
}

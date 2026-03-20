import '../auth/auth_session_store.dart';
import '../device/device_identity_service.dart';
import '../errors/app_exception.dart';
import '../errors/error_codes.dart';
import '../errors/error_stage.dart';
import '../network/api_client.dart';
import '../network/api_config.dart';
import '../network/api_time.dart';

class AnalyticsService {
  AnalyticsService({
    ApiClient? client,
    String? baseUrl,
    DeviceIdentityService? identityService,
    AuthSessionStore? sessionStore,
  }) : _baseUrl = (baseUrl ?? AppApiConfig.baseUrl).trim(),
       _client =
           client ??
           ApiClient(baseUrl: (baseUrl ?? AppApiConfig.baseUrl).trim()),
       _identityService = identityService ?? DeviceIdentityService(),
       _sessionStore = sessionStore ?? AuthSessionStore();

  static const String _defaultChannel = 'stable';

  final ApiClient _client;
  final String _baseUrl;
  final DeviceIdentityService _identityService;
  final AuthSessionStore _sessionStore;

  Future<void> trackVisit({
    String? channel,
    DateTime? occurredAt,
    int visitCount = 1,
    int visitSeconds = 0,
  }) async {
    _ensureBaseUrl();
    final identity = await _identityService.loadIdentity();
    final accessToken = (await _sessionStore.getAccessToken())?.trim();

    final payload = <String, dynamic>{
      'install_id': identity.installId,
      'platform': identity.platform,
      'channel':
          (channel == null || channel.trim().isEmpty)
              ? _defaultChannel
              : channel.trim(),
      'app_version': identity.appVersion,
      'visit_count': visitCount < 0 ? 0 : visitCount,
      'visit_seconds': visitSeconds < 0 ? 0 : visitSeconds,
      'occurred_at': formatApiTimeUtc(occurredAt ?? DateTime.now()),
    };

    await _client.request<Map<String, dynamic>>(
      method: ApiMethod.post,
      path: '/v1/analytics/visit',
      body: payload,
      headers: {
        if (accessToken != null && accessToken.isNotEmpty)
          'Authorization': 'Bearer $accessToken',
      },
      stage: ErrorStage.unknown,
      enableAuthRefresh: accessToken != null && accessToken.isNotEmpty,
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

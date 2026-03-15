import '../errors/app_exception.dart';
import '../errors/error_codes.dart';
import '../errors/error_stage.dart';
import '../network/api_client.dart';
import '../network/api_config.dart';
import 'device_identity_service.dart';

class DeviceHeartbeatService {
  DeviceHeartbeatService({
    ApiClient? client,
    String? baseUrl,
    DeviceIdentityService? identityService,
  }) : _baseUrl = (baseUrl ?? AppApiConfig.baseUrl).trim(),
       _client =
           client ?? ApiClient(baseUrl: (baseUrl ?? AppApiConfig.baseUrl).trim()),
       _identityService = identityService ?? DeviceIdentityService();

  final ApiClient _client;
  final String _baseUrl;
  final DeviceIdentityService _identityService;

  Future<void> sendHeartbeat() async {
    _ensureBaseUrl();
    final identity = await _identityService.loadIdentity();
    await _client.request<Map<String, dynamic>>(
      method: ApiMethod.post,
      path: '/v1/devices/heartbeat',
      body: identity.toHeartbeatPayload(),
      stage: ErrorStage.unknown,
      decoder: (data) => _decodeMap(data),
    );
  }

  void _ensureBaseUrl() {
    if (_baseUrl.isNotEmpty) {
      return;
    }
    throw const AppException(
      code: ErrorCode.validation,
      briefMessage: '缺少设备服务地址，请配置 APPREAD_API_BASE_URL。',
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

import '../device/device_identity_service.dart';
import '../errors/app_exception.dart';
import '../errors/error_codes.dart';
import '../errors/error_stage.dart';
import '../network/api_client.dart';
import '../network/api_config.dart';
import 'app_update_check_result.dart';

class AppUpdateService {
  AppUpdateService({
    ApiClient? client,
    String? baseUrl,
    DeviceIdentityService? identityService,
  }) : _baseUrl = (baseUrl ?? AppApiConfig.baseUrl).trim(),
       _client =
           client ??
           ApiClient(baseUrl: (baseUrl ?? AppApiConfig.baseUrl).trim()),
       _identityService = identityService ?? DeviceIdentityService();

  final ApiClient _client;
  final String _baseUrl;
  final DeviceIdentityService _identityService;

  Future<AppUpdateCheckResult> checkUpdate({String? appName}) async {
    _ensureBaseUrl();
    final versionCode = await _identityService.getAppVersionCode();
    final identity = await _identityService.loadIdentity();
    final resolvedAppName =
        (appName ?? AppApiConfig.appName).trim().isEmpty
            ? AppApiConfig.appName
            : (appName ?? AppApiConfig.appName).trim();

    final data = await _client.request<Map<String, dynamic>>(
      method: ApiMethod.post,
      path: '/v1/app-updates/check',
      body: {
        'app_name': resolvedAppName,
        'version_code': versionCode,
        'platform': identity.platform,
      },
      stage: ErrorStage.unknown,
      decoder: _decodeMap,
    );

    return AppUpdateCheckResult.fromJson(data, currentVersionCode: versionCode);
  }

  void _ensureBaseUrl() {
    if (_baseUrl.isNotEmpty) {
      return;
    }
    throw const AppException(
      code: ErrorCode.validation,
      briefMessage: '缺少更新服务地址，请配置 APPREAD_API_BASE_URL。',
      stage: ErrorStage.unknown,
    );
  }

  Map<String, dynamic> _decodeMap(Object? data) {
    if (data is Map) {
      return data.map((key, value) => MapEntry(key.toString(), value));
    }
    throw const FormatException('Invalid response payload.');
  }
}

import '../errors/app_exception.dart';
import '../errors/error_codes.dart';
import '../errors/error_stage.dart';
import '../network/api_client.dart';
import '../network/api_config.dart';
import 'mobile_feature_module.dart';

class MobileFeatureService {
  MobileFeatureService({ApiClient? client, String? baseUrl})
    : _baseUrl = (baseUrl ?? AppApiConfig.baseUrl).trim(),
      _client =
          client ??
          ApiClient(baseUrl: (baseUrl ?? AppApiConfig.baseUrl).trim());

  final ApiClient _client;
  final String _baseUrl;

  Future<List<MobileFeatureModule>> fetchMyModules() async {
    _ensureBaseUrl();
    final data = await _client.request<Map<String, dynamic>>(
      method: ApiMethod.get,
      path: '/v1/mobile-feature-modules/me',
      attachAccessToken: true,
      stage: ErrorStage.unknown,
      decoder: _decodeMap,
    );
    final rawItems = data['items'];
    if (rawItems is! List) {
      return const <MobileFeatureModule>[];
    }
    return rawItems
        .whereType<Map>()
        .map(
          (item) => MobileFeatureModule.fromJson(
            item.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .toList(growable: false);
  }

  Future<List<MobileFeatureModule>> fetchPublicModules() async {
    _ensureBaseUrl();
    final data = await _client.request<Map<String, dynamic>>(
      method: ApiMethod.get,
      path: '/v1/mobile-feature-modules/public',
      attachAccessToken: false,
      stage: ErrorStage.unknown,
      decoder: _decodeMap,
    );
    final rawItems = data['items'];
    if (rawItems is! List) {
      return const <MobileFeatureModule>[];
    }
    return rawItems
        .whereType<Map>()
        .map(
          (item) => MobileFeatureModule.fromJson(
            item.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .toList(growable: false);
  }

  void _ensureBaseUrl() {
    if (_baseUrl.isNotEmpty) {
      return;
    }
    throw const AppException(
      code: ErrorCode.validation,
      briefMessage: '缺少功能模块服务地址，请配置 APPREAD_API_BASE_URL。',
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

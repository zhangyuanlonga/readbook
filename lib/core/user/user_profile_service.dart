import '../errors/app_exception.dart';
import '../errors/error_codes.dart';
import '../errors/error_stage.dart';
import '../network/api_client.dart';
import '../network/api_config.dart';
import 'user_profile.dart';

class UserProfileService {
  UserProfileService({ApiClient? client, String? baseUrl})
    : _baseUrl = (baseUrl ?? AppApiConfig.baseUrl).trim(),
      _client =
          client ??
          ApiClient(baseUrl: (baseUrl ?? AppApiConfig.baseUrl).trim());

  final ApiClient _client;
  final String _baseUrl;

  Future<UserProfile> fetchMe() async {
    _ensureBaseUrl();
    final data = await _client.request<Map<String, dynamic>>(
      method: ApiMethod.get,
      path: '/v1/users/me',
      attachAccessToken: true,
      stage: ErrorStage.unknown,
      decoder: _decodeMap,
    );
    return UserProfile.fromJson(data);
  }

  void _ensureBaseUrl() {
    if (_baseUrl.isNotEmpty) {
      return;
    }
    throw const AppException(
      code: ErrorCode.validation,
      briefMessage: '缺少用户服务地址，请配置 APPREAD_API_BASE_URL。',
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

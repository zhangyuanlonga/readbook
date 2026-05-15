import '../errors/app_exception.dart';
import '../errors/error_codes.dart';
import '../errors/error_stage.dart';
import '../network/api_client.dart';
import '../network/api_config.dart';
import 'user_profile.dart';

class UserProfileUpdateInput {
  const UserProfileUpdateInput({
    required this.account,
    required this.displayName,
    required this.phone,
    required this.email,
    required this.password,
  });

  final String account;
  final String displayName;
  final String phone;
  final String email;
  final String password;
}

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

  Future<UserProfile> updateProfile(
    UserProfileUpdateInput input, {
    String? userId,
  }) async {
    _ensureBaseUrl();
    final payload = <String, dynamic>{
      'account': input.account.trim(),
      'display_name': input.displayName.trim(),
      'phone': input.phone.trim(),
      'email': input.email.trim(),
      if (input.password.trim().isNotEmpty) 'password': input.password.trim(),
    };

    Map<String, dynamic> data;
    try {
      data = await _client.request<Map<String, dynamic>>(
        method: ApiMethod.patch,
        path: '/v1/users/me',
        attachAccessToken: true,
        stage: ErrorStage.unknown,
        body: payload,
        decoder: _decodeMap,
      );
    } on ApiException catch (error) {
      final normalizedUserId = userId?.trim() ?? '';
      if (!_shouldFallbackToUserId(error) || normalizedUserId.isEmpty) {
        rethrow;
      }
      data = await _client.request<Map<String, dynamic>>(
        method: ApiMethod.patch,
        path: '/v1/users/$normalizedUserId',
        attachAccessToken: true,
        stage: ErrorStage.unknown,
        body: payload,
        decoder: _decodeMap,
      );
    }

    final rawUser = data['user'];
    if (rawUser is Map) {
      return UserProfile.fromJson(<String, dynamic>{'user': rawUser});
    }
    return UserProfile.fromJson(<String, dynamic>{'user': data});
  }

  bool _shouldFallbackToUserId(ApiException error) {
    return error.statusCode == 404 || error.apiCode == 'NOT_FOUND';
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

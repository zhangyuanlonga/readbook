import '../errors/app_exception.dart';
import '../errors/error_codes.dart';
import '../errors/error_stage.dart';
import '../auth/auth_session_store.dart';
import '../network/api_client.dart';
import '../network/api_config.dart';
import 'user_profile.dart';

class UserProfileUpdateInput {
  const UserProfileUpdateInput({
    required this.displayName,
    required this.phone,
    required this.email,
    required this.password,
  });

  final String displayName;
  final String phone;
  final String email;
  final String password;
}

class UserProfileService {
  UserProfileService({
    ApiClient? client,
    String? baseUrl,
    AuthSessionStore? sessionStore,
  }) : _baseUrl = (baseUrl ?? AppApiConfig.baseUrl).trim(),
       _client =
           client ??
           ApiClient(baseUrl: (baseUrl ?? AppApiConfig.baseUrl).trim()),
       _sessionStore = sessionStore;

  final ApiClient _client;
  final String _baseUrl;
  final AuthSessionStore? _sessionStore;

  Future<UserProfile> fetchMe() async {
    _ensureBaseUrl();
    final headers = await _authHeaders();
    final data = await _client.requestSpec(
      ApiRequestSpec.jsonObject(
        method: ApiMethod.get,
        path: '/v1/users/me',
        headers: headers,
        attachAccessToken: true,
        stage: ErrorStage.unknown,
      ),
    );
    return UserProfile.fromJson(data);
  }

  Future<UserProfile> updateProfile(
    UserProfileUpdateInput input, {
    String? userId,
  }) async {
    _ensureBaseUrl();
    final headers = await _authHeaders();
    final payload = <String, dynamic>{
      'display_name': input.displayName.trim(),
      'phone': input.phone.trim(),
      'email': input.email.trim(),
      if (input.password.trim().isNotEmpty) 'password': input.password.trim(),
    };

    Map<String, dynamic> data;
    try {
      data = await _client.requestSpec(
        ApiRequestSpec.jsonObject(
          method: ApiMethod.patch,
          path: '/v1/users/me',
          headers: headers,
          attachAccessToken: true,
          stage: ErrorStage.unknown,
          body: payload,
        ),
      );
    } on ApiException catch (error) {
      final normalizedUserId = userId?.trim() ?? '';
      if (!_shouldFallbackToUserId(error) || normalizedUserId.isEmpty) {
        rethrow;
      }
      data = await _client.requestSpec(
        ApiRequestSpec.jsonObject(
          method: ApiMethod.patch,
          path: '/v1/users/$normalizedUserId',
          headers: headers,
          attachAccessToken: true,
          stage: ErrorStage.unknown,
          body: payload,
        ),
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

  Future<Map<String, String>> _authHeaders() async {
    final token = (await _sessionStore?.getAccessToken())?.trim() ?? '';
    if (token.isEmpty) {
      return const <String, String>{};
    }
    return <String, String>{'Authorization': 'Bearer $token'};
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
}

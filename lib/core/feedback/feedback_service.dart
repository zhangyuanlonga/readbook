import '../auth/auth_session_store.dart';
import '../device/device_identity_service.dart';
import '../errors/app_exception.dart';
import '../errors/error_codes.dart';
import '../errors/error_stage.dart';
import '../network/api_client.dart';
import '../network/api_config.dart';
import 'feedback_models.dart';

class FeedbackService {
  FeedbackService({
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

  final ApiClient _client;
  final String _baseUrl;
  final DeviceIdentityService _identityService;
  final AuthSessionStore _sessionStore;

  Future<FeedbackListPage> fetchFeedbackList({
    String? keyword,
    String? type,
    String? status,
    int page = 1,
    int pageSize = 20,
  }) async {
    _ensureBaseUrl();
    final identity = await _identityService.loadIdentity();
    final accessToken = (await _sessionStore.getAccessToken())?.trim();

    final data = await _client.request<Map<String, dynamic>>(
      method: ApiMethod.get,
      path: '/v1/feedback',
      queryParameters: {
        'install_id': identity.installId,
        if (keyword != null && keyword.trim().isNotEmpty)
          'keyword': keyword.trim(),
        if (type != null && type.trim().isNotEmpty) 'type': type.trim(),
        if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
        'page': page < 1 ? 1 : page,
        'page_size': pageSize < 1 ? 20 : pageSize,
      },
      headers: {
        if (accessToken != null && accessToken.isNotEmpty)
          'Authorization': 'Bearer $accessToken',
      },
      enableAuthRefresh: accessToken != null && accessToken.isNotEmpty,
      stage: ErrorStage.unknown,
      decoder: _decodeMap,
    );

    return FeedbackListPage.fromJson(data);
  }

  Future<FeedbackListItem> submitFeedback({
    String? type,
    required String title,
    required String content,
  }) async {
    _ensureBaseUrl();
    final identity = await _identityService.loadIdentity();
    final accessToken = (await _sessionStore.getAccessToken())?.trim();
    final normalizedTitle = title.trim();
    final normalizedContent = content.trim();
    final normalizedType =
        (type == null || type.trim().isEmpty)
            ? FeedbackType.issue.apiValue
            : type.trim();

    if (normalizedTitle.isEmpty || normalizedContent.isEmpty) {
      throw const AppException(
        code: ErrorCode.validation,
        briefMessage: '请完整填写标题和问题描述。',
        stage: ErrorStage.unknown,
      );
    }

    final data = await _client.request<Map<String, dynamic>>(
      method: ApiMethod.post,
      path: '/v1/feedback',
      body: {
        'type': normalizedType,
        'title': normalizedTitle,
        'content': normalizedContent,
        'install_id': identity.installId,
        'platform': identity.platform,
        'app_version': identity.appVersion,
        'device_model': identity.deviceModel,
      },
      headers: {
        if (accessToken != null && accessToken.isNotEmpty)
          'Authorization': 'Bearer $accessToken',
      },
      enableAuthRefresh: accessToken != null && accessToken.isNotEmpty,
      stage: ErrorStage.unknown,
      decoder: _decodeMap,
    );

    return FeedbackListItem.fromJson(data);
  }

  Future<FeedbackListItem> fetchFeedbackDetail(String id) async {
    _ensureBaseUrl();
    final normalizedId = id.trim();
    if (normalizedId.isEmpty) {
      throw const AppException(
        code: ErrorCode.validation,
        briefMessage: '缺少反馈标识。',
        stage: ErrorStage.unknown,
      );
    }
    final identity = await _identityService.loadIdentity();
    final accessToken = (await _sessionStore.getAccessToken())?.trim();

    final data = await _client.request<Map<String, dynamic>>(
      method: ApiMethod.get,
      path: '/v1/feedback/$normalizedId',
      queryParameters: <String, dynamic>{'install_id': identity.installId},
      headers: {
        if (accessToken != null && accessToken.isNotEmpty)
          'Authorization': 'Bearer $accessToken',
      },
      enableAuthRefresh: accessToken != null && accessToken.isNotEmpty,
      stage: ErrorStage.unknown,
      decoder: _decodeMap,
    );
    return FeedbackListItem.fromJson(data);
  }

  void _ensureBaseUrl() {
    if (_baseUrl.isNotEmpty) {
      return;
    }
    throw const AppException(
      code: ErrorCode.validation,
      briefMessage: '缺少反馈服务地址，请配置 APPREAD_API_BASE_URL。',
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

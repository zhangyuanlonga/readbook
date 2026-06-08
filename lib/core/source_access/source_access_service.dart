import '../errors/error_stage.dart';
import '../network/api_client.dart';
import '../network/api_config.dart';
import 'source_access_scope.dart';

class SourceAccessService {
  SourceAccessService({ApiClient? client, String? baseUrl})
    : _client =
          client ??
          ApiClient(baseUrl: (baseUrl ?? AppApiConfig.baseUrl).trim());

  final ApiClient _client;

  Future<SourceAccessScope> fetchMyScope() {
    return _client.request<SourceAccessScope>(
      method: ApiMethod.get,
      path: '/v1/me/source-access',
      attachAccessToken: true,
      enableRetry: false,
      stage: ErrorStage.source,
      decoder: (data) {
        if (data is! Map) {
          throw const FormatException('Invalid source access scope.');
        }
        return SourceAccessScope.fromJson(
          data.map((key, value) => MapEntry(key.toString(), value)),
        );
      },
    );
  }
}

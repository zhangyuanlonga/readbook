import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/core/errors/error_stage.dart';
import 'package:shuxiang_reading_next/core/network/api_client.dart';
import 'package:shuxiang_reading_next/features/search/application/server_book_gateway_service.dart';

void main() {
  test(
    'loadContent requests full chapter content for server gateway reading',
    () async {
      final client = _FakeGatewayApiClient();
      final service = ServerBookGatewayService(client: client);

      await service.loadContent(
        sourceId: 'server-gateway:source_a',
        bookId: 'book_1',
        detailUrl: 'https://example.com/book/1',
        chapterUrl: 'https://example.com/book/1/c1',
        chapterIndex: 0,
        chapterTitle: '第一章',
      );

      expect(client.method, ApiMethod.post);
      expect(client.path, 'v1/books/content');
      final body = client.body as Map<String, Object?>;
      final options = body['options'] as Map<String, Object?>;
      expect(options['followNextContent'], isTrue);
      expect(options['includeImages'], isTrue);
      expect(options['format'], 'auto');
      expect(options['timeoutMs'], 45000);
      expect(client.stage, ErrorStage.content);
    },
  );
}

class _FakeGatewayApiClient extends ApiClient {
  ApiMethod? method;
  String? path;
  Object? body;
  ErrorStage? stage;

  @override
  Future<T> request<T>({
    required ApiMethod method,
    required String path,
    Map<String, dynamic> queryParameters = const {},
    Object? body,
    Map<String, String> headers = const {},
    Duration? timeout,
    int? maxRetries,
    bool enableRetry = true,
    bool enableCache = false,
    Duration? cacheTtl,
    bool attachAccessToken = false,
    bool enableAuthRefresh = true,
    ErrorStage stage = ErrorStage.unknown,
    T Function(Object? data)? decoder,
  }) async {
    this.method = method;
    this.path = path;
    this.body = body;
    this.stage = stage;
    final payload = <String, Object?>{
      'content': '正文内容',
      'contentType': 'novel',
      'format': 'plain',
      'sourceReport': <String, Object?>{'cacheHit': false},
    };
    return decoder!(payload);
  }
}

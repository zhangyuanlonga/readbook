import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/core/errors/error_stage.dart';
import 'package:shuxiang_reading_next/core/network/api_client.dart';
import 'package:shuxiang_reading_next/features/source/application/source_runtime_session_service.dart';

void main() {
  group('SourceRuntimeSessionService', () {
    test(
      'submits cookie and login headers to gateway session endpoint',
      () async {
        final client =
            _FakeApiClient()
              ..responses.add(<String, Object?>{
                'sourceUrl': 'https://source.example',
                'hasCookie': true,
                'hasHeaders': true,
                'hasLoginInfo': false,
                'hasSourceVariable': false,
                'headerNames': <Object?>['Authorization', 'X-Token'],
                'cookieScope': 'sourceAndHost',
                'sessionPolicy': 'shortRuntimeCookieAndHeaderOnly',
                'updatedAt': 1710000000000,
                'ttlSeconds': 1800,
              });
        final service = SourceRuntimeSessionService(client: client);

        final snapshot = await service.submitSession(
          sourceId: 'server-gateway:https://source.example',
          cookie: ' sid=abc ',
          headers: const <String, String>{'X-Token': '  token  ', ' ': 'skip'},
          loginHeaderJson: '{"Authorization":"Bearer abc"}',
        );

        expect(client.calls, hasLength(1));
        final call = client.calls.single;
        expect(call.method, ApiMethod.put);
        expect(call.path, 'v1/sources/https%3A%2F%2Fsource.example/session');
        expect(call.stage, ErrorStage.source);
        final body = call.body as Map<String, Object?>;
        expect(body.containsKey('bookSourceUrl'), isFalse);
        expect(body['cookie'], 'sid=abc');
        expect(body['loginHeaderJson'], '{"Authorization":"Bearer abc"}');
        expect(body['headers'], <String, String>{'X-Token': 'token'});
        expect(snapshot.hasCookie, isTrue);
        expect(snapshot.hasHeaders, isTrue);
        expect(snapshot.headerNames, <String>['Authorization', 'X-Token']);
        expect(snapshot.cookieScope, 'sourceAndHost');
      },
    );

    test('loads and clears source runtime session', () async {
      final client =
          _FakeApiClient()
            ..responses.addAll(<Object?>[
              <String, Object?>{
                'sourceUrl': 'https://source.example',
                'hasCookie': true,
                'hasHeaders': false,
                'hasLoginInfo': true,
                'hasSourceVariable': false,
                'headerNames': <Object?>[],
                'cookieScope': 'source',
                'sessionPolicy': 'shortRuntimeHeaderOnly',
                'ttlSeconds': 1800,
              },
              <String, Object?>{
                'sourceUrl': 'https://source.example',
                'hasCookie': false,
                'hasHeaders': false,
                'hasLoginInfo': false,
                'hasSourceVariable': false,
                'headerNames': <Object?>[],
                'cookieScope': 'source',
                'sessionPolicy': 'shortRuntimeHeaderOnly',
                'ttlSeconds': 1800,
              },
            ]);
      final service = SourceRuntimeSessionService(client: client);

      final loaded = await service.loadSession(sourceId: 'source_a');
      final cleared = await service.clearSession(sourceId: 'source_a');

      expect(loaded.hasCookie, isTrue);
      expect(loaded.hasLoginInfo, isTrue);
      expect(cleared.hasCookie, isFalse);
      expect(client.calls[0].method, ApiMethod.get);
      expect(client.calls[0].path, 'v1/sources/source_a/session');
      expect(client.calls[1].method, ApiMethod.delete);
      expect(client.calls[1].path, 'v1/sources/source_a/session');
    });

    test('creates login task from gateway login-task endpoint', () async {
      final client =
          _FakeApiClient()
            ..responses.add(<String, Object?>{
              'taskId': 'login-1',
              'sourceId': 'src',
              'sourceName': '测试源',
              'mode': 'webView',
              'loginUrl': 'https://example.com/login',
              'request': {
                'url': 'https://example.com/login',
                'method': 'post',
                'headers': {'User-Agent': 'reader'},
                'body': 'next=/book',
              },
            });
      final service = SourceRuntimeSessionService(client: client);

      final task = await service.createLoginTask(
        sourceId: 'server-gateway:src',
      );

      expect(client.calls.single.method, ApiMethod.get);
      expect(client.calls.single.path, 'v1/sources/src/login-task');
      expect(task.taskId, 'login-1');
      expect(task.sourceId, 'src');
      expect(task.sourceName, '测试源');
      expect(task.mode, 'webView');
      expect(task.loginUrl, 'https://example.com/login');
      expect(task.request?.method, 'POST');
      expect(task.request?.headers, {'User-Agent': 'reader'});
      expect(task.request?.body, 'next=/book');
    });
  });
}

class _FakeApiClient extends ApiClient {
  final List<_ApiCall> calls = <_ApiCall>[];
  final List<Object?> responses = <Object?>[];

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
    calls.add(_ApiCall(method: method, path: path, body: body, stage: stage));
    final response = responses.removeAt(0);
    if (decoder == null) {
      return response as T;
    }
    return decoder(response);
  }
}

class _ApiCall {
  const _ApiCall({
    required this.method,
    required this.path,
    required this.body,
    required this.stage,
  });

  final ApiMethod method;
  final String path;
  final Object? body;
  final ErrorStage stage;
}

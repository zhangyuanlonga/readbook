import 'dart:async';

import 'package:flutter_appread/core/webview/webview_executor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WebViewExecutor', () {
    test('reuses pooled sessions and balances worker load', () async {
      final createdWorkers = <int>[];
      final callWorkers = <int>[];
      final executor = WebViewExecutor(
        poolSize: 2,
        sessionFactory: (workerIndex) {
          createdWorkers.add(workerIndex);
          return _FakeWebViewSession(
            workerIndex: workerIndex,
            onLoad: (request, timeout) async {
              callWorkers.add(workerIndex);
              return WebViewResponsePayload(
                statusCode: 200,
                body: 'w$workerIndex:${request.url}',
                finalUrl: request.url,
              );
            },
          );
        },
      );

      final first = await executor.load(
        request: const WebViewRequestPayload(url: 'https://example.com/1'),
      );
      final second = await executor.load(
        request: const WebViewRequestPayload(url: 'https://example.com/2'),
      );
      final third = await executor.load(
        request: const WebViewRequestPayload(url: 'https://example.com/3'),
      );
      final fourth = await executor.load(
        request: const WebViewRequestPayload(url: 'https://example.com/4'),
      );

      expect(first.body, 'w0:https://example.com/1');
      expect(second.body, 'w1:https://example.com/2');
      expect(third.body, 'w0:https://example.com/3');
      expect(fourth.body, 'w1:https://example.com/4');

      expect(createdWorkers.length, 2);
      expect(createdWorkers.toSet(), <int>{0, 1});
      expect(callWorkers, <int>[0, 1, 0, 1]);

      await executor.dispose();
    });

    test('resets failed session and continues processing', () async {
      var factoryCallCount = 0;
      final executor = WebViewExecutor(
        poolSize: 1,
        sessionFactory: (workerIndex) {
          factoryCallCount += 1;
          return _FakeWebViewSession(
            workerIndex: workerIndex,
            onLoad: (request, timeout) async {
              if (request.url.endsWith('/slow')) {
                await Future<void>.delayed(const Duration(milliseconds: 50));
                throw TimeoutException('timeout');
              }
              return WebViewResponsePayload(
                statusCode: 200,
                body: 'ok',
                finalUrl: request.url,
              );
            },
          );
        },
      );

      await expectLater(
        executor.load(
          request: const WebViewRequestPayload(
            url: 'https://example.com/slow',
            timeout: Duration(milliseconds: 10),
          ),
        ),
        throwsA(isA<TimeoutException>()),
      );

      final response = await executor.load(
        request: const WebViewRequestPayload(url: 'https://example.com/fast'),
      );

      expect(response.body, 'ok');
      expect(factoryCallCount, 2);

      await executor.dispose();
    });

    test('disposes pooled sessions and rejects new requests', () async {
      final sessions = <_FakeWebViewSession>[];
      final executor = WebViewExecutor(
        poolSize: 1,
        sessionFactory: (workerIndex) {
          final session = _FakeWebViewSession(
            workerIndex: workerIndex,
            onLoad: (request, timeout) async {
              return WebViewResponsePayload(
                statusCode: 200,
                body: 'done',
                finalUrl: request.url,
              );
            },
          );
          sessions.add(session);
          return session;
        },
      );

      await executor.load(
        request: const WebViewRequestPayload(url: 'https://example.com/start'),
      );
      await executor.dispose();

      expect(sessions, hasLength(1));
      expect(sessions.single.disposedCount, 1);
      await expectLater(
        executor.load(
          request: const WebViewRequestPayload(url: 'https://example.com/next'),
        ),
        throwsA(isA<StateError>()),
      );
    });
  });
}

class _FakeWebViewSession implements WebViewSession {
  _FakeWebViewSession({required this.workerIndex, required this.onLoad});

  final int workerIndex;
  final Future<WebViewResponsePayload> Function(
    WebViewRequestPayload request,
    Duration timeout,
  )
  onLoad;

  var disposedCount = 0;

  @override
  Future<WebViewResponsePayload> load({
    required WebViewRequestPayload request,
    required Duration timeout,
  }) {
    return onLoad(request, timeout);
  }

  @override
  Future<void> dispose() async {
    disposedCount += 1;
  }
}

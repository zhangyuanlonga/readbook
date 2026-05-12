import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/source/application/source_runtime_request_execution_container.dart';
import 'package:shuxiang_reading_next/runtime/browser/browser_runtime.dart';
import 'package:shuxiang_reading_next/runtime/cache/cache_policy.dart';
import 'package:shuxiang_reading_next/runtime/http/challenge_detector.dart';
import 'package:shuxiang_reading_next/runtime/http/http_models.dart';
import 'package:shuxiang_reading_next/runtime/http/request_engine.dart';
import 'package:shuxiang_reading_next/runtime/session/source_session.dart';

void main() {
  group('SourceRuntimeRequestExecutionContainer', () {
    test('clears session and cache on dispose', () {
      final container = SourceRuntimeRequestExecutionContainer(
        sourceId: 'source-1',
        requestEngine: const _FakeRequestEngine(),
        browserRuntime: const UnsupportedBrowserRuntime(),
      );

      container.session.set('token', 'abc');
      container.session.setCookie('sid', 'cookie');
      container.cacheManager.put<String>(
        key: 'search:1',
        sourceId: 'source-1',
        step: CacheStep.search,
        value: 'cached-result',
      );

      container.dispose();

      expect(container.session.get<String>('token'), isNull);
      expect(container.session.cookies, isEmpty);
      expect(container.cacheManager.get<String>('search:1'), isNull);
    });
  });
}

class _FakeRequestEngine implements RequestEngine {
  const _FakeRequestEngine();

  @override
  Future<RuntimeHttpResponse> request(
    RuntimeHttpRequest request, {
    SourceSession? session,
  }) async {
    throw UnimplementedError();
  }

  @override
  bool isHtml(RuntimeHttpResponse response) => false;

  @override
  bool isJson(RuntimeHttpResponse response) => false;

  @override
  bool isRedirect(RuntimeHttpResponse response) => false;

  @override
  bool isChallenge(RuntimeHttpResponse response) => false;

  @override
  ChallengeDetectionResult detectChallenge(RuntimeHttpResponse response) {
    return const ChallengeDetectionResult(isChallenge: false);
  }
}

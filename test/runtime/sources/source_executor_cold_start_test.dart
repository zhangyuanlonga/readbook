import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/runtime/browser/browser_runtime.dart';
import 'package:shuxiang_reading_next/runtime/cache/cache_manager.dart';
import 'package:shuxiang_reading_next/runtime/http/challenge_detector.dart';
import 'package:shuxiang_reading_next/runtime/http/http_models.dart';
import 'package:shuxiang_reading_next/runtime/http/request_engine.dart';
import 'package:shuxiang_reading_next/runtime/session/session_manager.dart';
import 'package:shuxiang_reading_next/runtime/session/source_session.dart';
import 'package:shuxiang_reading_next/runtime/sources/source_contract.dart';
import 'package:shuxiang_reading_next/runtime/sources/source_executor.dart';
import 'package:shuxiang_reading_next/runtime/sources/source_manifest.dart';
import 'package:shuxiang_reading_next/runtime/sources/source_registry.dart';
import 'package:shuxiang_reading_next/runtime/sources/source_result_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SourceExecutor cold start gate', () {
    setUp(() {
      SourceExecutor.debugResetColdStartGate();
    });

    test('serializes first cold search runs across sources', () async {
      final searchOneCompleter = Completer<List<Book>>();
      final searchTwoCompleter = Completer<List<Book>>();
      var sourceOneStarted = false;
      var sourceTwoStarted = false;

      final executor = SourceExecutor(
        requestEngine: const _FakeRequestEngine(),
        sessionManager: InMemorySessionManager(),
        cacheManager: InMemoryCacheManager(),
        browserRuntime: const UnsupportedBrowserRuntime(),
      );

      final sourceOne = RegisteredSource(
        runtime: const SourceRuntimeInfo(
          id: 'source_one',
          name: '源一',
          group: '测试',
          revision: 'test',
        ),
        definition: RuntimeSourceDefinition(
          manifest: const SourceManifest(
            name: '源一',
            group: '测试',
            author: 'tester',
            description: '',
          ),
          search: (_, __) async {
            sourceOneStarted = true;
            return searchOneCompleter.future;
          },
          detail: (_, book) async => book,
          chapters: (_, __) async => const <Chapter>[],
          content: (_, __, chapter) async =>
              Content(title: chapter.title, content: ''),
        ),
      );

      final sourceTwo = RegisteredSource(
        runtime: const SourceRuntimeInfo(
          id: 'source_two',
          name: '源二',
          group: '测试',
          revision: 'test',
        ),
        definition: RuntimeSourceDefinition(
          manifest: const SourceManifest(
            name: '源二',
            group: '测试',
            author: 'tester',
            description: '',
          ),
          search: (_, __) async {
            sourceTwoStarted = true;
            return searchTwoCompleter.future;
          },
          detail: (_, book) async => book,
          chapters: (_, __) async => const <Chapter>[],
          content: (_, __, chapter) async =>
              Content(title: chapter.title, content: ''),
        ),
      );

      final futureOne = executor.search(sourceOne, '凡人');
      final futureTwo = executor.search(sourceTwo, '凡人');

      await Future<void>.delayed(Duration.zero);
      expect(sourceOneStarted, isTrue);
      expect(sourceTwoStarted, isFalse);

      searchOneCompleter.complete(const <Book>[]);
      await Future<void>.delayed(Duration.zero);
      expect(sourceTwoStarted, isTrue);

      searchTwoCompleter.complete(const <Book>[]);
      await futureOne;
      await futureTwo;
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

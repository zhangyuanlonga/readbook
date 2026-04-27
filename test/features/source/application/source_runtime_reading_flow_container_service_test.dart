import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/source/application/source_runtime_reading_flow_container_service.dart';
import 'package:shuxiang_reading_next/features/source/application/source_runtime_request_execution_container.dart';
import 'package:shuxiang_reading_next/runtime/browser/browser_runtime.dart';
import 'package:shuxiang_reading_next/runtime/http/challenge_detector.dart';
import 'package:shuxiang_reading_next/runtime/http/http_models.dart';
import 'package:shuxiang_reading_next/runtime/http/request_engine.dart';
import 'package:shuxiang_reading_next/runtime/session/source_session.dart';
import 'package:shuxiang_reading_next/runtime/sources/source_contract.dart';
import 'package:shuxiang_reading_next/runtime/sources/source_manifest.dart';
import 'package:shuxiang_reading_next/runtime/sources/source_registry.dart';
import 'package:shuxiang_reading_next/runtime/sources/source_result_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(<String, Object>{});

  group('SourceRuntimeReadingFlowContainerService', () {
    test(
      'disposes flow container after delay instead of immediately',
      () async {
        var requestDisposed = 0;
        var sourceDisposed = 0;

        final requestContainer = SourceRuntimeRequestExecutionContainer(
          sourceId: 'source-1',
          requestEngine: const _FakeRequestEngine(),
          browserRuntime: const UnsupportedBrowserRuntime(),
          onDispose: () {
            requestDisposed += 1;
          },
        );

        final container = SourceRuntimeReadingFlowExecutionContainer(
          sourceId: 'source-1',
          flowKey: 'source-1::detail:https%3A%2F%2Fexample.com%2Fbook%2F1',
          source: RegisteredSource(
            runtime: const SourceRuntimeInfo(
              id: 'source-1',
              name: '测试源',
              group: '测试',
              revision: 'test',
            ),
            definition: RuntimeSourceDefinition(
              manifest: const SourceManifest(
                name: '测试源',
                group: '测试',
                author: 'tester',
                description: '',
              ),
              search: (_, __) async => const <Book>[],
              detail: (_, book) async => book,
              chapters: (_, __) async => const <Chapter>[],
              content:
                  (_, __, chapter) async =>
                      Content(title: chapter.title, content: ''),
              dispose: () {
                sourceDisposed += 1;
              },
            ),
          ),
          requestContainer: requestContainer,
        );

        final service = SourceRuntimeReadingFlowContainerService(
          disposalDelay: const Duration(milliseconds: 20),
        );
        service.put(container);

        service.clearFlow(
          sourceId: 'source-1',
          book: const Book(
            title: '测试书',
            author: '',
            detailUrl: 'https://example.com/book/1',
          ),
        );

        expect(requestDisposed, 0);
        expect(sourceDisposed, 0);

        await Future<void>.delayed(const Duration(milliseconds: 40));

        expect(requestDisposed, 1);
        expect(sourceDisposed, 1);
      },
    );
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

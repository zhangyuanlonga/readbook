import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/source/application/script_source_runtime_service.dart';
import 'package:shuxiang_reading_next/runtime/browser/browser_runtime.dart';
import 'package:shuxiang_reading_next/runtime/http/challenge_detector.dart';
import 'package:shuxiang_reading_next/runtime/http/http_models.dart';
import 'package:shuxiang_reading_next/runtime/http/request_engine.dart';
import 'package:shuxiang_reading_next/runtime/session/source_session.dart';
import 'package:shuxiang_reading_next/runtime/sources/source_contract.dart';
import 'package:shuxiang_reading_next/runtime/sources/source_manifest.dart';
import 'package:shuxiang_reading_next/runtime/sources/source_result_models.dart';
import 'package:shuxiang_reading_next/runtime/sources/source_script_compiler.dart';

void main() {
  group('ScriptSourceRuntimeService reading flow container', () {
    test('reuses session and compiled source across detail chapters content', () async {
      final compiler = _FakeFlowScriptCompiler();
      final service = ScriptSourceRuntimeService(
        requestEngine: const _FakeRequestEngine(),
        browserRuntime: const UnsupportedBrowserRuntime(),
        scriptCompiler: compiler,
      );

      const originalBook = Book(
        title: '凡人修仙传',
        author: '忘语',
      );

      final detailedBook = await service.detailIsolated(
        sourceId: 'source-1',
        sourceCode: 'export default {}',
        book: originalBook,
      );
      final chapters = await service.chaptersIsolated(
        sourceId: 'source-1',
        sourceCode: 'export default {}',
        book: detailedBook,
      );
      final content = await service.contentIsolated(
        sourceId: 'source-1',
        sourceCode: 'export default {}',
        book: detailedBook,
        chapter: chapters.first,
      );

      expect(detailedBook.detailUrl, 'https://example.com/book/1');
      expect(chapters, hasLength(1));
      expect(content.content, contains('session-ok'));
      expect(compiler.compileCount, 1);
    });

    test('clears reading flow and recreates container on next entry', () async {
      final compiler = _FakeFlowScriptCompiler();
      final service = ScriptSourceRuntimeService(
        requestEngine: const _FakeRequestEngine(),
        browserRuntime: const UnsupportedBrowserRuntime(),
        scriptCompiler: compiler,
      );

      const originalBook = Book(
        title: '凡人修仙传',
        author: '忘语',
      );

      final detailedBook = await service.detailIsolated(
        sourceId: 'source-1',
        sourceCode: 'export default {}',
        book: originalBook,
      );

      service.clearReadingFlow(
        sourceId: 'source-1',
        detailUrl: detailedBook.detailUrl,
        title: detailedBook.title,
      );

      await service.detailIsolated(
        sourceId: 'source-1',
        sourceCode: 'export default {}',
        book: originalBook,
      );

      expect(compiler.compileCount, 2);
    });

    test('does not reuse flow across different books', () async {
      final compiler = _FakeFlowScriptCompiler();
      final service = ScriptSourceRuntimeService(
        requestEngine: const _FakeRequestEngine(),
        browserRuntime: const UnsupportedBrowserRuntime(),
        scriptCompiler: compiler,
      );

      const firstBook = Book(
        title: '凡人修仙传',
        author: '忘语',
        detailUrl: 'https://example.com/book/1',
      );
      const secondBook = Book(
        title: '斗破苍穹',
        author: '天蚕土豆',
        detailUrl: 'https://example.com/book/2',
      );

      await service.detailIsolated(
        sourceId: 'source-1',
        sourceCode: 'export default {}',
        book: firstBook,
      );
      await service.detailIsolated(
        sourceId: 'source-1',
        sourceCode: 'export default {}',
        book: secondBook,
      );

      expect(compiler.compileCount, 2);
    });
  });
}

class _FakeFlowScriptCompiler extends SourceScriptCompiler {
  int compileCount = 0;

  @override
  Future<RuntimeSourceDefinition> compile(String sourceCode) async {
    compileCount += 1;
    return RuntimeSourceDefinition(
      manifest: const SourceManifest(
        name: '测试源',
        group: '测试',
        author: 'tester',
        description: '',
      ),
      search: (_, __) async => const <Book>[],
      detail: (ctx, book) async {
        ctx.session.set('flow-token', 'session-ok');
        return book.copyWith(
          detailUrl: 'https://example.com/book/1',
          tocUrl: 'https://example.com/book/1/catalog',
        );
      },
      chapters: (ctx, book) async {
        if (ctx.session.get<String>('flow-token') != 'session-ok') {
          throw StateError('missing reading flow session');
        }
        return const <Chapter>[
          Chapter(
            title: '第一章',
            url: 'https://example.com/book/1/ch1',
            index: 0,
          ),
        ];
      },
      content: (ctx, book, chapter) async {
        final token = ctx.session.get<String>('flow-token');
        if (token != 'session-ok') {
          throw StateError('missing reading flow session');
        }
        return Content(title: chapter.title, content: 'content:$token');
      },
    );
  }
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

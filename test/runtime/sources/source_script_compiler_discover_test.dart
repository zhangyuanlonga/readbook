import 'package:flutter_appread/runtime/browser/browser_runtime.dart';
import 'package:flutter_appread/runtime/cache/cache_manager.dart';
import 'package:flutter_appread/runtime/crypto/source_crypto.dart';
import 'package:flutter_appread/runtime/html/html_runtime.dart';
import 'package:flutter_appread/runtime/http/challenge_detector.dart';
import 'package:flutter_appread/runtime/http/http_models.dart';
import 'package:flutter_appread/runtime/http/request_engine.dart';
import 'package:flutter_appread/runtime/session/source_session.dart';
import 'package:flutter_appread/runtime/sources/source_contract.dart';
import 'package:flutter_appread/runtime/sources/source_manifest.dart';
import 'package:flutter_appread/runtime/sources/source_result_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_appread/runtime/sources/source_script_compiler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SourceScriptCompiler discover capability', () {
    const compiler = SourceScriptCompiler();

    test(
      'auto adds discover capability when discover method pair exists',
      () async {
        final definition = await compiler.compile(_sourceWithImplicitDiscover);

        expect(definition.manifest.supportsCapability('discover'), isTrue);
        expect(definition.discoverCategories, isNotNull);
        expect(definition.discoverBooks, isNotNull);
      },
    );

    test(
      'throws when discover capability is declared without method pair',
      () async {
        await expectLater(
          () => compiler.compile(_sourceWithBrokenDeclaredDiscover),
          throwsA(
            isA<SourceScriptCompileException>().having(
              (error) => error.message,
              'message',
              contains('meta.capabilities 声明了 discover'),
            ),
          ),
        );
      },
    );

    test(
      'throws when discover methods are not implemented as a pair',
      () async {
        await expectLater(
          () => compiler.compile(_sourceWithHalfDiscoverMethods),
          throwsA(
            isA<SourceScriptCompileException>().having(
              (error) => error.message,
              'message',
              contains('必须成对实现'),
            ),
          ),
        );
      },
    );

    test('chapters use array order as index and preserve isVolume', () async {
      final definition = await compiler.compile(_sourceWithChapterMeta);
      final chapters = await definition.chapters(_buildRuntimeContext(), _book);

      expect(chapters, hasLength(3));
      expect(chapters[0].index, 0);
      expect(chapters[1].index, 1);
      expect(chapters[2].index, 2);
      expect(chapters[0].isVolume, isTrue);
      expect(chapters[1].isVolume, isFalse);
      expect(chapters[2].isVolume, isFalse);
    });
  });
}

SourceRuntimeContext _buildRuntimeContext() {
  final session = SourceSession(sourceId: 'test_source');
  final manifest = const SourceManifest(
    name: '测试源',
    group: '测试',
    author: 'tester',
    description: '',
  );

  return SourceRuntimeContext(
    source: const SourceRuntimeInfo(
      id: 'test_source',
      name: '测试源',
      group: '测试',
      revision: 'test',
    ),
    http: SourceHttpContext(
      requestEngine: const _FakeRequestEngine(),
      session: session,
      manifest: manifest,
      browserRuntime: const UnsupportedBrowserRuntime(),
    ),
    browser: SourceBrowserContext(
      browserRuntime: const UnsupportedBrowserRuntime(),
      session: session,
    ),
    cookie: SourceCookieContext(session: session),
    cache: SourceCacheContext(
      cacheStore: CacheStoreContext(cacheManager: InMemoryCacheManager()),
      sourceId: 'test_source',
    ),
    html: const DefaultHtmlRuntime(),
    session: session,
    utils: const SourceUtilsContext(),
    crypto: SourceCryptoContext(),
    log: (_) {},
  );
}

const Book _book = Book(title: '测试书', author: '', detailUrl: 'https://book');

const String _sourceWithImplicitDiscover = '''
export default {
  meta: {
    name: '隐式发现源',
    group: '测试',
    author: 'tester',
    description: '',
    capabilities: ['search', 'detail', 'chapters', 'content'],
  },
  async discoverCategories(ctx) { return []; },
  async discoverBooks(ctx, category, page, pageSize) { return []; },
  async search(ctx, keyword) { return []; },
  async detail(ctx, book) { return book; },
  async chapters(ctx, book) { return []; },
  async content(ctx, book, chapter) { return { title: chapter.title || '', content: '' }; },
};
''';

const String _sourceWithBrokenDeclaredDiscover = '''
export default {
  meta: {
    name: '错误发现源',
    group: '测试',
    author: 'tester',
    description: '',
    capabilities: ['search', 'detail', 'chapters', 'content', 'discover'],
  },
  async search(ctx, keyword) { return []; },
  async detail(ctx, book) { return book; },
  async chapters(ctx, book) { return []; },
  async content(ctx, book, chapter) { return { title: chapter.title || '', content: '' }; },
};
''';

const String _sourceWithHalfDiscoverMethods = '''
export default {
  meta: {
    name: '半套发现源',
    group: '测试',
    author: 'tester',
    description: '',
    capabilities: ['search', 'detail', 'chapters', 'content'],
  },
  async discoverCategories(ctx) { return []; },
  async search(ctx, keyword) { return []; },
  async detail(ctx, book) { return book; },
  async chapters(ctx, book) { return []; },
  async content(ctx, book, chapter) { return { title: chapter.title || '', content: '' }; },
};
''';

const String _sourceWithChapterMeta = '''
export default {
  meta: {
    name: '章节元数据测试源',
    group: '测试',
    author: 'tester',
    description: '',
    capabilities: ['search', 'detail', 'chapters', 'content'],
  },
  async search(ctx, keyword) { return []; },
  async detail(ctx, book) { return book; },
  async chapters(ctx, book) {
    return [
      { title: '第一卷', url: '', isVolume: true, index: 99 },
      { title: '第一章', url: 'https://example.com/1', index: 99 },
      { title: '第二章', url: 'https://example.com/2' },
    ];
  },
  async content(ctx, book, chapter) { return { title: chapter.title || '', content: '' }; },
};
''';

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

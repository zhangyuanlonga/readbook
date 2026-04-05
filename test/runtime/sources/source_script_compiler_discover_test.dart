import 'package:shuxiang_reading_next/runtime/browser/browser_runtime.dart';
import 'package:shuxiang_reading_next/runtime/cache/cache_manager.dart';
import 'package:shuxiang_reading_next/runtime/crypto/source_crypto.dart';
import 'package:shuxiang_reading_next/runtime/html/html_runtime.dart';
import 'package:shuxiang_reading_next/runtime/http/challenge_detector.dart';
import 'package:shuxiang_reading_next/runtime/http/http_models.dart';
import 'package:shuxiang_reading_next/runtime/http/request_engine.dart';
import 'package:shuxiang_reading_next/runtime/sources/source_registry.dart';
import 'package:shuxiang_reading_next/runtime/session/source_session.dart';
import 'package:shuxiang_reading_next/runtime/sources/source_contract.dart';
import 'package:shuxiang_reading_next/runtime/sources/source_manifest.dart';
import 'package:shuxiang_reading_next/runtime/sources/source_result_models.dart';
import 'package:shuxiang_reading_next/src/js_runtime.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuxiang_reading_next/runtime/sources/source_script_compiler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(<String, Object>{});
  SourceScriptCompiler.debugResetSharedRunners();

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

  group('SourceScriptCompiler runtime isolation', () {
    late _FakeReusableJsRuntimeAdapterFactory factory;

    setUp(() {
      factory = _FakeReusableJsRuntimeAdapterFactory();
      debugJsRuntimeAdapterFactory = factory.create;
      SourceScriptCompiler.debugResetSharedRunners();
    });

    tearDown(() {
      debugJsRuntimeAdapterFactory = null;
      SourceScriptCompiler.debugResetSharedRunners();
    });

    test('reuses runtime for repeated search calls on same definition', () async {
      const compiler = SourceScriptCompiler();
      final definition = await compiler.compile(_sourceWithImplicitDiscover);

      await definition.search(_buildRuntimeContext(), '凡人');
      await definition.search(_buildRuntimeContext(), '凡人');

      expect(factory.createdCount, 2);
      expect(factory.disposedCount, 1);

      definition.dispose?.call();
      expect(factory.disposedCount, 2);
    });

    test('disposes reused runtime when source is removed from registry', () async {
      const compiler = SourceScriptCompiler();
      final definition = await compiler.compile(_sourceWithImplicitDiscover);
      final registry = SourceRegistry();
      registry.upsert('test_source', definition);

      await definition.search(_buildRuntimeContext(), '凡人');
      expect(factory.createdCount, 2);

      registry.remove('test_source');
      expect(factory.disposedCount, 2);
    });

    test('does not reuse runtime across identical compiled definitions', () async {
      const compiler = SourceScriptCompiler();
      final definitionA = await compiler.compile(_sourceWithImplicitDiscover);
      final definitionB = await compiler.compile(_sourceWithImplicitDiscover);

      await definitionA.search(_buildRuntimeContext(), '凡人');
      await definitionB.search(_buildRuntimeContext(), '作者');

      expect(factory.createdCount, 4);
      expect(factory.disposedCount, 2);

      definitionA.dispose?.call();
      expect(factory.disposedCount, 3);

      definitionB.dispose?.call();
      expect(factory.disposedCount, 4);
    });

    test('binds implicit ctx and source variables before invocation', () async {
      const compiler = SourceScriptCompiler();
      final definition = await compiler.compile(_sourceWithImplicitDiscover);

      await definition.search(_buildRuntimeContext(), '凡人');

      expect(factory.lastInstalledBootstrapSource, contains('var ctx = undefined;'));
      expect(factory.lastInstalledBootstrapSource, contains('var source = undefined;'));
      expect(factory.lastRunSnippet, contains('ctx = __ctx;'));
      expect(factory.lastRunSnippet, contains('source = __source;'));
      expect(factory.lastRunSnippet, contains('globalThis.ctx = __ctx;'));
      expect(factory.lastRunSnippet, contains('globalThis.source = __source;'));
      expect(factory.lastRunSnippet, contains('ctx = undefined;'));
      expect(factory.lastRunSnippet, contains('source = undefined;'));
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

class _FakeReusableJsRuntimeAdapterFactory {
  int createdCount = 0;
  int disposedCount = 0;
  String? lastRunSnippet;
  String? lastInstalledBootstrapSource;

  JsRuntimeAdapter create() {
    createdCount += 1;
    return _FakeReusableJsRuntimeAdapter(
      onInstallBootstrap: (source, sourceUrl) {
        if (sourceUrl == 'source_debugger_bootstrap.js') {
          lastInstalledBootstrapSource = source;
        }
      },
      onRunSnippet: (script) {
        lastRunSnippet = script;
      },
      onDispose: () {
        disposedCount += 1;
      },
    );
  }
}

class _FakeReusableJsRuntimeAdapter implements JsRuntimeAdapter {
  _FakeReusableJsRuntimeAdapter({
    required this.onDispose,
    required this.onInstallBootstrap,
    required this.onRunSnippet,
  });

  final void Function() onDispose;
  final void Function(String source, String? sourceUrl) onInstallBootstrap;
  final void Function(String script) onRunSnippet;
  String _installedSource = '';

  @override
  bool get isSupported => true;

  @override
  String? get unsupportedReason => null;

  @override
  Future<void> installBootstrap(String source, {String? sourceUrl}) async {
    onInstallBootstrap(source, sourceUrl);
    if (sourceUrl == 'pasted_source.js') {
      _installedSource = source;
    }
  }

  @override
  Future<void> installPlaygroundBootstrap() async {}

  @override
  void registerBridge(String channelName, JsBridgeHandler handler) {}

  @override
  Future<JsExecutionResult> runSnippet(String script) async {
    onRunSnippet(script);
    if (script.contains('hasSearch:')) {
      return JsExecutionResult(
        output:
            '{"meta":{"name":"测试源","group":"测试","author":"tester","description":""},"hasInit":false,"hasDiscoverCategories":${_installedSource.contains('discoverCategories')},'
            '"hasDiscoverBooks":${_installedSource.contains('discoverBooks')},'
            '"hasSearch":${_installedSource.contains('search(ctx, keyword)') || _installedSource.contains('search(ctx,keyword)')},'
            '"hasDetail":${_installedSource.contains('detail(ctx, book)') || _installedSource.contains('detail(ctx,book)')},'
            '"hasChapters":${_installedSource.contains('chapters(ctx, book)') || _installedSource.contains('chapters(ctx,book)')},'
            '"hasContent":${_installedSource.contains('content(ctx, book, chapter)') || _installedSource.contains('content(ctx,book,chapter)')}}',
        isError: false,
      );
    }

    if (script.contains("__source?.['search']") ||
        script.contains("__sourceDefinition?.['search']")) {
      return const JsExecutionResult(output: '[]', isError: false);
    }
    if (script.contains("__source?.['chapters']") ||
        script.contains("__sourceDefinition?.['chapters']")) {
      return const JsExecutionResult(output: '[]', isError: false);
    }
    if (script.contains("__source?.['detail']") ||
        script.contains("__sourceDefinition?.['detail']")) {
      return const JsExecutionResult(
        output: '{"title":"测试书","author":"","detailUrl":"https://book","tocUrl":"","extra":{},"debug":{}}',
        isError: false,
      );
    }
    if (script.contains("__source?.['content']") ||
        script.contains("__sourceDefinition?.['content']")) {
      return const JsExecutionResult(
        output: '{"title":"第一章","content":"正文"}',
        isError: false,
      );
    }

    return const JsExecutionResult(output: 'null', isError: false);
  }

  @override
  void dispose() {
    onDispose();
  }
}

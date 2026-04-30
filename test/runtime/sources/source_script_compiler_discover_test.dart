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

    test('accepts Android-style double encoded inspection payload', () async {
      final factory =
          _FakeReusableJsRuntimeAdapterFactory()
            ..inspectionOutputOverride =
                '"{\\"meta\\":{\\"name\\":\\"测试源\\",\\"group\\":\\"测试\\",\\"author\\":\\"tester\\",\\"description\\":\\"\\"},\\"hasInit\\":false,\\"hasDiscoverCategories\\":true,\\"hasDiscoverBooks\\":true,\\"hasSearch\\":true,\\"hasDetail\\":true,\\"hasChapters\\":true,\\"hasContent\\":true}"';
      debugJsRuntimeAdapterFactory = factory.create;
      addTearDown(() {
        debugJsRuntimeAdapterFactory = null;
      });

      final definition = await compiler.compile(_sourceWithImplicitDiscover);

      expect(definition.manifest.name, '测试源');
      expect(definition.discoverCategories, isNotNull);
      expect(definition.discoverBooks, isNotNull);
    });

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

    test('crypto byte helpers are available to source scripts', () async {
      final definition = await compiler.compile(_sourceWithCryptoByteHelpers);

      final books = await definition.search(_buildRuntimeContext(), '任意');

      expect(books, hasLength(1));
      expect(books.single.title, '97,98,99|abc|YWJj');
    });

    test('source login and book state bridges are available', () async {
      final definition = await compiler.compile(_sourceWithLoginStateHelpers);
      final context = _buildRuntimeContext();

      final books = await definition.search(context, '任意');
      expect(books.single.title, '{"token":"abc"}|{"账号":"foo"}|{"tab":"小说"}');

      final detailed = await definition.detail(context, books.single);
      expect(detailed.extra['customBefore'], '');
      expect(detailed.extra['customAfter'], '{"mode":"vip"}');

      final content = await definition.content(
        context,
        detailed,
        const Chapter(title: '第一章', url: 'https://chapter/1', index: 0),
      );
      expect(content.content, '{"mode":"vip"}');
    });

    test('ui bridges are available to source scripts', () async {
      final definition = await compiler.compile(_sourceWithUiHelpers);
      final events = <String>[];
      final context = _buildRuntimeContext(
        ui: SourceUiContext(
          toastHandler: (message) async => events.add('toast:$message'),
          longToastHandler: (message) async => events.add('long:$message'),
          openBrowserAwaitHandler: ({
            required String url,
            String? title,
            bool refetchAfterSuccess = true,
            String? html,
          }) async {
            events.add('browser:$url|$title|$refetchAfterSuccess');
            return <String, Object?>{
              'statusCode': 200,
              'body': 'browser-body',
              'finalUrl': url,
            };
          },
          verificationCodeHandler: (imageUrl) async {
            events.add('verify:$imageUrl');
            return '7788';
          },
        ),
      );

      final books = await definition.search(context, '任意');
      expect(books.single.title, '7788');
      expect(
        events,
        containsAll(<String>[
          'toast:hello',
          'long:world',
          'browser:https://example.com/login|登录|false',
          'verify:https://example.com/code.png',
        ]),
      );
    });

    test('convenience helper apis are available to source scripts', () async {
      final definition = await compiler.compile(_sourceWithConvenienceHelpers);

      final books = await definition.search(_buildRuntimeContext(), '任意');

      expect(
        books.single.title,
        '39470278_53e7dd36e624ed3cda64ff5fe095a3da|foo|小说|小说|1|2|done|picked|39470278_53e7dd36e624ed3cda64ff5fe095a3da|abc',
      );
    });

    test(
      'extended login and ui helper apis are available to source scripts',
      () async {
        final definition = await compiler.compile(_sourceWithExtendedHelpers);
        final events = <String>[];
        final context = _buildRuntimeContext(
          ui: SourceUiContext(
            openUrlHandler: ({required String url, String? title}) async {
              events.add('open:$url|$title');
            },
            alertHandler: ({
              required String message,
              String? title,
              String? confirmText,
            }) async {
              events.add('alert:$message|$title|$confirmText');
            },
            confirmHandler: ({
              required String message,
              String? title,
              String? confirmText,
              String? cancelText,
            }) async {
              events.add('confirm:$message|$title|$confirmText|$cancelText');
              return true;
            },
            promptHandler: ({
              required String message,
              String? title,
              String? initialValue,
              String? confirmText,
              String? cancelText,
              bool obscureText = false,
            }) async {
              events.add(
                'prompt:$message|$title|$initialValue|$confirmText|$cancelText|$obscureText',
              );
              return 'typed';
            },
          ),
        );

        final books = await definition.search(context, '任意');

        expect(books.single.title, 'bar|小说|vip|typed');
        expect(
          events,
          containsAll(<String>[
            'open:https://example.com/help|帮助',
            'alert:当前仅支持最小宿主提示|提示|知道了',
            'confirm:确认清空？|提示|确认|取消',
            'prompt:请输入验证码|验证码|1234|确定|返回|false',
          ]),
        );
      },
    );

    test('loginCheckJs can update login state and replay request', () async {
      final definition = await compiler.compile(_sourceWithLoginCheckHelpers);
      final engine = _FakeSequenceRequestEngine(<RuntimeHttpResponse>[
        RuntimeHttpResponse(
          ok: true,
          status: 200,
          uri: Uri.parse('https://example.com/search'),
          headers: const <String, String>{'content-type': 'application/json'},
          text: '{"statusCode":301}',
        ),
        RuntimeHttpResponse(
          ok: true,
          status: 200,
          uri: Uri.parse('https://example.com/search'),
          headers: const <String, String>{'content-type': 'text/plain'},
          text: 'ok-search',
        ),
      ]);
      final context = _buildRuntimeContext(
        requestEngine: engine,
        sourceId: 'login_check_source',
      );

      final books = await definition.search(context, '任意');

      expect(books.single.title, 'ok-search|{"Authorization":"Bearer ok"}');
      expect(engine.requests, hasLength(2));
      expect(engine.requests.last.headers['Authorization'], 'Bearer ok');
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

    test(
      'reuses runtime for repeated search calls on same definition',
      () async {
        const compiler = SourceScriptCompiler();
        final definition = await compiler.compile(_sourceWithImplicitDiscover);

        await definition.search(_buildRuntimeContext(), '凡人');
        await definition.search(_buildRuntimeContext(), '凡人');

        expect(factory.createdCount, 2);
        expect(factory.disposedCount, 1);

        definition.dispose?.call();
        expect(factory.disposedCount, 2);
      },
    );

    test(
      'disposes reused runtime when source is removed from registry',
      () async {
        const compiler = SourceScriptCompiler();
        final definition = await compiler.compile(_sourceWithImplicitDiscover);
        final registry = SourceRegistry();
        registry.upsert('test_source', definition);

        await definition.search(_buildRuntimeContext(), '凡人');
        expect(factory.createdCount, 2);

        registry.remove('test_source');
        expect(factory.disposedCount, 2);
      },
    );

    test(
      'does not reuse runtime across identical compiled definitions',
      () async {
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
      },
    );

    test('binds implicit ctx and source variables before invocation', () async {
      const compiler = SourceScriptCompiler();
      final definition = await compiler.compile(_sourceWithImplicitDiscover);

      await definition.search(_buildRuntimeContext(), '凡人');

      expect(
        factory.lastInstalledBootstrapSource,
        contains('var ctx = undefined;'),
      );
      expect(
        factory.lastInstalledBootstrapSource,
        contains('var source = undefined;'),
      );
      expect(
        factory.lastInstalledBootstrapSource,
        contains('var book = undefined;'),
      );
      expect(
        factory.lastInstalledBootstrapSource,
        contains('var chapter = undefined;'),
      );
      expect(
        factory.lastInstalledBootstrapSource,
        contains(
          'function sanitizeForHost(value, depth, seen, stats, rootMethodName)',
        ),
      );
      expect(
        factory.lastInstalledBootstrapSource,
        contains("if (depth === 0 && rootMethodName === 'chapters')"),
      );
      expect(
        factory.lastInstalledBootstrapSource,
        contains(
          'globalThis.__appreadEncodeHostSuccess = function(value, methodName)',
        ),
      );
      expect(
        factory.lastInstalledBootstrapSource,
        contains('hexDecode(value, options = {})'),
      );
      expect(
        factory.lastInstalledBootstrapSource,
        contains('base64Decode(value, options = {})'),
      );
      expect(
        factory.lastInstalledBootstrapSource,
        contains('symmetricEncrypt(options)'),
      );
      expect(
        factory.lastInstalledBootstrapSource,
        contains('asymmetricEncrypt(options)'),
      );
      expect(factory.lastRunSnippet, contains('ctx = __ctx;'));
      expect(factory.lastRunSnippet, contains('source = __source;'));
      expect(factory.lastRunSnippet, contains('globalThis.ctx = __ctx;'));
      expect(factory.lastRunSnippet, contains('globalThis.source = __source;'));
      expect(
        factory.lastRunSnippet,
        contains('globalThis.book = __currentBook;'),
      );
      expect(
        factory.lastRunSnippet,
        contains('globalThis.chapter = __currentChapter;'),
      );
      expect(
        factory.lastRunSnippet,
        contains(
          "return globalThis.__appreadEncodeHostSuccess(__rawResult, 'search');",
        ),
      );
      expect(
        factory.lastRunSnippet,
        contains('return globalThis.__appreadEncodeHostFailure(error);'),
      );
      expect(factory.lastRunSnippet, contains('ctx = undefined;'));
      expect(factory.lastRunSnippet, contains('source = undefined;'));
      expect(factory.lastRunSnippet, contains('book = undefined;'));
      expect(factory.lastRunSnippet, contains('chapter = undefined;'));
    });

    test('unwraps runtime error envelope into compile exception', () async {
      factory.searchOutputOverride = '{"ok":false,"error":"规则异常：返回值不可安全序列化"}';
      const compiler = SourceScriptCompiler();
      final definition = await compiler.compile(_sourceWithImplicitDiscover);

      await expectLater(
        () => definition.search(_buildRuntimeContext(), '凡人'),
        throwsA(
          isA<SourceScriptCompileException>().having(
            (error) => error.message,
            'message',
            contains('返回值不可安全序列化'),
          ),
        ),
      );
    });

    test('accepts Android-style double encoded runtime envelope', () async {
      factory.searchOutputOverride = '"{\\"ok\\":true,\\"value\\":[]}"';
      const compiler = SourceScriptCompiler();
      final definition = await compiler.compile(_sourceWithImplicitDiscover);

      final books = await definition.search(_buildRuntimeContext(), '凡人');

      expect(books, isEmpty);
    });
  });
}

SourceRuntimeContext _buildRuntimeContext({
  SourceUiContext ui = const SourceUiContext(),
  RequestEngine requestEngine = const _FakeRequestEngine(),
  String sourceId = 'test_source',
}) {
  final session = SourceSession(sourceId: sourceId);
  final manifest = const SourceManifest(
    name: '测试源',
    group: '测试',
    author: 'tester',
    description: '',
  );
  final sourceLogin = SourceLoginContext(sourceId: sourceId);
  return SourceRuntimeContext(
    source: SourceRuntimeInfo(
      id: sourceId,
      name: '测试源',
      group: '测试',
      revision: 'test',
    ),
    http: SourceHttpContext(
      requestEngine: requestEngine,
      session: session,
      manifest: manifest,
      browserRuntime: const UnsupportedBrowserRuntime(),
      sourceLogin: sourceLogin,
    ),
    sourceLogin: sourceLogin,
    bookState: SourceBookStateContext(),
    browser: SourceBrowserContext(
      browserRuntime: const UnsupportedBrowserRuntime(),
      session: session,
    ),
    cookie: SourceCookieContext(session: session),
    cache: SourceCacheContext(
      cacheStore: CacheStoreContext(cacheManager: InMemoryCacheManager()),
      sourceId: sourceId,
    ),
    html: const DefaultHtmlRuntime(),
    session: session,
    utils: SourceUtilsContext(),
    crypto: SourceCryptoContext(),
    ui: ui,
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

const String _sourceWithCryptoByteHelpers = '''
export default {
  meta: {
    name: '加密字节工具测试源',
    group: '测试',
    author: 'tester',
    description: '',
    capabilities: ['search', 'detail', 'chapters', 'content'],
  },
  async search(ctx, keyword) {
    const bytes = ctx.crypto.hexDecode('616263');
    const text = ctx.crypto.base64Decode('YWJj', { output: 'string' });
    const encoded = ctx.crypto.base64Encode(bytes);
    return [{ title: Array.from(bytes).join(',') + '|' + text + '|' + encoded, detailUrl: 'https://book' }];
  },
  async detail(ctx, book) { return book; },
  async chapters(ctx, book) { return []; },
  async content(ctx, book, chapter) { return { title: chapter.title || '', content: '' }; },
};
''';

const String _sourceWithLoginStateHelpers = '''
export default {
  meta: {
    name: '登录态桥接测试源',
    group: '测试',
    author: 'tester',
    description: '',
    capabilities: ['search', 'detail', 'chapters', 'content'],
  },
  async search(ctx, keyword) {
    await ctx.sourceLogin.putHeader('{"token":"abc"}');
    await ctx.sourceLogin.putInfo('{"账号":"foo"}');
    await ctx.sourceLogin.setVariable('{"tab":"小说"}');
    return [{
      title: await ctx.sourceLogin.getHeader() + '|' + await ctx.sourceLogin.getInfo() + '|' + await ctx.sourceLogin.getVariable(),
      author: '',
      detailUrl: 'https://book/1',
      sourceId: ctx.source.id,
      extra: { bookId: 'book_1' },
    }];
  },
  async detail(ctx, book) {
    const customBefore = await ctx.bookState.getCustom();
    await ctx.bookState.setCustom('{"mode":"vip"}');
    return {
      ...book,
      extra: {
        ...book.extra,
        customBefore,
        customAfter: await ctx.bookState.getCustom(book),
      },
    };
  },
  async chapters(ctx, book) {
    return [];
  },
  async content(ctx, book, chapter) {
    return {
      title: chapter.title,
      content: await ctx.bookState.getCustom(),
    };
  },
};
''';

const String _sourceWithUiHelpers = '''
export default {
  meta: {
    name: 'UI桥接测试源',
    group: '测试',
    author: 'tester',
    description: '',
    capabilities: ['search', 'detail', 'chapters', 'content'],
  },
  async search(ctx, keyword) {
    await ctx.ui.toast('hello');
    await ctx.ui.longToast('world');
    const browser = await ctx.ui.openBrowserAwait({
      url: 'https://example.com/login',
      title: '登录',
      refetchAfterSuccess: false,
    });
    const code = await ctx.ui.getVerificationCode('https://example.com/code.png');
    return [{ title: code, detailUrl: browser.finalUrl }];
  },
  async detail(ctx, book) { return book; },
  async chapters(ctx, book) { return []; },
  async content(ctx, book, chapter) { return { title: chapter.title || '', content: '' }; },
};
''';

const String _sourceWithConvenienceHelpers = '''
export default {
  meta: {
    name: '便捷辅助测试源',
    group: '测试',
    author: 'tester',
    description: '',
    capabilities: ['search', 'detail', 'chapters', 'content'],
  },
  async search(ctx, keyword) {
    await ctx.sourceLogin.putHeader('{"authorization":"Bearer 39470278_53e7dd36e624ed3cda64ff5fe095a3da"}');
    await ctx.sourceLogin.putInfo('{"账号":"foo"}');
    await ctx.sourceLogin.setVariable('{"tab":"小说","token":"variable-token"}');
    const variableMap = await ctx.sourceLogin.getVariableMap();
    const token = await ctx.sourceLogin.getToken();
    const account = await ctx.sourceLogin.getField('账号');
    const category = await ctx.sourceLogin.getFirstField(['missing', 'tab'], { sources: ['variable'] });
    const parsed = ctx.utils.safeJsonParse('{"ok":1}', { ok: 0 });
    const invalidParsed = ctx.utils.safeJsonParse('not-json', { ok: 2 });
    const first = ctx.utils.firstNonEmpty(['', '  ', 'done']);
    const picked = ctx.utils.pickField('{"a":"","b":"picked"}', ['a', 'b'], 'fallback');
    const normalized = ctx.utils.normalizeToken('Bearer token=39470278_53e7dd36e624ed3cda64ff5fe095a3da&foo=1');
    const plain = ctx.crypto.decryptPipeline('YWJj', [
      { method: 'base64Decode', output: 'string' },
    ]);
    return [{
      title: [
        token,
        account,
        category,
        variableMap.tab,
        String(parsed.ok),
        String(invalidParsed.ok),
        first,
        picked,
        normalized,
        plain,
      ].join('|'),
      detailUrl: 'https://book/helper',
    }];
  },
  async detail(ctx, book) { return book; },
  async chapters(ctx, book) { return []; },
  async content(ctx, book, chapter) { return { title: chapter.title || '', content: '' }; },
};
''';

const String _sourceWithExtendedHelpers = '''
export default {
  meta: {
    name: '扩展登录能力测试源',
    group: '测试',
    author: 'tester',
    description: '',
    capabilities: ['search', 'detail', 'chapters', 'content'],
  },
  async search(ctx, keyword) {
    await ctx.sourceLogin.patchInfo({ 账号: 'foo' });
    await ctx.sourceLogin.patchInfo('{"密钥":"bar"}');
    await ctx.sourceLogin.putVariable('tab', '小说');
    await ctx.bookState.patchCustom({ mode: 'vip' }, {
      title: '测试书',
      detailUrl: 'https://book/1',
      sourceId: ctx.source.id,
      extra: { bookId: 'book_1' },
    });
    await ctx.ui.openUrl('https://example.com/help', '帮助');
    await ctx.ui.alert({
      message: '当前仅支持最小宿主提示',
      title: '提示',
      confirmText: '知道了',
    });
    await ctx.ui.confirm({
      message: '确认清空？',
      title: '提示',
      confirmText: '确认',
      cancelText: '取消',
    });
    const prompt = await ctx.ui.prompt({
      message: '请输入验证码',
      title: '验证码',
      initialValue: '1234',
      confirmText: '确定',
      cancelText: '返回',
      obscureText: false,
    });
    return [{
      title: [
        await ctx.sourceLogin.getField('密钥'),
        await ctx.sourceLogin.getVariableValue('tab'),
        await ctx.bookState.getCustomValue('mode', {
          title: '测试书',
          detailUrl: 'https://book/1',
          sourceId: ctx.source.id,
          extra: { bookId: 'book_1' },
        }),
        prompt,
      ].join('|'),
      detailUrl: 'https://book/1',
      sourceId: ctx.source.id,
      extra: { bookId: 'book_1' },
    }];
  },
  async detail(ctx, book) { return book; },
  async chapters(ctx, book) { return []; },
  async content(ctx, book, chapter) { return { title: chapter.title || '', content: '' }; },
};
''';

const String _sourceWithLoginCheckHelpers = '''
export default {
  meta: {
    name: '登录检测测试源',
    group: '测试',
    author: 'tester',
    description: '',
    capabilities: ['search', 'detail', 'chapters', 'content'],
  },
  loginCheckJs: `<js>
    const payload = result.json() || JSON.parse(result.body() || '{}');
    if (payload.statusCode === 301) {
      await ctx.sourceLogin.putHeader(JSON.stringify({ Authorization: 'Bearer ok' }));
      java.getHeaderMap().put('Authorization', 'Bearer ok');
      result = await java.getResponse();
    }
    result;
  </js>`,
  async search(ctx, keyword) {
    const response = await ctx.http.request({
      url: 'https://example.com/search',
      responseType: 'text',
    });
    return [{
      title: String(response.text || '') + '|' + await ctx.sourceLogin.getHeader(),
      detailUrl: 'https://book/login-check',
    }];
  },
  async detail(ctx, book) { return book; },
  async chapters(ctx, book) { return []; },
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

class _FakeSequenceRequestEngine implements RequestEngine {
  _FakeSequenceRequestEngine(List<RuntimeHttpResponse> responses)
    : _responses = List<RuntimeHttpResponse>.from(responses);

  final List<RuntimeHttpResponse> _responses;
  final List<RuntimeHttpRequest> requests = <RuntimeHttpRequest>[];

  @override
  Future<RuntimeHttpResponse> request(
    RuntimeHttpRequest request, {
    SourceSession? session,
  }) async {
    requests.add(request);
    if (_responses.isEmpty) {
      throw StateError('No fake responses remaining.');
    }
    return _responses.removeAt(0);
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
  String? searchOutputOverride;
  String? inspectionOutputOverride;

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
      searchOutputOverride: searchOutputOverride,
      inspectionOutputOverride: inspectionOutputOverride,
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
    this.searchOutputOverride,
    this.inspectionOutputOverride,
  });

  final void Function() onDispose;
  final void Function(String source, String? sourceUrl) onInstallBootstrap;
  final void Function(String script) onRunSnippet;
  final String? searchOutputOverride;
  final String? inspectionOutputOverride;
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
            inspectionOutputOverride ??
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
      return JsExecutionResult(
        output: searchOutputOverride ?? '[]',
        isError: false,
      );
    }
    if (script.contains("__source?.['chapters']") ||
        script.contains("__sourceDefinition?.['chapters']")) {
      return const JsExecutionResult(output: '[]', isError: false);
    }
    if (script.contains("__source?.['detail']") ||
        script.contains("__sourceDefinition?.['detail']")) {
      return const JsExecutionResult(
        output:
            '{"title":"测试书","author":"","detailUrl":"https://book","tocUrl":"","extra":{},"debug":{}}',
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

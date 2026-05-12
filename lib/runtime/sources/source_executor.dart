import 'dart:async';

import '../browser/browser_runtime.dart';
import '../cache/cache_key_builder.dart';
import '../cache/cache_manager.dart';
import '../cache/cache_policy.dart';
import '../crypto/source_crypto.dart';
import '../html/html_runtime.dart';
import '../http/request_engine.dart';
import '../session/session_manager.dart';
import '../../features/source/application/source_login_state_service.dart';
import 'source_contract.dart';
import 'source_registry.dart';
import 'source_result_models.dart';

class SourceExecutor {
  SourceExecutor({
    required RequestEngine requestEngine,
    required SessionManager sessionManager,
    required CacheManager cacheManager,
    HtmlRuntime? htmlRuntime,
    BrowserRuntime? browserRuntime,
    SourceLoginStateService? sourceLoginStateService,
    void Function(String message)? logger,
  }) : _requestEngine = requestEngine,
       _sessionManager = sessionManager,
       _cacheManager = cacheManager,
       _htmlRuntime = htmlRuntime ?? const DefaultHtmlRuntime(),
       _browserRuntime = browserRuntime ?? const UnsupportedBrowserRuntime(),
       _sourceLoginStateService =
           sourceLoginStateService ?? SourceLoginStateService(),
       _logger = logger;

  final RequestEngine _requestEngine;
  final SessionManager _sessionManager;
  final CacheManager _cacheManager;
  final HtmlRuntime _htmlRuntime;
  final BrowserRuntime _browserRuntime;
  final SourceLoginStateService _sourceLoginStateService;
  final void Function(String message)? _logger;
  static final _SourceColdStartGate _coldStartGate = _SourceColdStartGate();

  static void debugResetColdStartGate() {
    _coldStartGate.reset();
  }

  Future<List<DiscoverCategory>> discoverCategories(
    RegisteredSource source,
  ) async {
    final handler = source.definition.discoverCategories;
    if (handler == null) {
      throw StateError(
        'Script runtime source does not support discoverCategories: ${source.runtime.id}',
      );
    }

    final cacheKey = CacheKeyBuilder.discoverCategories(
      sourceId: source.runtime.id,
    );
    final cached = _cacheManager.get<List<DiscoverCategory>>(cacheKey);
    if (cached != null) {
      return cached;
    }

    final categories = await _runWithColdStartGuard(
      source: source,
      step: SourceTaskStep.discoverCategories,
      taskBuilder:
          () => SourceTask(
            sourceId: source.runtime.id,
            step: SourceTaskStep.discoverCategories,
          ),
      action: (context) async => await handler(context),
    );
    _cacheManager.put<List<DiscoverCategory>>(
      key: cacheKey,
      sourceId: source.runtime.id,
      step: CacheStep.discoverCategories,
      value: categories,
      policy: CachePolicy.forStep(CacheStep.discoverCategories),
    );
    return categories;
  }

  Future<List<Book>> discoverBooks(
    RegisteredSource source, {
    required DiscoverCategory category,
    required int page,
    required int pageSize,
  }) async {
    final handler = source.definition.discoverBooks;
    if (handler == null) {
      throw StateError(
        'Script runtime source does not support discoverBooks: ${source.runtime.id}',
      );
    }

    final cacheKey = CacheKeyBuilder.discoverBooks(
      sourceId: source.runtime.id,
      categoryTitle: category.title,
      categoryUrl: category.url,
      page: page,
      pageSize: pageSize,
    );
    final cached = _cacheManager.get<List<Book>>(cacheKey);
    if (cached != null) {
      return cached;
    }

    final books = await _runWithColdStartGuard(
      source: source,
      step: SourceTaskStep.discoverBooks,
      taskBuilder:
          () => SourceTask(
            sourceId: source.runtime.id,
            step: SourceTaskStep.discoverBooks,
            category: category,
            page: page,
            pageSize: pageSize,
          ),
      action:
          (context) async => await handler(context, category, page, pageSize),
    );
    final normalized = books
        .map(
          (Book book) =>
              book.sourceId.isEmpty
                  ? book.copyWith(sourceId: source.runtime.id)
                  : book,
        )
        .toList(growable: false);

    _cacheManager.put<List<Book>>(
      key: cacheKey,
      sourceId: source.runtime.id,
      step: CacheStep.discoverBooks,
      value: normalized,
      policy: CachePolicy.forStep(CacheStep.discoverBooks),
    );
    return normalized;
  }

  Future<List<Book>> search(RegisteredSource source, String keyword) async {
    final cacheKey = CacheKeyBuilder.search(
      sourceId: source.runtime.id,
      keyword: keyword,
    );
    final cached = _cacheManager.get<List<Book>>(cacheKey);
    if (cached != null) {
      return cached;
    }

    final books = await _runWithColdStartGuard(
      source: source,
      step: SourceTaskStep.search,
      taskBuilder:
          () => SourceTask(
            sourceId: source.runtime.id,
            step: SourceTaskStep.search,
            keyword: keyword,
          ),
      action:
          (context) async => await source.definition.search(context, keyword),
    );
    final normalized = books
        .map(
          (Book book) =>
              book.sourceId.isEmpty
                  ? book.copyWith(sourceId: source.runtime.id)
                  : book,
        )
        .toList(growable: false);

    _cacheManager.put<List<Book>>(
      key: cacheKey,
      sourceId: source.runtime.id,
      step: CacheStep.search,
      value: normalized,
    );
    return normalized;
  }

  Future<Book> detail(RegisteredSource source, Book book) async {
    final cacheKey = CacheKeyBuilder.detail(
      sourceId: source.runtime.id,
      bookId: _runtimeBookCacheId(book),
    );
    final cached = _cacheManager.get<Book>(cacheKey);
    if (cached != null) {
      return cached;
    }

    final result = await _runWithColdStartGuard(
      source: source,
      step: SourceTaskStep.detail,
      taskBuilder:
          () => SourceTask(
            sourceId: source.runtime.id,
            step: SourceTaskStep.detail,
            book: book,
          ),
      action: (context) async => await source.definition.detail(context, book),
    );
    final normalized =
        result.sourceId.isEmpty
            ? result.copyWith(sourceId: source.runtime.id)
            : result;

    _cacheManager.put<Book>(
      key: cacheKey,
      sourceId: source.runtime.id,
      step: CacheStep.detail,
      value: normalized,
    );
    return normalized;
  }

  Future<List<Chapter>> chapters(RegisteredSource source, Book book) async {
    final cacheKey = CacheKeyBuilder.chapters(
      sourceId: source.runtime.id,
      bookId: _runtimeBookCacheId(book),
    );
    final cached = _cacheManager.get<List<Chapter>>(cacheKey);
    if (cached != null) {
      return cached;
    }

    final result = await _runWithColdStartGuard(
      source: source,
      step: SourceTaskStep.chapters,
      taskBuilder:
          () => SourceTask(
            sourceId: source.runtime.id,
            step: SourceTaskStep.chapters,
            book: book,
          ),
      action:
          (context) async => await source.definition.chapters(context, book),
    );
    final normalized = result
        .map(
          (Chapter chapter) =>
              chapter.sourceId.isEmpty
                  ? chapter.copyWith(sourceId: source.runtime.id)
                  : chapter,
        )
        .toList(growable: false);

    _cacheManager.put<List<Chapter>>(
      key: cacheKey,
      sourceId: source.runtime.id,
      step: CacheStep.chapters,
      value: normalized,
      policy: CachePolicy.forStep(CacheStep.chapters),
    );
    return normalized;
  }

  Future<Content> content(
    RegisteredSource source,
    Book book,
    Chapter chapter,
  ) async {
    final cacheKey = CacheKeyBuilder.content(
      sourceId: source.runtime.id,
      chapterId: _runtimeChapterCacheId(chapter),
    );
    final cached = _cacheManager.get<Content>(cacheKey);
    if (cached != null) {
      return cached;
    }

    final result = await _runWithColdStartGuard(
      source: source,
      step: SourceTaskStep.content,
      taskBuilder:
          () => SourceTask(
            sourceId: source.runtime.id,
            step: SourceTaskStep.content,
            book: book,
            chapter: chapter,
          ),
      action:
          (context) async =>
              await source.definition.content(context, book, chapter),
    );
    final normalized =
        result.sourceId.isEmpty
            ? result.copyWith(sourceId: source.runtime.id)
            : result;

    _cacheManager.put<Content>(
      key: cacheKey,
      sourceId: source.runtime.id,
      step: CacheStep.content,
      value: normalized,
      policy: CachePolicy.forStep(CacheStep.content),
    );
    return normalized;
  }

  Future<void> _runInitIfNeeded(
    RegisteredSource source,
    SourceRuntimeContext context,
    SourceTask task,
  ) async {
    if (source.definition.init == null) {
      return;
    }
    await source.definition.init!(context, task);
  }

  Future<T> _runWithColdStartGuard<T>({
    required RegisteredSource source,
    required SourceTaskStep step,
    required SourceTask Function() taskBuilder,
    required Future<T> Function(SourceRuntimeContext context) action,
  }) {
    final gateKey = '${source.runtime.id}:${step.name}';
    return _coldStartGate.run(
      key: gateKey,
      onColdStart: () {
        _logger?.call(
          '[${source.runtime.id}] cold-start gate enter ${step.name}',
        );
      },
      onWarmRun: () {
        _logger?.call('[${source.runtime.id}] warm step ${step.name}');
      },
      action: () async {
        final context = _createContext(source);
        await _runInitIfNeeded(source, context, taskBuilder());
        return action(context);
      },
    );
  }

  SourceRuntimeContext _createContext(
    RegisteredSource source, {
    SourceUiContext ui = const SourceUiContext(),
  }) {
    final runtime = source.runtime;
    final session = _sessionManager.sessionFor(runtime.id);
    final sourceLogin = SourceLoginContext(
      sourceId: runtime.id,
      stateService: _sourceLoginStateService,
    );
    return SourceRuntimeContext(
      source: runtime,
      http: SourceHttpContext(
        requestEngine: _requestEngine,
        session: session,
        manifest: source.definition.manifest,
        browserRuntime: _browserRuntime,
        sourceLogin: sourceLogin,
      ),
      sourceLogin: sourceLogin,
      bookState: SourceBookStateContext(stateService: _sourceLoginStateService),
      browser: SourceBrowserContext(
        browserRuntime: _browserRuntime,
        session: session,
      ),
      cookie: SourceCookieContext(session: session),
      cache: SourceCacheContext(
        cacheStore: CacheStoreContext(cacheManager: _cacheManager),
        sourceId: runtime.id,
      ),
      html: _htmlRuntime,
      session: session,
      utils: SourceUtilsContext(),
      crypto: SourceCryptoContext(),
      ui: ui,
      log: (String message) {
        appendDebugLog(session, message: message);
        _logger?.call('[${runtime.id}] $message');
      },
    );
  }

  SourceRuntimeContext createContext(
    RegisteredSource source, {
    SourceUiContext ui = const SourceUiContext(),
  }) {
    return _createContext(source, ui: ui);
  }

  String _runtimeBookCacheId(Book book) {
    final detailUrl = book.detailUrl.trim();
    if (detailUrl.isNotEmpty) {
      return Uri.encodeComponent(detailUrl);
    }
    final title = book.title.trim();
    if (title.isNotEmpty) {
      return Uri.encodeComponent(title);
    }
    return 'anonymous-book';
  }

  String _runtimeChapterCacheId(Chapter chapter) {
    final chapterUrl = chapter.url.trim();
    if (chapterUrl.isNotEmpty) {
      return Uri.encodeComponent(chapterUrl);
    }
    final title = chapter.title.trim();
    if (title.isNotEmpty) {
      return '${chapter.index}:${Uri.encodeComponent(title)}';
    }
    return 'chapter-${chapter.index}';
  }
}

class _SourceColdStartGate {
  final Set<String> _warmedKeys = <String>{};
  Future<void> _queue = Future<void>.value();

  Future<T> run<T>({
    required String key,
    required Future<T> Function() action,
    void Function()? onColdStart,
    void Function()? onWarmRun,
  }) {
    if (_warmedKeys.contains(key)) {
      onWarmRun?.call();
      return action();
    }

    final completer = Completer<T>();
    _queue = _queue.catchError((_) {}).then((_) async {
      try {
        onColdStart?.call();
        final result = await action();
        _warmedKeys.add(key);
        completer.complete(result);
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  void reset() {
    _warmedKeys.clear();
    _queue = Future<void>.value();
  }
}

import 'dart:async';

import '../../../runtime/browser/browser_runtime.dart';
import '../../../runtime/cache/cache_manager.dart';
import '../../../runtime/host/appread_browser_runtime.dart';
import '../../../runtime/http/request_engine.dart';
import '../../../runtime/session/session_manager.dart';
import '../../../runtime/session/source_session.dart';
import '../../../runtime/sources/persisted_source_loader.dart';
import '../../../runtime/sources/source_executor.dart';
import '../../../runtime/sources/source_file_store.dart';
import '../../../runtime/sources/source_registry.dart';
import '../../../runtime/sources/source_manifest.dart';
import '../../../runtime/sources/source_result_models.dart' as runtime_models;
import '../../../runtime/sources/source_script_compiler.dart';

class ScriptSourceRuntimeService {
  ScriptSourceRuntimeService({
    SourceRegistry? registry,
    SessionManager? sessionManager,
    CacheManager? cacheManager,
    BrowserRuntime? browserRuntime,
    RequestEngine? requestEngine,
    SourceScriptCompiler? scriptCompiler,
    SourceFileStore? sourceFileStore,
  }) : registry = registry ?? SourceRegistry(),
       sessionManager = sessionManager ?? InMemorySessionManager(),
       cacheManager = cacheManager ?? InMemoryCacheManager(),
       browserRuntime = browserRuntime ?? AppReadBrowserRuntime(),
       requestEngine = requestEngine ?? HttpPackageRequestEngine(),
       scriptCompiler = scriptCompiler ?? const SourceScriptCompiler(),
       sourceFileStore = sourceFileStore ?? SourceFileStore() {
    _persistedLoader = PersistedSourceLoader(
      sourceFileStore: this.sourceFileStore,
      sourceScriptCompiler: this.scriptCompiler,
    );
    _executor = SourceExecutor(
      requestEngine: this.requestEngine,
      sessionManager: this.sessionManager,
      cacheManager: this.cacheManager,
      browserRuntime: this.browserRuntime,
    );
  }

  final SourceRegistry registry;
  final SessionManager sessionManager;
  final CacheManager cacheManager;
  final BrowserRuntime browserRuntime;
  final RequestEngine requestEngine;
  final SourceScriptCompiler scriptCompiler;
  final SourceFileStore sourceFileStore;
  late final PersistedSourceLoader _persistedLoader;
  late final SourceExecutor _executor;
  static Future<void> _isolatedExecutionQueue = Future<void>.value();

  List<RegisteredSource> allSources({bool enabledOnly = true}) {
    return registry.all(enabledOnly: enabledOnly);
  }

  void clearRegisteredSources() {
    registry.clear();
  }

  void removeRegisteredSource(String sourceId) {
    final normalized = sourceId.trim();
    if (normalized.isEmpty) {
      return;
    }
    registry.remove(normalized);
    sessionManager.clearSource(normalized);
    cacheManager.invalidateSource(normalized);
  }

  RegisteredSource? sourceById(String sourceId) {
    final normalized = sourceId.trim();
    if (normalized.isEmpty) {
      return null;
    }
    return registry.getById(normalized);
  }

  Future<RegisteredSource> compileAndRegister({
    required String sourceCode,
    String? runtimeId,
    String revision = 'scratch',
  }) async {
    final definition = await scriptCompiler.compile(sourceCode);
    final normalizedRuntimeId = runtimeId?.trim() ?? '';
    if (normalizedRuntimeId.isEmpty) {
      return registry.register(definition, revision: revision);
    }
    return registry.upsert(normalizedRuntimeId, definition, revision: revision);
  }

  Future<StoredSourceFile> saveSource({
    required String suggestedName,
    required String contents,
  }) {
    return sourceFileStore.saveSource(
      suggestedName: suggestedName,
      contents: contents,
    );
  }

  Future<List<StoredSourceFile>> listStoredSources() {
    return sourceFileStore.listSourceFiles();
  }

  Future<PersistedSourceLoadReport> reloadPersistedSources({
    bool clearRegistry = false,
  }) async {
    if (clearRegistry) {
      registry.clear();
    }
    return _persistedLoader.loadInto(registry);
  }

  Future<List<runtime_models.Book>> search({
    required String sourceId,
    required String keyword,
    bool allowInteractiveChallenge = true,
    SessionCancellationHandle? cancellationHandle,
  }) async {
    final source = _requireSource(sourceId);
    final session = sessionManager.sessionFor(sourceId);
    const key = '__allow_interactive_challenge__';
    final previousCancellation = session.get<SessionCancellationHandle>(
      sessionCancellationHandleKey,
    );
    final previous = session.get<bool>(key);
    session.set(key, allowInteractiveChallenge);
    if (cancellationHandle != null) {
      session.set(sessionCancellationHandleKey, cancellationHandle);
    } else {
      session.clear(sessionCancellationHandleKey);
    }
    try {
      return _executor.search(source, keyword);
    } finally {
      if (previous == null) {
        session.clear(key);
      } else {
        session.set(key, previous);
      }
      if (previousCancellation == null) {
        session.clear(sessionCancellationHandleKey);
      } else {
        session.set(sessionCancellationHandleKey, previousCancellation);
      }
    }
  }

  Future<List<runtime_models.Book>> searchIsolated({
    required String sourceId,
    required String sourceCode,
    required String keyword,
    bool allowInteractiveChallenge = true,
    SessionCancellationHandle? cancellationHandle,
  }) async {
    final isolatedSession = SourceSession(sourceId: sourceId);
    const key = '__allow_interactive_challenge__';
    isolatedSession.set(key, allowInteractiveChallenge);
    if (cancellationHandle != null) {
      isolatedSession.set(sessionCancellationHandleKey, cancellationHandle);
    } else {
      isolatedSession.clear(sessionCancellationHandleKey);
    }
    final isolatedCache = InMemoryCacheManager();
    final isolatedSessionManager = _SingleSessionManager(isolatedSession);
    final isolatedExecutor = SourceExecutor(
      requestEngine: requestEngine,
      sessionManager: isolatedSessionManager,
      cacheManager: isolatedCache,
      browserRuntime: browserRuntime,
    );
    return _runIsolated(
      sourceId: sourceId,
      sourceCode: sourceCode,
      executor: isolatedExecutor,
      action: (source) => isolatedExecutor.search(source, keyword),
    );
  }

  Future<List<runtime_models.DiscoverCategory>> discoverCategories({
    required String sourceId,
  }) async {
    final source = _requireSource(sourceId);
    return _executor.discoverCategories(source);
  }

  Future<List<runtime_models.DiscoverCategory>> discoverCategoriesIsolated({
    required String sourceId,
    required String sourceCode,
  }) {
    return _runIsolated(
      sourceId: sourceId,
      sourceCode: sourceCode,
      executor: _executor,
      action: (source) => _executor.discoverCategories(source),
    );
  }

  Future<List<runtime_models.Book>> discoverBooks({
    required String sourceId,
    required runtime_models.DiscoverCategory category,
    required int page,
    required int pageSize,
  }) async {
    final source = _requireSource(sourceId);
    return _executor.discoverBooks(
      source,
      category: category,
      page: page,
      pageSize: pageSize,
    );
  }

  Future<List<runtime_models.Book>> discoverBooksIsolated({
    required String sourceId,
    required String sourceCode,
    required runtime_models.DiscoverCategory category,
    required int page,
    required int pageSize,
  }) {
    return _runIsolated(
      sourceId: sourceId,
      sourceCode: sourceCode,
      executor: _executor,
      action:
          (source) => _executor.discoverBooks(
            source,
            category: category,
            page: page,
            pageSize: pageSize,
          ),
    );
  }

  Future<runtime_models.Book> detail({
    required String sourceId,
    required runtime_models.Book book,
  }) async {
    final source = _requireSource(sourceId);
    return _executor.detail(source, book);
  }

  Future<runtime_models.Book> detailIsolated({
    required String sourceId,
    required String sourceCode,
    required runtime_models.Book book,
  }) {
    return _runIsolated(
      sourceId: sourceId,
      sourceCode: sourceCode,
      executor: _executor,
      action: (source) => _executor.detail(source, book),
    );
  }

  Future<List<runtime_models.Chapter>> chapters({
    required String sourceId,
    required runtime_models.Book book,
  }) async {
    final source = _requireSource(sourceId);
    return _executor.chapters(source, book);
  }

  Future<List<runtime_models.Chapter>> chaptersIsolated({
    required String sourceId,
    required String sourceCode,
    required runtime_models.Book book,
  }) {
    return _runIsolated(
      sourceId: sourceId,
      sourceCode: sourceCode,
      executor: _executor,
      action: (source) => _executor.chapters(source, book),
    );
  }

  Future<runtime_models.Content> content({
    required String sourceId,
    required runtime_models.Book book,
    required runtime_models.Chapter chapter,
  }) async {
    final source = _requireSource(sourceId);
    return _executor.content(source, book, chapter);
  }

  Future<runtime_models.Content> contentIsolated({
    required String sourceId,
    required String sourceCode,
    required runtime_models.Book book,
    required runtime_models.Chapter chapter,
  }) {
    return _runIsolated(
      sourceId: sourceId,
      sourceCode: sourceCode,
      executor: _executor,
      action: (source) => _executor.content(source, book, chapter),
    );
  }

  RegisteredSource _requireSource(String sourceId) {
    final normalized = sourceId.trim();
    final source = registry.getById(normalized);
    if (source == null) {
      throw StateError('Script runtime source not found: $sourceId');
    }
    return source;
  }

  Future<T> _runIsolated<T>({
    required String sourceId,
    required String sourceCode,
    required SourceExecutor executor,
    required Future<T> Function(RegisteredSource source) action,
  }) async {
    final completer = Completer<T>();
    _isolatedExecutionQueue = _isolatedExecutionQueue
        .catchError((_) {})
        .then((_) async {
          final definition = await scriptCompiler.compile(sourceCode);
          final isolatedSource = RegisteredSource(
            runtime: SourceRuntimeInfo(
              id: sourceId.trim(),
              name: definition.manifest.name,
              group: definition.manifest.group,
              revision: 'isolated:${DateTime.now().millisecondsSinceEpoch}',
            ),
            definition: definition,
          );
          try {
            completer.complete(await action(isolatedSource));
          } catch (error, stackTrace) {
            completer.completeError(error, stackTrace);
          } finally {
            definition.dispose?.call();
          }
        });
    return completer.future;
  }
}

class _SingleSessionManager implements SessionManager {
  const _SingleSessionManager(this._session);

  final SourceSession _session;

  @override
  Iterable<SourceSession> get activeSessions => <SourceSession>[_session];

  @override
  SourceSession sessionFor(String sourceId) => _session;

  @override
  void clearAll() {
    _session.clear();
    _session.clearCookies();
  }

  @override
  void clearSource(String sourceId) {
    if (_session.sourceId != sourceId.trim()) {
      return;
    }
    clearAll();
  }
}

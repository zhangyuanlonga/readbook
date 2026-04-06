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
import '../../../core/logging/app_logger.dart';
import 'source_runtime_diagnostic_execution_container.dart';
import 'source_runtime_reading_flow_container_service.dart';
import 'source_runtime_request_execution_container.dart';

class ScriptSourceRuntimeService {
  ScriptSourceRuntimeService({
    SourceRegistry? registry,
    SessionManager? sessionManager,
    CacheManager? cacheManager,
    BrowserRuntime? browserRuntime,
    RequestEngine? requestEngine,
    SourceScriptCompiler? scriptCompiler,
    SourceFileStore? sourceFileStore,
    SourceRuntimeReadingFlowContainerService? readingFlowContainerService,
    AppLogger? logger,
  }) : registry = registry ?? SourceRegistry(),
       sessionManager = sessionManager ?? InMemorySessionManager(),
       cacheManager = cacheManager ?? InMemoryCacheManager(),
       browserRuntime = browserRuntime ?? AppReadBrowserRuntime(),
       requestEngine = requestEngine ?? HttpPackageRequestEngine(),
       scriptCompiler = scriptCompiler ?? const SourceScriptCompiler(),
       sourceFileStore = sourceFileStore ?? SourceFileStore(),
       _logger = logger ?? AppLogger.instance,
       readingFlowContainerService =
           readingFlowContainerService ??
           SourceRuntimeReadingFlowContainerService() {
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
  final AppLogger _logger;
  final SourceRuntimeReadingFlowContainerService readingFlowContainerService;
  late final PersistedSourceLoader _persistedLoader;
  late final SourceExecutor _executor;
  static Future<void> _isolatedExecutionQueue = Future<void>.value();

  List<RegisteredSource> allSources({bool enabledOnly = true}) {
    return registry.all(enabledOnly: enabledOnly);
  }

  void clearRegisteredSources() {
    readingFlowContainerService.clearAll();
    registry.clear();
  }

  void removeRegisteredSource(String sourceId) {
    final normalized = sourceId.trim();
    if (normalized.isEmpty) {
      return;
    }
    registry.remove(normalized);
    readingFlowContainerService.clearSource(normalized);
    sessionManager.clearSource(normalized);
    cacheManager.invalidateSource(normalized);
  }

  void clearReadingFlow({
    required String sourceId,
    String detailUrl = '',
    String tocUrl = '',
    String title = '',
  }) {
    final normalizedSourceId = sourceId.trim();
    if (normalizedSourceId.isEmpty) {
      return;
    }
    readingFlowContainerService.clearFlow(
      sourceId: normalizedSourceId,
      book: runtime_models.Book(
        title: title.trim(),
        author: '',
        detailUrl: detailUrl.trim(),
        tocUrl: tocUrl.trim(),
        sourceId: normalizedSourceId,
      ),
    );
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

  Future<SourceRuntimeDiagnosticExecutionContainer>
  createDiagnosticExecutionContainer({
    required String sourceId,
    required String sourceCode,
    bool serializeStartup = true,
  }) async {
    final requestContainer = SourceRuntimeRequestExecutionContainer(
      sourceId: sourceId,
      requestEngine: requestEngine,
      browserRuntime: browserRuntime,
      onDispose: () {
        _logger.info(
          'Source runtime diagnostic container disposed',
          context: <String, Object?>{
            'sourceId': sourceId.trim(),
          },
        );
      },
    );
    try {
      final source = await _createIsolatedSource(
        sourceId: sourceId,
        sourceCode: sourceCode,
        serializeStartup: serializeStartup,
      );
      _logger.info(
        'Source runtime diagnostic container created',
        context: <String, Object?>{
          'sourceId': sourceId.trim(),
          'sourceName': source.runtime.name,
          'serializeStartup': serializeStartup,
        },
      );
      return DefaultSourceRuntimeDiagnosticExecutionContainer(
        source: source,
        requestContainer: requestContainer,
      );
    } catch (_) {
      requestContainer.dispose();
      rethrow;
    }
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
    bool serializeStartup = true,
  }) async {
    final container = SourceRuntimeRequestExecutionContainer(
      sourceId: sourceId,
      requestEngine: requestEngine,
      browserRuntime: browserRuntime,
      onDispose: () {
        _logger.info(
          'Source runtime request container disposed',
          context: <String, Object?>{
            'sourceId': sourceId.trim(),
            'purpose': 'search',
          },
        );
      },
    );
    _logger.info(
      'Source runtime request container created',
      context: <String, Object?>{
        'sourceId': sourceId.trim(),
        'purpose': 'search',
        'serializeStartup': serializeStartup,
      },
    );
    const key = '__allow_interactive_challenge__';
    container.session.set(key, allowInteractiveChallenge);
    if (cancellationHandle != null) {
      container.session.set(sessionCancellationHandleKey, cancellationHandle);
    } else {
      container.session.clear(sessionCancellationHandleKey);
    }
    return _runRequestIsolated(
      sourceId: sourceId,
      sourceCode: sourceCode,
      container: container,
      serializeStartup: serializeStartup,
      action: (source) => container.executor.search(source, keyword),
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
    bool serializeStartup = true,
  }) {
    final container = SourceRuntimeRequestExecutionContainer(
      sourceId: sourceId,
      requestEngine: requestEngine,
      browserRuntime: browserRuntime,
      onDispose: () {
        _logger.info(
          'Source runtime request container disposed',
          context: <String, Object?>{
            'sourceId': sourceId.trim(),
            'purpose': 'discoverCategories',
          },
        );
      },
    );
    _logger.info(
      'Source runtime request container created',
      context: <String, Object?>{
        'sourceId': sourceId.trim(),
        'purpose': 'discoverCategories',
        'serializeStartup': serializeStartup,
      },
    );
    return _runRequestIsolated(
      sourceId: sourceId,
      sourceCode: sourceCode,
      container: container,
      serializeStartup: serializeStartup,
      action: (source) => container.executor.discoverCategories(source),
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
    bool serializeStartup = true,
  }) {
    final container = SourceRuntimeRequestExecutionContainer(
      sourceId: sourceId,
      requestEngine: requestEngine,
      browserRuntime: browserRuntime,
      onDispose: () {
        _logger.info(
          'Source runtime request container disposed',
          context: <String, Object?>{
            'sourceId': sourceId.trim(),
            'purpose': 'discoverBooks',
          },
        );
      },
    );
    _logger.info(
      'Source runtime request container created',
      context: <String, Object?>{
        'sourceId': sourceId.trim(),
        'purpose': 'discoverBooks',
        'serializeStartup': serializeStartup,
      },
    );
    return _runRequestIsolated(
      sourceId: sourceId,
      sourceCode: sourceCode,
      container: container,
      serializeStartup: serializeStartup,
      action:
          (source) => container.executor.discoverBooks(
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
    bool serializeStartup = true,
  }) {
    return _runReadingFlowIsolated(
      sourceId: sourceId,
      sourceCode: sourceCode,
      book: book,
      serializeStartup: serializeStartup,
      action: (container) async {
        final result = await container.executor.detail(container.source, book);
        readingFlowContainerService.rebindFlow(
          sourceId: sourceId.trim(),
          fromBook: book,
          toBook: result,
        );
        return result;
      },
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
    bool serializeStartup = true,
  }) {
    return _runReadingFlowIsolated(
      sourceId: sourceId,
      sourceCode: sourceCode,
      book: book,
      serializeStartup: serializeStartup,
      action:
          (container) => container.executor.chapters(container.source, book),
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
    bool serializeStartup = true,
  }) {
    return _runReadingFlowIsolated(
      sourceId: sourceId,
      sourceCode: sourceCode,
      book: book,
      serializeStartup: serializeStartup,
      action:
          (container) =>
              container.executor.content(container.source, book, chapter),
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
    bool serializeStartup = true,
  }) async {
    if (!serializeStartup) {
      final source = await _createIsolatedSource(
        sourceId: sourceId,
        sourceCode: sourceCode,
        serializeStartup: false,
      );
      try {
        return await action(source);
      } finally {
        source.definition.dispose?.call();
      }
    }
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
 
  Future<T> _runRequestIsolated<T>({
    required String sourceId,
    required String sourceCode,
    required SourceRuntimeRequestExecutionContainer container,
    required Future<T> Function(RegisteredSource source) action,
    bool serializeStartup = true,
  }) async {
    try {
      return await _runIsolated(
        sourceId: sourceId,
        sourceCode: sourceCode,
        executor: container.executor,
        action: action,
        serializeStartup: serializeStartup,
      );
    } finally {
      container.dispose();
    }
  }

  Future<T> _runReadingFlowIsolated<T>({
    required String sourceId,
    required String sourceCode,
    required runtime_models.Book book,
    required bool serializeStartup,
    required Future<T> Function(
      SourceRuntimeReadingFlowExecutionContainer container,
    )
    action,
  }) async {
    final normalizedSourceId = sourceId.trim();
    final existing = readingFlowContainerService.get(
      sourceId: normalizedSourceId,
      book: book,
    );
    final container =
        existing ??
        await _createReadingFlowContainer(
          sourceId: normalizedSourceId,
          sourceCode: sourceCode,
          book: book,
          serializeStartup: serializeStartup,
        );
    return action(container);
  }

  Future<SourceRuntimeReadingFlowExecutionContainer>
  _createReadingFlowContainer({
    required String sourceId,
    required String sourceCode,
    required runtime_models.Book book,
    required bool serializeStartup,
  }) async {
    final requestContainer = SourceRuntimeRequestExecutionContainer(
      sourceId: sourceId,
      requestEngine: requestEngine,
      browserRuntime: browserRuntime,
      onDispose: () {
        _logger.info(
          'Source runtime request container disposed',
          context: <String, Object?>{
            'sourceId': sourceId.trim(),
            'purpose': 'readingFlow',
          },
        );
      },
    );
    final source = await _createIsolatedSource(
      sourceId: sourceId,
      sourceCode: sourceCode,
      serializeStartup: serializeStartup,
    );
    _logger.info(
      'Source runtime request container created',
      context: <String, Object?>{
        'sourceId': sourceId.trim(),
        'purpose': 'readingFlow',
        'serializeStartup': serializeStartup,
      },
    );
    final container = SourceRuntimeReadingFlowExecutionContainer(
      sourceId: sourceId,
      flowKey: readingFlowContainerService.flowKeyOf(
        sourceId: sourceId,
        book: book,
      ),
      source: source,
      requestContainer: requestContainer,
    );
    return readingFlowContainerService.put(container);
  }

  Future<RegisteredSource> _createIsolatedSource({
    required String sourceId,
    required String sourceCode,
    bool serializeStartup = true,
  }) async {
    if (!serializeStartup) {
      final definition = await scriptCompiler.compile(sourceCode);
      return RegisteredSource(
        runtime: SourceRuntimeInfo(
          id: sourceId.trim(),
          name: definition.manifest.name,
          group: definition.manifest.group,
          revision: 'isolated:${DateTime.now().millisecondsSinceEpoch}',
        ),
        definition: definition,
      );
    }
    final completer = Completer<RegisteredSource>();
    _isolatedExecutionQueue = _isolatedExecutionQueue
        .catchError((_) {})
        .then((_) async {
          try {
            final definition = await scriptCompiler.compile(sourceCode);
            completer.complete(
              RegisteredSource(
                runtime: SourceRuntimeInfo(
                  id: sourceId.trim(),
                  name: definition.manifest.name,
                  group: definition.manifest.group,
                  revision: 'isolated:${DateTime.now().millisecondsSinceEpoch}',
                ),
                definition: definition,
              ),
            );
          } catch (error, stackTrace) {
            completer.completeError(error, stackTrace);
          }
        });
    return completer.future;
  }
}

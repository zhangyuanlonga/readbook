import '../../../runtime/browser/browser_runtime.dart';
import '../../../runtime/cache/cache_manager.dart';
import '../../../runtime/host/appread_browser_runtime.dart';
import '../../../runtime/http/request_engine.dart';
import '../../../runtime/session/session_manager.dart';
import '../../../runtime/sources/persisted_source_loader.dart';
import '../../../runtime/sources/source_executor.dart';
import '../../../runtime/sources/source_file_store.dart';
import '../../../runtime/sources/source_registry.dart';
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
  }) async {
    final source = _requireSource(sourceId);
    return _executor.search(source, keyword);
  }

  Future<List<runtime_models.DiscoverCategory>> discoverCategories({
    required String sourceId,
  }) async {
    final source = _requireSource(sourceId);
    return _executor.discoverCategories(source);
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

  Future<runtime_models.Book> detail({
    required String sourceId,
    required runtime_models.Book book,
  }) async {
    final source = _requireSource(sourceId);
    return _executor.detail(source, book);
  }

  Future<List<runtime_models.Chapter>> chapters({
    required String sourceId,
    required runtime_models.Book book,
  }) async {
    final source = _requireSource(sourceId);
    return _executor.chapters(source, book);
  }

  Future<runtime_models.Content> content({
    required String sourceId,
    required runtime_models.Book book,
    required runtime_models.Chapter chapter,
  }) async {
    final source = _requireSource(sourceId);
    return _executor.content(source, book, chapter);
  }

  RegisteredSource _requireSource(String sourceId) {
    final normalized = sourceId.trim();
    final source = registry.getById(normalized);
    if (source == null) {
      throw StateError('Script runtime source not found: $sourceId');
    }
    return source;
  }
}

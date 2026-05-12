import '../../../runtime/browser/browser_runtime.dart';
import '../../../runtime/cache/cache_manager.dart';
import '../../../runtime/http/request_engine.dart';
import '../../../runtime/session/session_manager.dart';
import '../../../runtime/session/source_session.dart';
import '../../../runtime/sources/source_executor.dart';

class SourceRuntimeRequestExecutionContainer {
  SourceRuntimeRequestExecutionContainer({
    required this.sourceId,
    required RequestEngine requestEngine,
    required BrowserRuntime browserRuntime,
    void Function()? onDispose,
  }) : _session = SourceSession(sourceId: sourceId),
       _cacheManager = InMemoryCacheManager(),
       _onDispose = onDispose {
    _sessionManager = _SingleSessionManager(_session);
    _executor = SourceExecutor(
      requestEngine: requestEngine,
      sessionManager: _sessionManager,
      cacheManager: _cacheManager,
      browserRuntime: browserRuntime,
    );
  }

  final String sourceId;
  final SourceSession _session;
  late final SessionManager _sessionManager;
  final InMemoryCacheManager _cacheManager;
  late final SourceExecutor _executor;
  final void Function()? _onDispose;

  SourceSession get session => _session;
  SessionManager get sessionManager => _sessionManager;
  InMemoryCacheManager get cacheManager => _cacheManager;
  SourceExecutor get executor => _executor;

  void dispose() {
    _session.clear();
    _session.clearCookies();
    _cacheManager.clear();
    _onDispose?.call();
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
    if (_session.sourceId != sourceId) {
      return;
    }
    clearAll();
  }
}

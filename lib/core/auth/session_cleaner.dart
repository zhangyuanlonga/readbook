import 'auth_event_bus.dart';
import 'auth_session.dart';
import 'auth_session_store.dart';

class SessionCleaner {
  SessionCleaner({AuthSessionStore? sessionStore})
    : _sessionStore = sessionStore ?? AuthSessionStore();

  final AuthSessionStore _sessionStore;

  Future<void> clear({
    AuthSession? previousSession,
    bool emitEvent = true,
  }) async {
    final resolvedPreviousSession =
        previousSession ?? await _sessionStore.getSession();
    await _sessionStore.clear();
    if (emitEvent) {
      AuthEventBus.instance.emitLoggedOut('已退出登录。', resolvedPreviousSession);
    }
  }
}

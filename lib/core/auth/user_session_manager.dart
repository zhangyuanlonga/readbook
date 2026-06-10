import 'dart:async';

import 'auth_event_bus.dart';
import 'auth_session.dart';
import 'auth_session_store.dart';
import 'session_change_listener.dart';
import 'session_cleaner.dart';
import 'user_session_state.dart';

class UserSessionManager {
  UserSessionManager({
    AuthSessionStore? sessionStore,
    SessionCleaner? sessionCleaner,
  }) : _sessionStore = sessionStore ?? AuthSessionStore(),
       _sessionCleaner = sessionCleaner;

  static final UserSessionManager instance = UserSessionManager();

  final AuthSessionStore _sessionStore;
  final SessionCleaner? _sessionCleaner;
  final Set<SessionChangeListener> _listeners = <SessionChangeListener>{};

  UserSessionState _state = const UserSessionState.empty();

  UserSessionState get state => _state;

  String? get accessToken => _state.accessToken;

  Future<UserSessionState> load() async {
    _state = UserSessionState.fromSession(await _sessionStore.getSession());
    return _state;
  }

  Future<AuthSession?> getSession() {
    return _sessionStore.getSession();
  }

  Future<void> login(AuthSession session) async {
    final previousSession = await _sessionStore.getSession();
    await _sessionStore.saveSession(session);
    _state = UserSessionState.fromSession(session);
    AuthEventBus.instance.emitLoggedIn('登录成功。', session, previousSession);
    await _notifyLogin(session.userId);
  }

  Future<void> logout({
    AuthSession? previousSession,
    bool emitEvent = true,
  }) async {
    final resolvedPreviousSession =
        previousSession ?? await _sessionStore.getSession();
    final cleaner =
        _sessionCleaner ?? SessionCleaner(sessionStore: _sessionStore);
    await cleaner.clear(
      previousSession: resolvedPreviousSession,
      emitEvent: emitEvent,
    );
    _state = const UserSessionState.empty();
    await _notifyLogout(resolvedPreviousSession?.userId);
  }

  void addListener(SessionChangeListener listener) {
    _listeners.add(listener);
  }

  void removeListener(SessionChangeListener listener) {
    _listeners.remove(listener);
  }

  Future<void> _notifyLogin(String? userId) async {
    final normalized = userId?.trim() ?? '';
    if (normalized.isEmpty) {
      return;
    }
    await Future.wait<void>(
      _listeners.map((listener) => listener.onUserLogin(normalized)),
    );
  }

  Future<void> _notifyLogout(String? userId) async {
    await Future.wait<void>(
      _listeners.map((listener) => listener.onUserLogout(userId)),
    );
  }
}

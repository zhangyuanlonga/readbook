import 'auth_event_bus.dart';
import 'session_change_listener.dart';

class AuthEventSessionChangeDispatcher {
  AuthEventSessionChangeDispatcher({
    Iterable<SessionChangeListener> listeners = const <SessionChangeListener>[],
  }) : _listeners = List<SessionChangeListener>.of(listeners);

  final List<SessionChangeListener> _listeners;

  void addListener(SessionChangeListener listener) {
    _listeners.add(listener);
  }

  void removeListener(SessionChangeListener listener) {
    _listeners.remove(listener);
  }

  Future<void> handle(AuthEvent event) async {
    switch (event.type) {
      case AuthEventType.loggedIn:
        final userId = event.userId?.trim() ?? '';
        if (userId.isEmpty) {
          return;
        }
        await Future.wait<void>(
          _listeners.map((listener) => listener.onUserLogin(userId)),
        );
        break;
      case AuthEventType.loggedOut:
      case AuthEventType.sessionExpired:
        final userId = event.previousUserId ?? event.userId;
        await Future.wait<void>(
          _listeners.map((listener) => listener.onUserLogout(userId)),
        );
        break;
    }
  }
}

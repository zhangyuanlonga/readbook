import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/core/auth/auth_event_bus.dart';
import 'package:shuxiang_reading_next/core/auth/auth_event_session_change_dispatcher.dart';
import 'package:shuxiang_reading_next/core/auth/auth_session.dart';
import 'package:shuxiang_reading_next/core/auth/session_change_listener.dart';

void main() {
  test(
    'dispatches login and logout auth events to session listeners',
    () async {
      final listener = _RecordingSessionChangeListener();
      final dispatcher = AuthEventSessionChangeDispatcher(
        listeners: <SessionChangeListener>[listener],
      );

      await dispatcher.handle(
        const AuthEvent(
          type: AuthEventType.loggedIn,
          message: 'login',
          session: AuthSession(accessToken: 'token', userId: 'user-a'),
        ),
      );
      await dispatcher.handle(
        const AuthEvent(
          type: AuthEventType.loggedOut,
          message: 'logout',
          previousSession: AuthSession(accessToken: 'token', userId: 'user-a'),
        ),
      );

      expect(listener.logins, <String>['user-a']);
      expect(listener.logouts, <String?>['user-a']);
    },
  );

  test('treats sessionExpired as logout for cleanup listeners', () async {
    final listener = _RecordingSessionChangeListener();
    final dispatcher = AuthEventSessionChangeDispatcher(
      listeners: <SessionChangeListener>[listener],
    );

    await dispatcher.handle(
      const AuthEvent(
        type: AuthEventType.sessionExpired,
        message: 'expired',
        previousSession: AuthSession(accessToken: 'token', userId: 'user-a'),
      ),
    );

    expect(listener.logouts, <String?>['user-a']);
  });
}

class _RecordingSessionChangeListener implements SessionChangeListener {
  final List<String> logins = <String>[];
  final List<String?> logouts = <String?>[];

  @override
  Future<void> onUserLogin(String userId) async {
    logins.add(userId);
  }

  @override
  Future<void> onUserLogout(String? userId) async {
    logouts.add(userId);
  }
}

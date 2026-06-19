import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuxiang_reading_next/core/auth/auth_session.dart';
import 'package:shuxiang_reading_next/core/auth/auth_session_store.dart';
import 'package:shuxiang_reading_next/core/auth/session_change_listener.dart';
import 'package:shuxiang_reading_next/core/auth/session_cleaner.dart';
import 'package:shuxiang_reading_next/core/auth/session_cleanup_participant.dart';
import 'package:shuxiang_reading_next/core/auth/user_session_manager.dart';

import '../../test_utils/fake_auth_session_secret_store.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('login stores session, updates state, and notifies listener', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = AuthSessionStore(
      preferences: prefs,
      secretStore: FakeAuthSessionSecretStore(),
    );
    final manager = UserSessionManager(sessionStore: store);
    final listener = _RecordingSessionChangeListener();
    manager.addListener(listener);

    await manager.login(
      AuthSession(
        accessToken: 'access-a',
        refreshToken: 'refresh-a',
        userId: 'user-a',
        username: 'reader',
        accessExpiresAt: DateTime.utc(2026, 6, 10, 8),
      ),
    );

    final stored = await store.getSession();
    expect(stored?.accessToken, 'access-a');
    expect(stored?.userId, 'user-a');
    expect(manager.state.isLoggedIn, isTrue);
    expect(manager.state.userId, 'user-a');
    expect(listener.logins, <String>['user-a']);
  });

  test('logout clears session, resets state, and notifies listener', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = AuthSessionStore(
      preferences: prefs,
      secretStore: FakeAuthSessionSecretStore(),
    );
    final manager = UserSessionManager(sessionStore: store);
    final listener = _RecordingSessionChangeListener();
    manager.addListener(listener);

    await manager.login(
      const AuthSession(accessToken: 'access-a', userId: 'user-a'),
    );
    await manager.logout();

    expect(await store.getSession(), isNull);
    expect(manager.state.isLoggedIn, isFalse);
    expect(listener.logouts, <String>['user-a']);
  });

  test('logout runs injected session cleanup participants', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = AuthSessionStore(
      preferences: prefs,
      secretStore: FakeAuthSessionSecretStore(),
    );
    final cleanup = _RecordingSessionCleanupParticipant();
    final manager = UserSessionManager(
      sessionStore: store,
      sessionCleaner: SessionCleaner(
        sessionStore: store,
        cleanupParticipants: <SessionCleanupParticipant>[cleanup],
      ),
    );

    await manager.login(
      const AuthSession(accessToken: 'access-a', userId: 'user-a'),
    );
    await manager.logout();

    expect(cleanup.userIds, <String>['user-a']);
    expect(await store.getSession(), isNull);
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

class _RecordingSessionCleanupParticipant implements SessionCleanupParticipant {
  final List<String> userIds = <String>[];

  @override
  Future<void> clearForUser(String userId) async {
    userIds.add(userId);
  }
}

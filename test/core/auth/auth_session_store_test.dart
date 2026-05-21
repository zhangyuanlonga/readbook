import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuxiang_reading_next/core/auth/auth_session.dart';
import 'package:shuxiang_reading_next/core/auth/auth_session_secret_store.dart';
import 'package:shuxiang_reading_next/core/auth/auth_session_store.dart';

import '../../test_utils/fake_auth_session_secret_store.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test(
    'migrates legacy prefs credentials into secure storage on read',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'auth.access_token': 'legacy_access',
        'auth.refresh_token': 'legacy_refresh',
        'auth.access_expires_at': '2026-05-21T08:00:00Z',
        'auth.refresh_expires_at': '2026-05-22T08:00:00Z',
        'auth.user_id': 'user_1',
        'auth.username': 'tester',
        'auth.display_name': '测试用户',
      });
      final prefs = await SharedPreferences.getInstance();
      final secretStore = FakeAuthSessionSecretStore();
      final store = AuthSessionStore(
        preferences: prefs,
        secretStore: secretStore,
      );

      final session = await store.getSession();
      final secrets = await secretStore.readSecrets();

      expect(session, isNotNull);
      expect(session?.accessToken, 'legacy_access');
      expect(session?.refreshToken, 'legacy_refresh');
      expect(session?.userId, 'user_1');
      expect(session?.displayName, '测试用户');
      expect(secrets.accessToken, 'legacy_access');
      expect(secrets.refreshToken, 'legacy_refresh');
      expect(secrets.accessExpiresAt, DateTime.parse('2026-05-21T08:00:00Z'));
      expect(secrets.refreshExpiresAt, DateTime.parse('2026-05-22T08:00:00Z'));
      expect(prefs.getString('auth.access_token'), isNull);
      expect(prefs.getString('auth.refresh_token'), isNull);
      expect(prefs.getString('auth.access_expires_at'), isNull);
      expect(prefs.getString('auth.refresh_expires_at'), isNull);
      expect(prefs.getString('auth.user_id'), 'user_1');
      expect(prefs.getString('auth.username'), 'tester');
      expect(prefs.getString('auth.display_name'), '测试用户');
    },
  );

  test(
    'saveSession writes secrets to secure storage and keeps display cache',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final secretStore = FakeAuthSessionSecretStore();
      final store = AuthSessionStore(
        preferences: prefs,
        secretStore: secretStore,
      );

      await store.saveSession(
        const AuthSession(
          accessToken: 'secure_access',
          refreshToken: 'secure_refresh',
          accessExpiresAt: null,
          refreshExpiresAt: null,
          userId: 'user_2',
          username: 'reader',
          account: 'reader@example.com',
          displayName: 'Reader',
        ),
      );

      final secrets = await secretStore.readSecrets();
      expect(secrets.accessToken, 'secure_access');
      expect(secrets.refreshToken, 'secure_refresh');
      expect(prefs.getString('auth.access_token'), isNull);
      expect(prefs.getString('auth.refresh_token'), isNull);
      expect(prefs.getString('auth.user_id'), 'user_2');
      expect(prefs.getString('auth.username'), 'reader@example.com');
      expect(prefs.getString('auth.account'), 'reader@example.com');
      expect(prefs.getString('auth.display_name'), 'Reader');
    },
  );

  test('clear removes secure secrets and display cache', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'auth.user_id': 'user_3',
      'auth.username': 'legacy_user',
      'auth.account': 'legacy_user',
      'auth.display_name': 'Legacy User',
      'auth.access_token': 'legacy_access',
      'auth.refresh_token': 'legacy_refresh',
    });
    final prefs = await SharedPreferences.getInstance();
    final secretStore = FakeAuthSessionSecretStore(
      initialSecrets: const AuthSessionSecrets(
        accessToken: 'secure_access',
        refreshToken: 'secure_refresh',
      ),
    );
    final store = AuthSessionStore(
      preferences: prefs,
      secretStore: secretStore,
    );

    await store.clear();

    final secrets = await secretStore.readSecrets();
    expect(secrets.hasAnyValue, isFalse);
    expect(prefs.getString('auth.user_id'), isNull);
    expect(prefs.getString('auth.username'), isNull);
    expect(prefs.getString('auth.account'), isNull);
    expect(prefs.getString('auth.display_name'), isNull);
    expect(prefs.getString('auth.access_token'), isNull);
    expect(prefs.getString('auth.refresh_token'), isNull);
  });
}

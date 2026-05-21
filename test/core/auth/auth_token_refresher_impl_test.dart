import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuxiang_reading_next/core/auth/auth_service.dart';
import 'package:shuxiang_reading_next/core/auth/auth_session.dart';
import 'package:shuxiang_reading_next/core/auth/auth_session_store.dart';
import 'package:shuxiang_reading_next/core/auth/auth_token_refresher_impl.dart';

import '../../test_utils/fake_auth_session_secret_store.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test(
    'refresh token chain reads secure session and persists refreshed tokens',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'auth.user_id': 'user_1',
        'auth.username': 'reader',
        'auth.display_name': 'Reader',
      });
      final prefs = await SharedPreferences.getInstance();
      final secretStore = FakeAuthSessionSecretStore();
      final sessionStore = AuthSessionStore(
        preferences: prefs,
        secretStore: secretStore,
      );
      await sessionStore.saveSession(
        const AuthSession(
          accessToken: 'access_old',
          refreshToken: 'refresh_old',
          userId: 'user_1',
          username: 'reader',
          displayName: 'Reader',
        ),
      );

      final refresher = AuthTokenRefresherImpl(
        authService: _FakeRefreshingAuthService(sessionStore),
        sessionStore: sessionStore,
      );

      final refreshed = await refresher.refreshToken();
      final session = await sessionStore.getSession();

      expect(refreshed, isTrue);
      expect(session, isNotNull);
      expect(session?.accessToken, 'access_new');
      expect(session?.refreshToken, 'refresh_new');
      expect(session?.userId, 'user_1');
      expect(session?.displayName, 'Reader');
    },
  );
}

class _FakeRefreshingAuthService extends AuthService {
  _FakeRefreshingAuthService(this._sessionStore)
    : super(baseUrl: 'https://example.com');

  final AuthSessionStore _sessionStore;

  @override
  Future<AuthSession> refreshAndStore({String? refreshToken}) async {
    const session = AuthSession(
      accessToken: 'access_new',
      refreshToken: 'refresh_new',
      userId: 'user_1',
      username: 'reader',
      displayName: 'Reader',
    );
    await _sessionStore.saveSession(session);
    return session;
  }
}

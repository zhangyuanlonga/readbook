import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuxiang_reading_next/core/auth/auth_install_recovery_service.dart';
import 'package:shuxiang_reading_next/core/auth/auth_session.dart';
import 'package:shuxiang_reading_next/core/auth/auth_session_store.dart';

import '../../test_utils/fake_auth_session_secret_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test('clears lingering auth state when install id is missing', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = AuthSessionStore(
      preferences: prefs,
      secretStore: FakeAuthSessionSecretStore(),
    );
    await store.saveSession(
      const AuthSession(
        accessToken: 'access_token',
        refreshToken: 'refresh_token',
        userId: 'user_1',
        username: 'reader',
      ),
    );
    await prefs.remove('app.install_id');

    final cleared =
        await AuthInstallRecoveryService(
          preferences: prefs,
          sessionStore: store,
        ).clearAuthStateIfFreshInstall();

    expect(cleared, isTrue);
    expect(await store.getSession(), isNull);
  });

  test('keeps auth state when install id already exists', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app.install_id': 'install_1',
    });
    final prefs = await SharedPreferences.getInstance();
    final store = AuthSessionStore(
      preferences: prefs,
      secretStore: FakeAuthSessionSecretStore(),
    );
    await store.saveSession(
      const AuthSession(
        accessToken: 'access_token',
        refreshToken: 'refresh_token',
        userId: 'user_1',
      ),
    );

    final cleared =
        await AuthInstallRecoveryService(
          preferences: prefs,
          sessionStore: store,
        ).clearAuthStateIfFreshInstall();

    expect(cleared, isFalse);
    expect(await store.getSession(), isNotNull);
  });
}

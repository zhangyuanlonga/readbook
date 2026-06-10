import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuxiang_reading_next/core/auth/auth_service.dart';
import 'package:shuxiang_reading_next/core/auth/auth_session.dart';
import 'package:shuxiang_reading_next/core/auth/auth_session_store.dart';
import 'package:shuxiang_reading_next/core/auth/startup_auth_session_validator.dart';
import 'package:shuxiang_reading_next/core/network/api_client.dart';
import 'package:shuxiang_reading_next/core/errors/error_codes.dart';
import 'package:shuxiang_reading_next/core/errors/error_stage.dart';

import '../../test_utils/fake_auth_session_secret_store.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('clears session when refresh token is already expired', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = AuthSessionStore(
      preferences: prefs,
      secretStore: FakeAuthSessionSecretStore(),
    );
    await store.saveSession(
      AuthSession(
        accessToken: 'access_token',
        refreshToken: 'refresh_token',
        accessExpiresAt: DateTime.now().toUtc().subtract(
          const Duration(hours: 2),
        ),
        refreshExpiresAt: DateTime.now().toUtc().subtract(
          const Duration(hours: 1),
        ),
        userId: 'user_1',
      ),
    );

    final valid =
        await StartupAuthSessionValidator(
          sessionStore: store,
          authService: _FakeStartupAuthService(),
        ).validate();

    expect(valid, isFalse);
    expect(await store.getSession(), isNull);
  });

  test('keeps session when refresh fails transiently', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = AuthSessionStore(
      preferences: prefs,
      secretStore: FakeAuthSessionSecretStore(),
    );
    await store.saveSession(
      AuthSession(
        accessToken: 'access_token',
        refreshToken: 'refresh_token',
        accessExpiresAt: DateTime.now().toUtc().subtract(
          const Duration(hours: 2),
        ),
        refreshExpiresAt: DateTime.now().toUtc().add(const Duration(days: 1)),
        userId: 'user_1',
      ),
    );

    final valid =
        await StartupAuthSessionValidator(
          sessionStore: store,
          authService: _FakeStartupAuthService(
            refreshError: const ApiException(
              code: ErrorCode.network,
              briefMessage: 'network down',
              apiCode: 'UPSTREAM_TIMEOUT',
              stage: ErrorStage.unknown,
              statusCode: 503,
            ),
          ),
        ).validate();

    expect(valid, isFalse);
    expect(await store.getSession(), isNotNull);
  });
}

class _FakeStartupAuthService extends AuthService {
  _FakeStartupAuthService({this.refreshResult, this.refreshError});

  final AuthSession? refreshResult;
  final Object? refreshError;

  @override
  Future<AuthSession> refreshAndStore({String? refreshToken}) async {
    if (refreshError != null) {
      throw refreshError!;
    }
    return refreshResult ??
        AuthSession(
          accessToken: 'refreshed_access',
          refreshToken: refreshToken,
          accessExpiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
          refreshExpiresAt: DateTime.now().toUtc().add(const Duration(days: 1)),
          userId: 'user_1',
        );
  }
}

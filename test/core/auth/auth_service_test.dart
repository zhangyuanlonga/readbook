import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuxiang_reading_next/core/auth/auth_service.dart';
import 'package:shuxiang_reading_next/core/auth/auth_session.dart';
import 'package:shuxiang_reading_next/core/auth/auth_session_store.dart';
import 'package:shuxiang_reading_next/core/network/api_client.dart';

import '../../test_utils/fake_auth_session_secret_store.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test(
    'logout clears secure secrets and display cache after API success',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final secretStore = FakeAuthSessionSecretStore();
      final sessionStore = AuthSessionStore(
        preferences: prefs,
        secretStore: secretStore,
      );
      await sessionStore.saveSession(
        const AuthSession(
          accessToken: 'access_token',
          refreshToken: 'refresh_token',
          userId: 'user_1',
          username: 'tester',
          displayName: 'Tester',
        ),
      );

      final client = _FakeAuthApiClient();
      final service = AuthService(
        client: client,
        baseUrl: 'https://example.com',
        sessionStore: sessionStore,
      );

      await service.logout();

      final secrets = await secretStore.readSecrets();
      expect(client.capturedPath, '/v1/auth/logout');
      expect(client.capturedBody, <String, dynamic>{
        'refresh_token': 'refresh_token',
      });
      expect(await sessionStore.getSession(), isNull);
      expect(secrets.hasAnyValue, isFalse);
      expect(prefs.getString('auth.user_id'), isNull);
      expect(prefs.getString('auth.display_name'), isNull);
    },
  );
}

class _FakeAuthApiClient extends ApiClient {
  String? capturedPath;
  Map<String, dynamic>? capturedBody;

  @override
  Future<T> request<T>({
    required ApiMethod method,
    required String path,
    Map<String, dynamic> queryParameters = const {},
    Object? body,
    Map<String, String> headers = const {},
    Duration? timeout,
    int? maxRetries,
    bool enableRetry = true,
    bool enableCache = false,
    Duration? cacheTtl,
    bool attachAccessToken = false,
    bool enableAuthRefresh = true,
    dynamic stage,
    T Function(Object? data)? decoder,
  }) async {
    capturedPath = path;
    capturedBody = body is Map<String, dynamic> ? body : null;
    final payload = <String, dynamic>{};
    if (decoder != null) {
      return decoder(payload);
    }
    return payload as T;
  }
}

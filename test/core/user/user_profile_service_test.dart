import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuxiang_reading_next/core/auth/auth_session.dart';
import 'package:shuxiang_reading_next/core/auth/auth_session_store.dart';
import 'package:shuxiang_reading_next/core/errors/error_codes.dart';
import 'package:shuxiang_reading_next/core/errors/error_stage.dart';
import 'package:shuxiang_reading_next/core/network/api_client.dart';
import 'package:shuxiang_reading_next/core/user/user_profile_service.dart';

import '../../test_utils/fake_auth_session_secret_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('updateProfile sends bearer token to current-user endpoint', () async {
    final prefs = await SharedPreferences.getInstance();
    final sessionStore = AuthSessionStore(
      preferences: prefs,
      secretStore: FakeAuthSessionSecretStore(),
    );
    await sessionStore.saveSession(
      const AuthSession(
        accessToken: 'access-token-1',
        userId: 'usr_1',
        username: 'reader',
        account: 'reader',
        displayName: 'Reader',
      ),
    );
    final client = _FakeUserProfileApiClient();
    final service = UserProfileService(
      client: client,
      baseUrl: 'https://example.com',
      sessionStore: sessionStore,
    );

    final profile = await service.updateProfile(
      const UserProfileUpdateInput(
        displayName: 'Reader Next',
        phone: '',
        email: 'reader@example.com',
        password: '',
      ),
      userId: 'usr_1',
    );

    expect(client.paths, <String>['/v1/users/me']);
    expect(client.lastHeaders['Authorization'], 'Bearer access-token-1');
    expect(client.lastAttachAccessToken, isTrue);
    expect(client.lastBody, <String, dynamic>{
      'display_name': 'Reader Next',
      'phone': '',
      'email': 'reader@example.com',
    });
    expect(profile.displayName, 'Reader Next');
  });

  test(
    'updateProfile keeps bearer token when falling back to user id',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final sessionStore = AuthSessionStore(
        preferences: prefs,
        secretStore: FakeAuthSessionSecretStore(),
      );
      await sessionStore.saveSession(
        const AuthSession(accessToken: 'access-token-2', userId: 'usr_2'),
      );
      final client = _FakeUserProfileApiClient(
        failCurrentUserWithNotFound: true,
      );
      final service = UserProfileService(
        client: client,
        baseUrl: 'https://example.com',
        sessionStore: sessionStore,
      );

      final profile = await service.updateProfile(
        const UserProfileUpdateInput(
          displayName: 'Fallback Reader',
          phone: '13800138000',
          email: '',
          password: 'newpass1',
        ),
        userId: 'usr_2',
      );

      expect(client.paths, <String>['/v1/users/me', '/v1/users/usr_2']);
      expect(
        client.headersByPath['/v1/users/usr_2']?['Authorization'],
        'Bearer access-token-2',
      );
      expect(profile.userId, 'usr_2');
      expect(profile.displayName, 'Fallback Reader');
    },
  );
}

class _FakeUserProfileApiClient extends ApiClient {
  _FakeUserProfileApiClient({this.failCurrentUserWithNotFound = false});

  final bool failCurrentUserWithNotFound;
  final List<String> paths = <String>[];
  final Map<String, Map<String, String>> headersByPath =
      <String, Map<String, String>>{};
  Map<String, String> lastHeaders = const <String, String>{};
  Map<String, dynamic>? lastBody;
  bool? lastAttachAccessToken;

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
    ApiCachePolicy cachePolicy = ApiCachePolicy.realtime,
    Duration? cacheTtl,
    bool attachAccessToken = false,
    bool enableAuthRefresh = true,
    ErrorStage stage = ErrorStage.unknown,
    T Function(Object? data)? decoder,
  }) async {
    paths.add(path);
    lastHeaders = Map<String, String>.of(headers);
    headersByPath[path] = lastHeaders;
    lastBody = body is Map<String, dynamic> ? body : null;
    lastAttachAccessToken = attachAccessToken;

    if (path == '/v1/users/me' && failCurrentUserWithNotFound) {
      throw const ApiException(
        code: ErrorCode.unknownSource,
        briefMessage: 'not found',
        apiCode: 'NOT_FOUND',
        statusCode: 404,
      );
    }

    final payload = <String, dynamic>{
      'user': <String, dynamic>{
        'user_id': path == '/v1/users/usr_2' ? 'usr_2' : 'usr_1',
        'username': 'reader',
        'account': 'reader',
        'display_name': lastBody?['display_name'],
        'phone': lastBody?['phone'],
        'email': lastBody?['email'],
        'role': 'user',
        'created_at': '2026-05-29T00:00:00Z',
        'vip_level': 'none',
        'plan_type': 'month',
        'vip_status': 'expired',
        'vip_expire_at': null,
        'features': <String>[],
      },
    };
    if (decoder != null) {
      return decoder(payload);
    }
    return payload as T;
  }
}

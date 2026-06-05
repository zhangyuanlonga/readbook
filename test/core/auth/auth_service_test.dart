import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuxiang_reading_next/core/analytics/analytics_service.dart';
import 'package:shuxiang_reading_next/core/auth/auth_event_bus.dart';
import 'package:shuxiang_reading_next/core/auth/auth_service.dart';
import 'package:shuxiang_reading_next/core/auth/auth_session.dart';
import 'package:shuxiang_reading_next/core/auth/auth_session_store.dart';
import 'package:shuxiang_reading_next/core/device/device_heartbeat_service.dart';
import 'package:shuxiang_reading_next/core/membership/membership_service.dart';
import 'package:shuxiang_reading_next/core/membership/membership_seat_sync_result.dart';
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
      final events = <AuthEvent>[];
      final subscription = AuthEventBus.instance.stream.listen(events.add);
      addTearDown(subscription.cancel);
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
      expect(events, hasLength(1));
      expect(events.single.type, AuthEventType.loggedOut);
      expect(events.single.previousUserId, 'user_1');
    },
  );

  test(
    'login persists session and emits auth event before post-auth bootstrap finishes',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final secretStore = FakeAuthSessionSecretStore();
      final sessionStore = AuthSessionStore(
        preferences: prefs,
        secretStore: secretStore,
      );
      final client = _FakeAuthApiClient(
        responseByPath: <String, Map<String, dynamic>>{
          '/v1/auth/login': <String, dynamic>{
            'access_token': 'new_access',
            'refresh_token': 'new_refresh',
            'user_id': 'new_user',
            'username': 'new@example.com',
            'account': 'new@example.com',
            'display_name': 'New Reader',
          },
        },
      );
      final heartbeatService = _BlockingHeartbeatService();
      final events = <AuthEvent>[];
      final subscription = AuthEventBus.instance.stream.listen(events.add);
      addTearDown(subscription.cancel);
      addTearDown(heartbeatService.complete);

      final service = AuthService(
        client: client,
        baseUrl: 'https://example.com',
        heartbeatService: heartbeatService,
        analyticsService: _NoopAnalyticsService(),
        membershipService: _NoopMembershipService(),
        sessionStore: sessionStore,
      );

      final session = await service.loginAndStore(
        account: 'new@example.com',
        password: 'password123',
      );
      await Future<void>.delayed(Duration.zero);

      expect(session.userId, 'new_user');
      expect((await sessionStore.getSession())?.displayName, 'New Reader');
      expect(
        events.map((event) => event.type),
        contains(AuthEventType.loggedIn),
      );
      final loggedInEvent = events.lastWhere(
        (event) => event.type == AuthEventType.loggedIn,
      );
      expect(loggedInEvent.userId, 'new_user');
      expect(loggedInEvent.previousUserId, isNull);
      expect(heartbeatService.started, isTrue);
      expect(heartbeatService.completed, isFalse);
    },
  );

  test(
    'login event carries previous session when switching accounts',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final secretStore = FakeAuthSessionSecretStore();
      final sessionStore = AuthSessionStore(
        preferences: prefs,
        secretStore: secretStore,
      );
      await sessionStore.saveSession(
        const AuthSession(
          accessToken: 'old_access',
          refreshToken: 'old_refresh',
          userId: 'old_user',
          username: 'old@example.com',
        ),
      );
      final client = _FakeAuthApiClient(
        responseByPath: <String, Map<String, dynamic>>{
          '/v1/auth/login': <String, dynamic>{
            'access_token': 'new_access',
            'refresh_token': 'new_refresh',
            'user_id': 'new_user',
            'username': 'new@example.com',
            'account': 'new@example.com',
          },
        },
      );
      final events = <AuthEvent>[];
      final subscription = AuthEventBus.instance.stream.listen(events.add);
      addTearDown(subscription.cancel);
      final service = AuthService(
        client: client,
        baseUrl: 'https://example.com',
        heartbeatService: _ImmediateHeartbeatService(),
        analyticsService: _NoopAnalyticsService(),
        membershipService: _NoopMembershipService(),
        sessionStore: sessionStore,
      );

      await service.loginAndStore(
        account: 'new@example.com',
        password: 'password123',
      );
      await Future<void>.delayed(Duration.zero);

      final loggedInEvent = events.lastWhere(
        (event) => event.type == AuthEventType.loggedIn,
      );
      expect(loggedInEvent.userId, 'new_user');
      expect(loggedInEvent.previousUserId, 'old_user');
      expect(loggedInEvent.isAccountSwitch, isTrue);
    },
  );
}

class _FakeAuthApiClient extends ApiClient {
  _FakeAuthApiClient({
    this.responseByPath = const <String, Map<String, dynamic>>{},
  });

  final Map<String, Map<String, dynamic>> responseByPath;
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
    final payload = responseByPath[path] ?? <String, dynamic>{};
    if (decoder != null) {
      return decoder(payload);
    }
    return payload as T;
  }
}

class _BlockingHeartbeatService extends DeviceHeartbeatService {
  _BlockingHeartbeatService() : super(baseUrl: 'https://example.com');

  final Completer<void> _completer = Completer<void>();
  bool started = false;
  bool completed = false;

  @override
  Future<void> sendHeartbeat() async {
    started = true;
    await _completer.future;
    completed = true;
  }

  void complete() {
    if (!_completer.isCompleted) {
      _completer.complete();
    }
  }
}

class _ImmediateHeartbeatService extends DeviceHeartbeatService {
  _ImmediateHeartbeatService() : super(baseUrl: 'https://example.com');

  @override
  Future<void> sendHeartbeat() async {}
}

class _NoopAnalyticsService extends AnalyticsService {
  _NoopAnalyticsService() : super(baseUrl: 'https://example.com');

  @override
  Future<void> trackVisit({
    String? channel,
    DateTime? occurredAt,
    int visitCount = 1,
    int visitSeconds = 0,
  }) async {}
}

class _NoopMembershipService extends MembershipService {
  _NoopMembershipService() : super(baseUrl: 'https://example.com');

  @override
  Future<MembershipSeatSyncResult> syncCurrentDeviceSeat() async {
    return const MembershipSeatSyncResult(
      deviceStatus: 'ok',
      maxDevices: 1,
      activeDeviceCount: 1,
      seat: null,
    );
  }
}

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuxiang_reading_next/app/lifecycle/app_lifecycle_coordinator.dart';
import 'package:shuxiang_reading_next/core/auth/auth_event_bus.dart';
import 'package:shuxiang_reading_next/core/auth/auth_session.dart';
import 'package:shuxiang_reading_next/core/auth/session_change_listener.dart';
import 'package:shuxiang_reading_next/core/network/api_client.dart';
import 'package:shuxiang_reading_next/core/network/auth_token_refresher.dart';
import 'package:shuxiang_reading_next/features/source/application/external_source_import_bridge.dart';

class _FakeAuthTokenRefresher implements AuthTokenRefresher {
  @override
  Future<String?> getAccessToken() async => null;

  @override
  Future<bool> refreshToken() async => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  tearDown(() {
    ApiClient.defaultAuthTokenRefresher = null;
    ApiClient.defaultCacheUserIdResolver = null;
  });

  test('initialize wires import and auth streams', () async {
    final importController =
        StreamController<IncomingExternalImportPayload>.broadcast();
    final authController = StreamController<AuthEvent>.broadcast();
    var initializeCalls = 0;
    final sessionListener = _RecordingSessionChangeListener();
    final coordinator = AppLifecycleCoordinator(
      incomingExternalImportStream: importController.stream,
      authEventStream: authController.stream,
      initializeExternalImportBridge: () async {
        initializeCalls += 1;
      },
      authTokenRefresher: _FakeAuthTokenRefresher(),
      sessionChangeListeners: <SessionChangeListener>[sessionListener],
    );

    final receivedPayloads = <IncomingExternalImportPayload>[];
    final receivedEvents = <AuthEvent>[];

    await coordinator.initialize(
      onIncomingExternalImportPayload: receivedPayloads.add,
      onAuthEvent: receivedEvents.add,
    );

    final payload = IncomingExternalImportPayload.localBook(
      uri: 'file:///tmp/book.txt',
      label: 'Book',
    );
    const event = AuthEvent(
      type: AuthEventType.loggedOut,
      message: 'logged out',
      previousSession: AuthSession(accessToken: 'token', userId: 'user-a'),
    );

    importController.add(payload);
    authController.add(event);
    await Future<void>.delayed(Duration.zero);

    expect(initializeCalls, 1);
    expect(ApiClient.defaultAuthTokenRefresher, isNotNull);
    expect(receivedPayloads, hasLength(1));
    expect(receivedPayloads.single, same(payload));
    expect(receivedEvents, hasLength(1));
    expect(receivedEvents.single, event);
    expect(sessionListener.logouts, <String?>['user-a']);

    coordinator.dispose();
    await importController.close();
    await authController.close();
  });

  test('sendHeartbeat throttles repeated calls within window', () async {
    var heartbeatCalls = 0;
    var now = DateTime(2026, 4, 26, 12);
    final coordinator = AppLifecycleCoordinator(
      incomingExternalImportStream:
          const Stream<IncomingExternalImportPayload>.empty(),
      authEventStream: const Stream<AuthEvent>.empty(),
      initializeExternalImportBridge: () async {},
      authTokenRefresher: _FakeAuthTokenRefresher(),
      sendHeartbeat: () async {
        heartbeatCalls += 1;
      },
      now: () => now,
    );

    await coordinator.sendHeartbeat();
    await coordinator.sendHeartbeat();
    now = now.add(
      AppLifecycleCoordinator.heartbeatThrottle + const Duration(seconds: 1),
    );
    await coordinator.sendHeartbeat();

    expect(heartbeatCalls, 2);
  });

  test('resumed lifecycle triggers heartbeat and visit reporting', () async {
    var heartbeatCalls = 0;
    var visitCalls = 0;
    final coordinator = AppLifecycleCoordinator(
      incomingExternalImportStream:
          const Stream<IncomingExternalImportPayload>.empty(),
      authEventStream: const Stream<AuthEvent>.empty(),
      initializeExternalImportBridge: () async {},
      authTokenRefresher: _FakeAuthTokenRefresher(),
      sendHeartbeat: () async {
        heartbeatCalls += 1;
      },
      trackVisit: () async {
        visitCalls += 1;
      },
    );

    coordinator.handleAppLifecycleState(AppLifecycleState.resumed);
    await Future<void>.delayed(Duration.zero);

    expect(heartbeatCalls, 1);
    expect(visitCalls, 1);
  });

  test('sendVisitEvent throttles repeated calls within window', () async {
    var visitCalls = 0;
    var now = DateTime(2026, 5, 12, 10);
    final coordinator = AppLifecycleCoordinator(
      incomingExternalImportStream:
          const Stream<IncomingExternalImportPayload>.empty(),
      authEventStream: const Stream<AuthEvent>.empty(),
      initializeExternalImportBridge: () async {},
      authTokenRefresher: _FakeAuthTokenRefresher(),
      trackVisit: () async {
        visitCalls += 1;
      },
      now: () => now,
    );

    await coordinator.sendVisitEvent();
    await coordinator.sendVisitEvent();
    now = now.add(
      AppLifecycleCoordinator.visitThrottle + const Duration(seconds: 1),
    );
    await coordinator.sendVisitEvent();

    expect(visitCalls, 2);
  });
}

class _RecordingSessionChangeListener implements SessionChangeListener {
  final List<String?> logouts = <String?>[];

  @override
  Future<void> onUserLogin(String userId) async {}

  @override
  Future<void> onUserLogout(String? userId) async {
    logouts.add(userId);
  }
}

import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../core/analytics/analytics_service.dart';
import '../../core/auth/auth_event_bus.dart';
import '../../core/auth/auth_token_refresher_impl.dart';
import '../../core/device/device_heartbeat_service.dart';
import '../../core/network/api_client.dart';
import '../../core/network/auth_token_refresher.dart';
import '../../features/source/application/external_source_import_bridge.dart';

typedef AppIncomingExternalImportHandler =
    void Function(IncomingExternalImportPayload payload);
typedef AppAuthEventHandler = void Function(AuthEvent event);

class AppLifecycleCoordinator {
  AppLifecycleCoordinator({
    Stream<IncomingExternalImportPayload>? incomingExternalImportStream,
    Stream<AuthEvent>? authEventStream,
    Future<void> Function()? initializeExternalImportBridge,
    AuthTokenRefresher? authTokenRefresher,
    DeviceHeartbeatService? deviceHeartbeatService,
    AnalyticsService? analyticsService,
    Future<void> Function()? sendHeartbeat,
    Future<void> Function()? trackVisit,
    DateTime Function()? now,
  }) : _incomingExternalImportStream =
           incomingExternalImportStream ??
           ExternalImportBridge.instance.payloadStream,
       _authEventStream = authEventStream ?? AuthEventBus.instance.stream,
       _initializeExternalImportBridge =
           initializeExternalImportBridge ??
           ExternalImportBridge.instance.initialize,
       _authTokenRefresher = authTokenRefresher,
       _deviceHeartbeatService = deviceHeartbeatService,
       _analyticsService = analyticsService,
       _sendHeartbeat = sendHeartbeat,
       _trackVisit = trackVisit,
       _now = now ?? DateTime.now;

  static const Duration heartbeatThrottle = Duration(minutes: 2);

  final Stream<IncomingExternalImportPayload> _incomingExternalImportStream;
  final Stream<AuthEvent> _authEventStream;
  final Future<void> Function() _initializeExternalImportBridge;
  final AuthTokenRefresher? _authTokenRefresher;
  final DeviceHeartbeatService? _deviceHeartbeatService;
  final AnalyticsService? _analyticsService;
  final Future<void> Function()? _sendHeartbeat;
  final Future<void> Function()? _trackVisit;
  final DateTime Function() _now;

  StreamSubscription<IncomingExternalImportPayload>? _incomingImportSub;
  StreamSubscription<AuthEvent>? _authEventSub;
  bool _initialized = false;
  bool _isHeartbeatInFlight = false;
  bool _isVisitInFlight = false;
  DateTime? _lastHeartbeatAt;

  Future<void> initialize({
    required AppIncomingExternalImportHandler onIncomingExternalImportPayload,
    required AppAuthEventHandler onAuthEvent,
  }) async {
    if (_initialized) {
      return;
    }
    _initialized = true;
    ApiClient.defaultAuthTokenRefresher ??=
        _authTokenRefresher ?? AuthTokenRefresherImpl();
    _incomingImportSub = _incomingExternalImportStream.listen(
      onIncomingExternalImportPayload,
    );
    _authEventSub = _authEventStream.listen(onAuthEvent);
    await _initializeExternalImportBridge();
  }

  void handleAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      return;
    }
    unawaited(sendHeartbeat());
    unawaited(sendVisitEvent());
  }

  Future<void> sendHeartbeat() async {
    if (_isHeartbeatInFlight) {
      return;
    }
    final now = _now();
    final last = _lastHeartbeatAt;
    if (last != null && now.difference(last) < heartbeatThrottle) {
      return;
    }
    _isHeartbeatInFlight = true;
    try {
      final sendHeartbeat =
          _sendHeartbeat ??
          (_deviceHeartbeatService ?? DeviceHeartbeatService()).sendHeartbeat;
      await sendHeartbeat();
      _lastHeartbeatAt = now;
    } catch (_) {
      // Ignore heartbeat failures to avoid blocking startup or resume.
    } finally {
      _isHeartbeatInFlight = false;
    }
  }

  Future<void> sendVisitEvent() async {
    if (_isVisitInFlight) {
      return;
    }
    _isVisitInFlight = true;
    try {
      final trackVisit =
          _trackVisit ??
          () async => (_analyticsService ?? AnalyticsService()).trackVisit(
            visitCount: 1,
            visitSeconds: 0,
          );
      await trackVisit();
    } catch (_) {
      // Ignore analytics failures to avoid blocking startup or resume.
    } finally {
      _isVisitInFlight = false;
    }
  }

  void dispose() {
    unawaited(_incomingImportSub?.cancel());
    unawaited(_authEventSub?.cancel());
    _incomingImportSub = null;
    _authEventSub = null;
  }
}

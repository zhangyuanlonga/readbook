import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/auth/auth_event_bus.dart';
import '../../source/application/external_source_import_bridge.dart';

typedef AdvancedThemeIncomingImportHandler =
    Future<void> Function(IncomingExternalImportPayload payload);

class AdvancedThemePageFlowCoordinator {
  AdvancedThemePageFlowCoordinator({
    ExternalImportBridge? externalImportBridge,
    Stream<AuthEvent>? authEvents,
  }) : _externalImportBridge =
           externalImportBridge ?? ExternalImportBridge.instance,
       _authEvents = authEvents ?? AuthEventBus.instance.stream;

  final ExternalImportBridge _externalImportBridge;
  final Stream<AuthEvent> _authEvents;

  StreamSubscription<IncomingExternalImportPayload>? _payloadSubscription;
  StreamSubscription<AuthEvent>? _authEventSubscription;

  void initialize({
    required VoidCallback onPendingImportAvailable,
    required void Function(AuthEvent event) onAuthEvent,
  }) {
    _payloadSubscription ??= _externalImportBridge.payloadStream.listen((
      payload,
    ) {
      if (payload.type != ExternalImportPayloadType.advancedTheme) {
        return;
      }
      onPendingImportAvailable();
    });
    _authEventSubscription ??= _authEvents.listen(onAuthEvent);
  }

  Future<void> consumePendingPayloads(
    AdvancedThemeIncomingImportHandler handler,
  ) async {
    while (true) {
      final payload = _externalImportBridge.consumePendingPayload(
        type: ExternalImportPayloadType.advancedTheme,
      );
      if (payload == null) {
        return;
      }
      await handler(payload);
    }
  }

  Future<CachedExternalImportFile?> cacheExternalFileFromUri(
    IncomingExternalImportPayload payload,
  ) {
    return _externalImportBridge.cacheExternalFileFromUri(payload);
  }

  Future<void> dispose() async {
    await _payloadSubscription?.cancel();
    await _authEventSubscription?.cancel();
    _payloadSubscription = null;
    _authEventSubscription = null;
  }
}

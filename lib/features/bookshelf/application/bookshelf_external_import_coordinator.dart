import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../source/application/external_source_import_bridge.dart';

typedef BookshelfIncomingImportHandler =
    Future<void> Function(IncomingExternalImportPayload payload);

class BookshelfExternalImportCoordinator {
  BookshelfExternalImportCoordinator({
    ExternalImportBridge? externalImportBridge,
  }) : _externalImportBridge =
           externalImportBridge ?? ExternalImportBridge.instance;

  final ExternalImportBridge _externalImportBridge;

  StreamSubscription<IncomingExternalImportPayload>? _payloadSubscription;

  void initialize({required VoidCallback onPendingImportAvailable}) {
    if (_payloadSubscription != null) {
      return;
    }
    _payloadSubscription = _externalImportBridge.payloadStream.listen((
      payload,
    ) {
      if (payload.type != ExternalImportPayloadType.localBook) {
        return;
      }
      onPendingImportAvailable();
    });
  }

  Future<void> consumePendingPayloads(
    BookshelfIncomingImportHandler handler,
  ) async {
    while (true) {
      final payload = _externalImportBridge.consumePendingPayload(
        type: ExternalImportPayloadType.localBook,
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

  Future<List<IncomingExternalImportPayload>> pickLocalBookFiles() {
    return _externalImportBridge.pickLocalBookFiles();
  }

  Future<void> dispose() async {
    await _payloadSubscription?.cancel();
    _payloadSubscription = null;
  }
}

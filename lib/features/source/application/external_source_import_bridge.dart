import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class IncomingSourceImportPayload {
  const IncomingSourceImportPayload({required this.bytes, required this.label});

  final Uint8List bytes;
  final String label;
}

class ExternalSourceImportBridge {
  ExternalSourceImportBridge._();

  static final ExternalSourceImportBridge instance =
      ExternalSourceImportBridge._();

  static const MethodChannel _channel = MethodChannel(
    'com.example.flutter_appread/source_import_intent',
  );

  final StreamController<IncomingSourceImportPayload> _payloadController =
      StreamController<IncomingSourceImportPayload>.broadcast();
  final Queue<IncomingSourceImportPayload> _pendingPayloads =
      Queue<IncomingSourceImportPayload>();

  bool _initialized = false;

  Stream<IncomingSourceImportPayload> get payloadStream =>
      _payloadController.stream;

  Future<void> initialize() async {
    if (_initialized || kIsWeb) {
      _initialized = true;
      return;
    }
    _initialized = true;

    _channel.setMethodCallHandler(_onMethodCall);

    try {
      final payload = _parsePayload(
        await _channel.invokeMethod<dynamic>('getInitialImportPayload'),
      );
      if (payload != null) {
        _pushPayload(payload);
      }
    } on MissingPluginException {
      // Non-Android platforms may not provide this channel.
    } on PlatformException {
      // Ignore channel failures to avoid blocking app startup.
    }
  }

  IncomingSourceImportPayload? consumePendingPayload() {
    if (_pendingPayloads.isEmpty) {
      return null;
    }
    return _pendingPayloads.removeFirst();
  }

  Future<dynamic> _onMethodCall(MethodCall call) async {
    if (call.method != 'onImportPayload') {
      return null;
    }

    final payload = _parsePayload(call.arguments);
    if (payload != null) {
      _pushPayload(payload);
    }
    return null;
  }

  void _pushPayload(IncomingSourceImportPayload payload) {
    _pendingPayloads.addLast(payload);
    if (!_payloadController.isClosed) {
      _payloadController.add(payload);
    }
  }

  IncomingSourceImportPayload? _parsePayload(dynamic raw) {
    if (raw is! Map<Object?, Object?>) {
      return null;
    }

    final bytesRaw = raw['bytes'];
    Uint8List? bytes;
    if (bytesRaw is Uint8List) {
      bytes = bytesRaw;
    } else if (bytesRaw is List<int>) {
      bytes = Uint8List.fromList(bytesRaw);
    }
    if (bytes == null || bytes.isEmpty) {
      return null;
    }

    final labelRaw = raw['label'];
    final label =
        labelRaw is String && labelRaw.trim().isNotEmpty
            ? labelRaw.trim()
            : '外部书源';

    return IncomingSourceImportPayload(bytes: bytes, label: label);
  }
}

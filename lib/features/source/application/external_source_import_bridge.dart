import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'external_import_diagnostics.dart';

enum ExternalImportPayloadType { localBook, scriptSource, advancedTheme, font }

class IncomingExternalImportPayload {
  const IncomingExternalImportPayload.localBook({
    required this.uri,
    required this.label,
    this.mimeType,
  }) : type = ExternalImportPayloadType.localBook;

  const IncomingExternalImportPayload.scriptSource({
    required this.uri,
    required this.label,
    this.mimeType,
  }) : type = ExternalImportPayloadType.scriptSource;

  const IncomingExternalImportPayload.advancedTheme({
    required this.uri,
    required this.label,
    this.mimeType,
  }) : type = ExternalImportPayloadType.advancedTheme;

  const IncomingExternalImportPayload.font({
    required this.uri,
    required this.label,
    this.mimeType,
  }) : type = ExternalImportPayloadType.font;

  final ExternalImportPayloadType type;
  final String label;
  final String uri;
  final String? mimeType;
}

class CachedExternalImportFile {
  const CachedExternalImportFile({
    required this.path,
    required this.label,
    this.mimeType,
  });

  final String path;
  final String label;
  final String? mimeType;
}

class ExternalImportBridge {
  ExternalImportBridge._();

  static final ExternalImportBridge instance = ExternalImportBridge._();

  static const MethodChannel _channel = MethodChannel(
    'com.jiangyan.selune/source_import_intent',
  );
  static const String _methodGetInitialImportPayload =
      'getInitialImportPayload';
  static const String _methodCacheExternalFileFromUri =
      'cacheExternalFileFromUri';

  final StreamController<IncomingExternalImportPayload> _payloadController =
      StreamController<IncomingExternalImportPayload>.broadcast();
  final Queue<IncomingExternalImportPayload> _pendingPayloads =
      Queue<IncomingExternalImportPayload>();

  bool _initialized = false;

  Stream<IncomingExternalImportPayload> get payloadStream =>
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
        await _channel.invokeMethod<dynamic>(_methodGetInitialImportPayload),
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

  IncomingExternalImportPayload? consumePendingPayload({
    ExternalImportPayloadType? type,
  }) {
    if (_pendingPayloads.isEmpty) {
      return null;
    }
    if (type == null) {
      return _pendingPayloads.removeFirst();
    }

    final matchIndex = _pendingPayloads
        .toList(growable: false)
        .indexWhere((payload) => payload.type == type);
    if (matchIndex < 0) {
      return null;
    }

    final payload = _pendingPayloads.elementAt(matchIndex);
    _pendingPayloads.remove(payload);
    return payload;
  }

  Future<CachedExternalImportFile?> cacheExternalFileFromUri(
    IncomingExternalImportPayload payload,
  ) async {
    if ((payload.type != ExternalImportPayloadType.localBook &&
            payload.type != ExternalImportPayloadType.scriptSource &&
            payload.type != ExternalImportPayloadType.advancedTheme &&
            payload.type != ExternalImportPayloadType.font) ||
        payload.uri.trim().isEmpty) {
      return null;
    }

    try {
      final raw = await _channel.invokeMethod<dynamic>(
        _methodCacheExternalFileFromUri,
        <String, dynamic>{
          'type': switch (payload.type) {
            ExternalImportPayloadType.localBook => 'localBook',
            ExternalImportPayloadType.scriptSource => 'scriptSource',
            ExternalImportPayloadType.advancedTheme => 'advancedTheme',
            ExternalImportPayloadType.font => 'font',
          },
          'uri': payload.uri,
          'label': payload.label,
          'mimeType': payload.mimeType,
        },
      );
      if (raw is! Map<Object?, Object?>) {
        return null;
      }

      final path = raw['path']?.toString().trim() ?? '';
      if (path.isEmpty) {
        return null;
      }
      final label = raw['label']?.toString().trim();
      final mimeType = raw['mimeType']?.toString().trim();
      return CachedExternalImportFile(
        path: path,
        label: label == null || label.isEmpty ? payload.label : label,
        mimeType: mimeType == null || mimeType.isEmpty ? null : mimeType,
      );
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
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

  void _pushPayload(IncomingExternalImportPayload payload) {
    ExternalImportDiagnostics.logPayloadQueued(payload);
    _pendingPayloads.addLast(payload);
    if (!_payloadController.isClosed) {
      _payloadController.add(payload);
    }
  }

  IncomingExternalImportPayload? _parsePayload(dynamic raw) {
    if (raw is! Map<Object?, Object?>) {
      if (raw != null) {
        ExternalImportDiagnostics.logPayloadMalformed(raw);
      }
      return null;
    }

    final typeRaw = raw['type']?.toString().trim().toLowerCase();
    final labelRaw = raw['label'];
    final label =
        labelRaw is String && labelRaw.trim().isNotEmpty
            ? labelRaw.trim()
            : '外部导入';

    if (typeRaw == 'localbook') {
      final uriRaw = raw['uri']?.toString().trim() ?? '';
      if (uriRaw.isEmpty) {
        return null;
      }
      final mimeTypeRaw = raw['mimeType'];
      final mimeType =
          mimeTypeRaw is String && mimeTypeRaw.trim().isNotEmpty
              ? mimeTypeRaw.trim()
              : null;
      return IncomingExternalImportPayload.localBook(
        uri: uriRaw,
        label: label,
        mimeType: mimeType,
      );
    }
    if (typeRaw == 'scriptsource') {
      final uriRaw = raw['uri']?.toString().trim() ?? '';
      if (uriRaw.isEmpty) {
        return null;
      }
      final mimeTypeRaw = raw['mimeType'];
      final mimeType =
          mimeTypeRaw is String && mimeTypeRaw.trim().isNotEmpty
              ? mimeTypeRaw.trim()
              : null;
      return IncomingExternalImportPayload.scriptSource(
        uri: uriRaw,
        label: label,
        mimeType: mimeType,
      );
    }
    if (typeRaw == 'advancedtheme') {
      final uriRaw = raw['uri']?.toString().trim() ?? '';
      if (uriRaw.isEmpty) {
        return null;
      }
      final mimeTypeRaw = raw['mimeType'];
      final mimeType =
          mimeTypeRaw is String && mimeTypeRaw.trim().isNotEmpty
              ? mimeTypeRaw.trim()
              : null;
      return IncomingExternalImportPayload.advancedTheme(
        uri: uriRaw,
        label: label,
        mimeType: mimeType,
      );
    }
    if (typeRaw == 'font') {
      final uriRaw = raw['uri']?.toString().trim() ?? '';
      if (uriRaw.isEmpty) {
        return null;
      }
      final mimeTypeRaw = raw['mimeType'];
      final mimeType =
          mimeTypeRaw is String && mimeTypeRaw.trim().isNotEmpty
              ? mimeTypeRaw.trim()
              : null;
      return IncomingExternalImportPayload.font(
        uri: uriRaw,
        label: label,
        mimeType: mimeType,
      );
    }
    ExternalImportDiagnostics.logPayloadMalformed(raw);
    return null;
  }
}

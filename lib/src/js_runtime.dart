import 'dart:async';

import 'js_runtime_stub.dart'
    if (dart.library.io) 'js_runtime_native.dart'
    as runtime_impl;

typedef JsBridgeHandler = FutureOr<Object?> Function(dynamic args);

class JsExecutionResult {
  const JsExecutionResult({required this.output, required this.isError});

  final String output;
  final bool isError;
}

abstract class JsRuntimeAdapter {
  bool get isSupported;
  String? get unsupportedReason;

  void registerBridge(String channelName, JsBridgeHandler handler);
  Future<void> installBootstrap(String source, {String? sourceUrl});
  Future<void> installPlaygroundBootstrap();
  Future<JsExecutionResult> runSnippet(String script);
  void dispose();
}

JsRuntimeAdapter createJsRuntimeAdapter() =>
    runtime_impl.createJsRuntimeAdapter();

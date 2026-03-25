import 'js_runtime.dart';

JsRuntimeAdapter createJsRuntimeAdapter() =>
    const UnsupportedJsRuntimeAdapter();

class UnsupportedJsRuntimeAdapter implements JsRuntimeAdapter {
  const UnsupportedJsRuntimeAdapter();

  @override
  bool get isSupported => false;

  @override
  String? get unsupportedReason =>
      'flutter_js 当前不支持 Flutter Web，请改用 Android、iOS、macOS、Windows 或 Linux 目标运行。';

  @override
  Future<void> installBootstrap(String source, {String? sourceUrl}) async {}

  @override
  Future<void> installPlaygroundBootstrap() async {}

  @override
  void registerBridge(String channelName, JsBridgeHandler handler) {}

  @override
  Future<JsExecutionResult> runSnippet(String script) async {
    return JsExecutionResult(
      output: unsupportedReason ?? '当前平台不支持 flutter_js。',
      isError: true,
    );
  }

  @override
  void dispose() {}
}

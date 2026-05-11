import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/app/platform/app_platform_capabilities.dart';

void main() {
  test('source runtime and WebDAV are opt-in stage capabilities', () {
    final disabled = AppPlatformCapabilities.current(
      sourceRuntimeEnabled: false,
      webDavSyncEnabled: false,
    );

    expect(disabled.supportsSourceRuntime, isFalse);
    expect(disabled.supportsInteractiveWebView, isFalse);
    expect(disabled.supportsSourceDebugServer, isFalse);
    expect(disabled.supportsWebDavSync, isFalse);

    final enabled = AppPlatformCapabilities.current(
      sourceRuntimeEnabled: true,
      webDavSyncEnabled: true,
    );

    expect(enabled.supportsSourceRuntime, !kIsWeb);
    expect(enabled.supportsWebDavSync, !kIsWeb);
  });
}

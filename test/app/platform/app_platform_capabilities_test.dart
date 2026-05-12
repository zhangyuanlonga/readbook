import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/app/platform/app_platform_capabilities.dart';

void main() {
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test(
    'source runtime and WebDAV sync default to enabled on Android and iOS',
    () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      var capabilities = AppPlatformCapabilities.current();

      expect(capabilities.supportsSourceRuntime, isTrue);
      expect(capabilities.supportsWebDavSync, isTrue);
      expect(capabilities.supportsInteractiveWebView, isTrue);

      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      capabilities = AppPlatformCapabilities.current();

      expect(capabilities.supportsSourceRuntime, isTrue);
      expect(capabilities.supportsWebDavSync, isTrue);
      expect(capabilities.supportsInteractiveWebView, isTrue);
    },
  );

  test('source runtime and WebDAV sync default to disabled on desktop', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

    final capabilities = AppPlatformCapabilities.current();

    expect(capabilities.supportsSourceRuntime, isFalse);
    expect(capabilities.supportsInteractiveWebView, isFalse);
    expect(capabilities.supportsWebDavSync, isFalse);
  });

  test('source runtime explicit override is still respected', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    final disabled = AppPlatformCapabilities.current(
      sourceRuntimeEnabled: false,
      webDavSyncEnabled: false,
    );

    expect(disabled.supportsSourceRuntime, isFalse);
    expect(disabled.supportsInteractiveWebView, isFalse);
    expect(disabled.supportsWebDavSync, isFalse);

    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

    final enabled = AppPlatformCapabilities.current(
      sourceRuntimeEnabled: true,
      webDavSyncEnabled: true,
    );

    expect(enabled.supportsSourceRuntime, !kIsWeb);
    expect(enabled.supportsWebDavSync, !kIsWeb);
  });
}

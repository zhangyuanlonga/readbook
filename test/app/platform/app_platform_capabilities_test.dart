import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/app/platform/app_platform_capabilities.dart';

void main() {
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test('source runtime defaults to enabled on Android and iOS', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    expect(AppPlatformCapabilities.current().supportsSourceRuntime, isTrue);
    expect(
      AppPlatformCapabilities.current().supportsInteractiveWebView,
      isTrue,
    );

    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    expect(AppPlatformCapabilities.current().supportsSourceRuntime, isTrue);
    expect(
      AppPlatformCapabilities.current().supportsInteractiveWebView,
      isTrue,
    );
  });

  test('source runtime defaults to disabled on desktop', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

    final capabilities = AppPlatformCapabilities.current();

    expect(capabilities.supportsSourceRuntime, isFalse);
    expect(capabilities.supportsInteractiveWebView, isFalse);
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

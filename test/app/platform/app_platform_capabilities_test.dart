import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/app/platform/app_capability_state.dart';
import 'package:shuxiang_reading_next/app/platform/app_platform_capabilities.dart';

void main() {
  group('AppPlatformCapabilities', () {
    test('profile avatar uses file picker on desktop platforms', () {
      for (final platform in <TargetPlatform>[
        TargetPlatform.macOS,
        TargetPlatform.windows,
        TargetPlatform.linux,
      ]) {
        final capabilities = _capabilities(platform: platform);

        expect(capabilities.shouldUseFilePickerForProfileAvatar, isTrue);
      }
    });

    test('profile avatar keeps action surface on mobile platforms', () {
      for (final platform in <TargetPlatform>[
        TargetPlatform.android,
        TargetPlatform.iOS,
      ]) {
        final capabilities = _capabilities(platform: platform);

        expect(capabilities.shouldUseFilePickerForProfileAvatar, isFalse);
      }
    });

    test('profile avatar uses file picker on web target', () {
      final capabilities = _capabilities(
        platform: TargetPlatform.android,
        isWeb: true,
      );

      expect(capabilities.shouldUseFilePickerForProfileAvatar, isTrue);
    });

    test(
      'web local reading uses upload bytes instead of native path chain',
      () {
        final web = _capabilities(
          platform: TargetPlatform.android,
          isWeb: true,
          localFileImportSupported: false,
          managedFileStorageSupported: false,
        );
        final native = _capabilities(platform: TargetPlatform.macOS);

        expect(web.supportsWebUploadedLocalReading, isTrue);
        expect(web.supportsNativeLocalReading, isFalse);
        expect(native.supportsWebUploadedLocalReading, isFalse);
        expect(native.supportsNativeLocalReading, isTrue);
      },
    );
  });
}

AppPlatformCapabilities _capabilities({
  required TargetPlatform platform,
  bool isWeb = false,
  bool localFileImportSupported = true,
  bool managedFileStorageSupported = true,
}) {
  const supported = AppCapabilityState.supported(label: 'test');
  const unsupported = AppCapabilityState.unsupported(
    label: 'test',
    reason: 'unsupported',
  );
  return AppPlatformCapabilities(
    platform: platform,
    isWeb: isWeb,
    buildTarget:
        isWeb
            ? AppPlatformBuildTarget.webJs
            : switch (platform) {
              TargetPlatform.android => AppPlatformBuildTarget.android,
              TargetPlatform.iOS => AppPlatformBuildTarget.ios,
              TargetPlatform.macOS => AppPlatformBuildTarget.macos,
              TargetPlatform.windows => AppPlatformBuildTarget.windows,
              TargetPlatform.linux => AppPlatformBuildTarget.linux,
              _ => AppPlatformBuildTarget.unknown,
            },
    verificationStatus: AppPlatformVerificationStatus.stable,
    webFileUpload: supported,
    localFileImport: localFileImportSupported ? supported : unsupported,
    managedFileStorage: managedFileStorageSupported ? supported : unsupported,
    nativeSqlite: supported,
    driftWebStorage: supported,
    embeddedWebView: supported,
    imagePicking: supported,
    diagnosticLogExport: supported,
    desktopWindowControls: supported,
    audioPlayback: supported,
    readerBrightnessBridge: supported,
    readerVolumeKeyBridge: supported,
  );
}

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppPlatformCapabilities {
  const AppPlatformCapabilities({
    required this.platform,
    required this.isWeb,
    required this.supportsLocalFileImport,
    required this.supportsManagedFileStorage,
    required this.supportsNativeSqlite,
    required this.supportsDriftWebStorage,
    required this.supportsImagePicking,
    required this.supportsReaderBrightnessBridge,
    required this.supportsReaderVolumeKeyBridge,
    required this.supportsSourceRuntime,
    required this.supportsInteractiveWebView,
    required this.supportsSourceDebugServer,
    required this.supportsWebDavSync,
  });

  factory AppPlatformCapabilities.current({
    bool sourceRuntimeEnabled = _sourceRuntimeEnabledByDefine,
  }) {
    final platform = defaultTargetPlatform;
    final isMobile =
        platform == TargetPlatform.android || platform == TargetPlatform.iOS;
    final isDesktop =
        platform == TargetPlatform.macOS ||
        platform == TargetPlatform.windows ||
        platform == TargetPlatform.linux;
    final supportsNativeFileSystem = !kIsWeb;
    final sourceRuntimeSupportedPlatform = !kIsWeb;

    return AppPlatformCapabilities(
      platform: platform,
      isWeb: kIsWeb,
      supportsLocalFileImport: supportsNativeFileSystem,
      supportsManagedFileStorage: supportsNativeFileSystem,
      supportsNativeSqlite: supportsNativeFileSystem,
      supportsDriftWebStorage: kIsWeb,
      supportsImagePicking: !kIsWeb && (isMobile || isDesktop),
      supportsReaderBrightnessBridge: !kIsWeb && isMobile,
      supportsReaderVolumeKeyBridge: !kIsWeb && isMobile,
      supportsSourceRuntime:
          sourceRuntimeEnabled && sourceRuntimeSupportedPlatform,
      supportsInteractiveWebView:
          sourceRuntimeEnabled && sourceRuntimeSupportedPlatform,
      supportsSourceDebugServer:
          sourceRuntimeEnabled && sourceRuntimeSupportedPlatform && !kIsWeb,
      supportsWebDavSync: supportsNativeFileSystem,
    );
  }

  final TargetPlatform platform;
  final bool isWeb;
  final bool supportsLocalFileImport;
  final bool supportsManagedFileStorage;
  final bool supportsNativeSqlite;
  final bool supportsDriftWebStorage;
  final bool supportsImagePicking;
  final bool supportsReaderBrightnessBridge;
  final bool supportsReaderVolumeKeyBridge;
  final bool supportsSourceRuntime;
  final bool supportsInteractiveWebView;
  final bool supportsSourceDebugServer;
  final bool supportsWebDavSync;

  bool get supportsLocalReading =>
      supportsLocalFileImport &&
      supportsManagedFileStorage &&
      (supportsNativeSqlite || supportsDriftWebStorage);
}

const bool _sourceRuntimeEnabledByDefine = bool.fromEnvironment(
  'APP_ENABLE_SOURCE_RUNTIME',
  defaultValue: false,
);

final appPlatformCapabilitiesProvider = Provider<AppPlatformCapabilities>((
  ref,
) {
  return AppPlatformCapabilities.current();
});

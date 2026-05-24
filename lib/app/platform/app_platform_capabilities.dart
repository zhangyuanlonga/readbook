import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_capability_state.dart';

class AppPlatformCapabilities {
  const AppPlatformCapabilities({
    required this.platform,
    required this.isWeb,
    required this.localFileImport,
    required this.managedFileStorage,
    required this.nativeSqlite,
    required this.driftWebStorage,
    required this.imagePicking,
    required this.readerBrightnessBridge,
    required this.readerVolumeKeyBridge,
    required this.webDavSync,
  });

  factory AppPlatformCapabilities.current({bool? webDavSyncEnabled}) {
    final platform = defaultTargetPlatform;
    final isMobile =
        platform == TargetPlatform.android || platform == TargetPlatform.iOS;
    final isDesktop =
        platform == TargetPlatform.macOS ||
        platform == TargetPlatform.windows ||
        platform == TargetPlatform.linux;
    final supportsNativeFileSystem = !kIsWeb;
    final resolvedWebDavSyncEnabled =
        webDavSyncEnabled ??
        (_hasWebDavSyncEnabledDefine ? _webDavSyncEnabledByDefine : isMobile);

    final localFileImport = _capability(
      supported: supportsNativeFileSystem,
      label: '本地文件导入',
      unsupportedReason: '当前 Web 环境暂不支持系统文件导入。',
    );
    final managedFileStorage = _capability(
      supported: supportsNativeFileSystem,
      label: '受管文件存储',
      unsupportedReason: '当前 Web 环境暂不支持本地受管文件目录。',
    );
    final nativeSqlite = _capability(
      supported: supportsNativeFileSystem,
      label: '原生 SQLite',
      unsupportedReason: '当前 Web 环境使用 Web 存储，不支持原生 SQLite。',
    );
    final driftWebStorage = _capability(
      supported: kIsWeb,
      label: 'Web 数据库存储',
      unsupportedReason: '当前原生平台使用原生 SQLite，不需要 Web 数据库存储。',
    );
    final imagePicking = _capability(
      supported: !kIsWeb && (isMobile || isDesktop),
      label: '图片选择',
      unsupportedReason: '当前平台暂不支持图片选择器。',
    );
    final readerBrightnessBridge = _capability(
      supported: !kIsWeb && isMobile,
      label: '阅读器亮度桥接',
      unsupportedReason: '亮度桥接仅在 Android/iOS 原生端启用。',
    );
    final readerVolumeKeyBridge = _capability(
      supported: !kIsWeb && isMobile,
      label: '阅读器音量键桥接',
      unsupportedReason: '音量键桥接仅在 Android/iOS 原生端启用。',
    );
    final webDavSync = _runtimeCapability(
      enabled: resolvedWebDavSyncEnabled,
      supportedPlatform: supportsNativeFileSystem,
      label: 'WebDAV 同步',
      disabledReason: 'WebDAV 同步当前未启用，需要开启同步能力后使用。',
      unsupportedReason: '当前平台暂不支持 WebDAV 同步所需的本地文件能力。',
    );

    return AppPlatformCapabilities(
      platform: platform,
      isWeb: kIsWeb,
      localFileImport: localFileImport,
      managedFileStorage: managedFileStorage,
      nativeSqlite: nativeSqlite,
      driftWebStorage: driftWebStorage,
      imagePicking: imagePicking,
      readerBrightnessBridge: readerBrightnessBridge,
      readerVolumeKeyBridge: readerVolumeKeyBridge,
      webDavSync: webDavSync,
    );
  }

  final TargetPlatform platform;
  final bool isWeb;
  final AppCapabilityState localFileImport;
  final AppCapabilityState managedFileStorage;
  final AppCapabilityState nativeSqlite;
  final AppCapabilityState driftWebStorage;
  final AppCapabilityState imagePicking;
  final AppCapabilityState readerBrightnessBridge;
  final AppCapabilityState readerVolumeKeyBridge;
  final AppCapabilityState webDavSync;

  bool get supportsLocalFileImport => localFileImport.isSupported;
  bool get supportsManagedFileStorage => managedFileStorage.isSupported;
  bool get supportsNativeSqlite => nativeSqlite.isSupported;
  bool get supportsDriftWebStorage => driftWebStorage.isSupported;
  bool get supportsImagePicking => imagePicking.isSupported;
  bool get supportsReaderBrightnessBridge => readerBrightnessBridge.isSupported;
  bool get supportsReaderVolumeKeyBridge => readerVolumeKeyBridge.isSupported;
  bool get supportsWebDavSync => webDavSync.isSupported;

  bool get supportsLocalReading =>
      supportsLocalFileImport &&
      supportsManagedFileStorage &&
      (supportsNativeSqlite || supportsDriftWebStorage);
}

AppCapabilityState _capability({
  required bool supported,
  required String label,
  required String unsupportedReason,
}) {
  return supported
      ? AppCapabilityState.supported(label: label)
      : AppCapabilityState.unsupported(label: label, reason: unsupportedReason);
}

AppCapabilityState _runtimeCapability({
  required bool enabled,
  required bool supportedPlatform,
  required String label,
  required String disabledReason,
  required String unsupportedReason,
}) {
  if (enabled && supportedPlatform) {
    return AppCapabilityState.supported(label: label);
  }
  if (!enabled && supportedPlatform) {
    return AppCapabilityState.needsSetup(
      label: label,
      reason: disabledReason,
      setupActionLabel: '开启能力',
    );
  }
  return AppCapabilityState.unsupported(
    label: label,
    reason: unsupportedReason,
  );
}

const bool _webDavSyncEnabledByDefine = bool.fromEnvironment(
  'APP_ENABLE_WEBDAV_SYNC',
  defaultValue: false,
);

const bool _hasWebDavSyncEnabledDefine = bool.hasEnvironment(
  'APP_ENABLE_WEBDAV_SYNC',
);

final appPlatformCapabilitiesProvider = Provider<AppPlatformCapabilities>((
  ref,
) {
  return AppPlatformCapabilities.current();
});

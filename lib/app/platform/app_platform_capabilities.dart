import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_capability_state.dart';

enum AppPlatformBuildTarget {
  android,
  ios,
  webJs,
  webWasm,
  macos,
  windows,
  linux,
  unknown,
}

enum AppPlatformVerificationStatus {
  stable,
  firstReleaseTarget,
  experimental,
  verifiedDebugBuild,
  buildVerificationPending,
}

class AppPlatformCapabilities {
  const AppPlatformCapabilities({
    required this.platform,
    required this.isWeb,
    required this.buildTarget,
    required this.verificationStatus,
    required this.webFileUpload,
    required this.localFileImport,
    required this.managedFileStorage,
    required this.nativeSqlite,
    required this.driftWebStorage,
    required this.embeddedWebView,
    required this.imagePicking,
    required this.diagnosticLogExport,
    required this.desktopWindowControls,
    required this.audioPlayback,
    required this.readerBrightnessBridge,
    required this.readerVolumeKeyBridge,
  });

  factory AppPlatformCapabilities.current() {
    final platform = defaultTargetPlatform;
    final buildTarget = _resolveBuildTarget(platform: platform, isWeb: kIsWeb);
    final isMobile =
        platform == TargetPlatform.android || platform == TargetPlatform.iOS;
    final isDesktop =
        platform == TargetPlatform.macOS ||
        platform == TargetPlatform.windows ||
        platform == TargetPlatform.linux;
    final supportsNativeFileSystem = !kIsWeb;
    final supportsDesktopWindowControls = !kIsWeb && isDesktop;

    final webFileUpload = _capability(
      supported: kIsWeb,
      label: 'Web 文件上传',
      unsupportedReason: '当前原生平台使用系统文件选择器，不使用浏览器上传入口。',
    );
    final localFileImport = _capability(
      supported: supportsNativeFileSystem,
      label: 'Native 文件系统导入',
      unsupportedReason: '当前 Web 环境暂不支持 Native 文件系统导入，可使用 Web 上传策略。',
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
    final embeddedWebView = _capability(
      supported:
          !kIsWeb &&
          (platform == TargetPlatform.android ||
              platform == TargetPlatform.iOS ||
              platform == TargetPlatform.macOS),
      label: '内嵌 WebView',
      unsupportedReason: '当前平台不支持内嵌 WebView，需使用外部浏览器或服务器登录替代。',
    );
    final imagePicking = _capability(
      supported: !kIsWeb && (isMobile || isDesktop),
      label: '图片选择',
      unsupportedReason: '当前平台暂不支持图片选择器。',
    );
    final diagnosticLogExport = _capability(
      supported: true,
      label: '诊断日志导出',
      unsupportedReason: '当前平台暂不支持诊断日志导出。',
    );
    final desktopWindowControls = _capability(
      supported: supportsDesktopWindowControls,
      label: '桌面窗口控制',
      unsupportedReason: '移动端和 Web 不使用桌面窗口控制。',
    );
    final audioPlayback = _capability(
      supported: true,
      label: '音频播放',
      unsupportedReason: '当前平台暂不支持音频播放。',
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
    return AppPlatformCapabilities(
      platform: platform,
      isWeb: kIsWeb,
      buildTarget: buildTarget,
      verificationStatus: _resolveVerificationStatus(buildTarget),
      webFileUpload: webFileUpload,
      localFileImport: localFileImport,
      managedFileStorage: managedFileStorage,
      nativeSqlite: nativeSqlite,
      driftWebStorage: driftWebStorage,
      embeddedWebView: embeddedWebView,
      imagePicking: imagePicking,
      diagnosticLogExport: diagnosticLogExport,
      desktopWindowControls: desktopWindowControls,
      audioPlayback: audioPlayback,
      readerBrightnessBridge: readerBrightnessBridge,
      readerVolumeKeyBridge: readerVolumeKeyBridge,
    );
  }

  final TargetPlatform platform;
  final bool isWeb;
  final AppPlatformBuildTarget buildTarget;
  final AppPlatformVerificationStatus verificationStatus;
  final AppCapabilityState webFileUpload;
  final AppCapabilityState localFileImport;
  final AppCapabilityState managedFileStorage;
  final AppCapabilityState nativeSqlite;
  final AppCapabilityState driftWebStorage;
  final AppCapabilityState embeddedWebView;
  final AppCapabilityState imagePicking;
  final AppCapabilityState diagnosticLogExport;
  final AppCapabilityState desktopWindowControls;
  final AppCapabilityState audioPlayback;
  final AppCapabilityState readerBrightnessBridge;
  final AppCapabilityState readerVolumeKeyBridge;

  bool get supportsWebFileUpload => webFileUpload.isSupported;
  bool get supportsLocalFileImport => localFileImport.isSupported;
  bool get supportsManagedFileStorage => managedFileStorage.isSupported;
  bool get supportsNativeSqlite => nativeSqlite.isSupported;
  bool get supportsDriftWebStorage => driftWebStorage.isSupported;
  bool get supportsEmbeddedWebView => embeddedWebView.isSupported;
  bool get supportsImagePicking => imagePicking.isSupported;
  bool get supportsDiagnosticLogExport => diagnosticLogExport.isSupported;
  bool get supportsDesktopWindowControls => desktopWindowControls.isSupported;
  bool get supportsAudioPlayback => audioPlayback.isSupported;
  bool get supportsReaderBrightnessBridge => readerBrightnessBridge.isSupported;
  bool get supportsReaderVolumeKeyBridge => readerVolumeKeyBridge.isSupported;

  bool get isWebJsTarget => buildTarget == AppPlatformBuildTarget.webJs;
  bool get isWebWasmTarget => buildTarget == AppPlatformBuildTarget.webWasm;

  bool get supportsLocalReading =>
      supportsLocalFileImport &&
      supportsManagedFileStorage &&
      (supportsNativeSqlite || supportsDriftWebStorage);
}

AppPlatformBuildTarget _resolveBuildTarget({
  required TargetPlatform platform,
  required bool isWeb,
}) {
  if (isWeb) {
    return kIsWasm
        ? AppPlatformBuildTarget.webWasm
        : AppPlatformBuildTarget.webJs;
  }
  return switch (platform) {
    TargetPlatform.android => AppPlatformBuildTarget.android,
    TargetPlatform.iOS => AppPlatformBuildTarget.ios,
    TargetPlatform.macOS => AppPlatformBuildTarget.macos,
    TargetPlatform.windows => AppPlatformBuildTarget.windows,
    TargetPlatform.linux => AppPlatformBuildTarget.linux,
    _ => AppPlatformBuildTarget.unknown,
  };
}

AppPlatformVerificationStatus _resolveVerificationStatus(
  AppPlatformBuildTarget buildTarget,
) {
  return switch (buildTarget) {
    AppPlatformBuildTarget.android ||
    AppPlatformBuildTarget.ios => AppPlatformVerificationStatus.stable,
    AppPlatformBuildTarget.webJs =>
      AppPlatformVerificationStatus.firstReleaseTarget,
    AppPlatformBuildTarget.webWasm =>
      AppPlatformVerificationStatus.experimental,
    AppPlatformBuildTarget.macos =>
      AppPlatformVerificationStatus.verifiedDebugBuild,
    AppPlatformBuildTarget.windows || AppPlatformBuildTarget.linux =>
      AppPlatformVerificationStatus.buildVerificationPending,
    AppPlatformBuildTarget.unknown =>
      AppPlatformVerificationStatus.buildVerificationPending,
  };
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

final appPlatformCapabilitiesProvider = Provider<AppPlatformCapabilities>((
  ref,
) {
  return AppPlatformCapabilities.current();
});

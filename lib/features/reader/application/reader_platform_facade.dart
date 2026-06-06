import 'reader_runtime_wake_policy.dart';

enum ReaderBrightnessAction { restoreSystem, applyReader }

enum ReaderSystemUiChromeState { edgeToEdge, bottomOnly }

/// 阅读器平台能力门面。
///
/// 这里只放平台相关的纯决策：是否启用音量键拦截、亮度桥接应恢复还是应用、
/// 系统 UI 应显示还是沉浸。真正的 MethodChannel / SystemChrome 调用仍在
/// presentation 层执行，避免 application 层绑定具体平台 API。
class ReaderPlatformFacade {
  const ReaderPlatformFacade({
    this.wakePolicy = const ReaderRuntimeWakePolicy(),
  });

  final ReaderRuntimeWakePolicy wakePolicy;

  ReaderVolumeKeyInterceptionDecision resolveVolumeKeyInterception({
    required bool platformSupported,
    required bool enabledInSettings,
    required bool overlayVisible,
    required bool textSelectionActive,
    required bool bootstrapping,
    required bool loadingContent,
    required bool hasError,
  }) {
    if (!platformSupported) {
      return const ReaderVolumeKeyInterceptionDecision.disabled(
        'platformUnsupported',
      );
    }
    if (!enabledInSettings) {
      return const ReaderVolumeKeyInterceptionDecision.disabled(
        'settingsDisabled',
      );
    }
    if (overlayVisible) {
      return const ReaderVolumeKeyInterceptionDecision.disabled(
        'overlayVisible',
      );
    }
    if (textSelectionActive) {
      return const ReaderVolumeKeyInterceptionDecision.disabled(
        'textSelectionActive',
      );
    }
    if (bootstrapping || loadingContent || hasError) {
      return const ReaderVolumeKeyInterceptionDecision.disabled('readerBusy');
    }
    return const ReaderVolumeKeyInterceptionDecision.enabled();
  }

  ReaderBrightnessDecision resolveBrightness({
    required bool followSystemBrightness,
    required double configuredBrightness,
  }) {
    if (followSystemBrightness) {
      return const ReaderBrightnessDecision.restoreSystem();
    }
    return ReaderBrightnessDecision.applyReader(
      configuredBrightness.clamp(0.0, 1.0).toDouble(),
    );
  }

  ReaderSystemUiDecision resolveSystemUiVisibility({
    required bool overlayVisible,
    bool? forcedVisible,
  }) {
    final visible = forcedVisible ?? overlayVisible;
    return ReaderSystemUiDecision(
      visible: visible,
      chromeState:
          visible
              ? ReaderSystemUiChromeState.edgeToEdge
              : ReaderSystemUiChromeState.bottomOnly,
    );
  }

  bool shouldPollBattery({
    required bool force,
    required bool infoShowBattery,
    required DateTime? lastReadAt,
    required DateTime now,
  }) {
    return wakePolicy.shouldPollBattery(
      force: force,
      infoShowBattery: infoShowBattery,
      lastReadAt: lastReadAt,
      now: now,
    );
  }
}

class ReaderVolumeKeyInterceptionDecision {
  const ReaderVolumeKeyInterceptionDecision._({
    required this.shouldEnable,
    this.disabledReason,
  });

  const ReaderVolumeKeyInterceptionDecision.enabled()
    : this._(shouldEnable: true);

  const ReaderVolumeKeyInterceptionDecision.disabled(String reason)
    : this._(shouldEnable: false, disabledReason: reason);

  final bool shouldEnable;
  final String? disabledReason;
}

class ReaderBrightnessDecision {
  const ReaderBrightnessDecision._({required this.action, this.brightness});

  const ReaderBrightnessDecision.restoreSystem()
    : this._(action: ReaderBrightnessAction.restoreSystem);

  const ReaderBrightnessDecision.applyReader(double brightness)
    : this._(
        action: ReaderBrightnessAction.applyReader,
        brightness: brightness,
      );

  final ReaderBrightnessAction action;
  final double? brightness;
}

class ReaderSystemUiDecision {
  const ReaderSystemUiDecision({
    required this.visible,
    required this.chromeState,
  });

  final bool visible;
  final ReaderSystemUiChromeState chromeState;
}

import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_platform_facade.dart';

void main() {
  group('ReaderPlatformFacade', () {
    const facade = ReaderPlatformFacade();

    test(
      'enables volume key interception only when bridge and reader are ready',
      () {
        final decision = facade.resolveVolumeKeyInterception(
          platformSupported: true,
          enabledInSettings: true,
          overlayVisible: false,
          textSelectionActive: false,
          bootstrapping: false,
          loadingContent: false,
          hasError: false,
        );

        expect(decision.shouldEnable, isTrue);
        expect(decision.disabledReason, isNull);
      },
    );

    test(
      'disables volume key interception while overlay is visible or reader busy',
      () {
        final overlayDecision = facade.resolveVolumeKeyInterception(
          platformSupported: true,
          enabledInSettings: true,
          overlayVisible: true,
          textSelectionActive: false,
          bootstrapping: false,
          loadingContent: false,
          hasError: false,
        );
        final busyDecision = facade.resolveVolumeKeyInterception(
          platformSupported: true,
          enabledInSettings: true,
          overlayVisible: false,
          textSelectionActive: false,
          bootstrapping: false,
          loadingContent: true,
          hasError: false,
        );

        expect(overlayDecision.shouldEnable, isFalse);
        expect(overlayDecision.disabledReason, 'overlayVisible');
        expect(busyDecision.shouldEnable, isFalse);
        expect(busyDecision.disabledReason, 'readerBusy');
      },
    );

    test('resolves brightness restore or clamped reader brightness', () {
      final restore = facade.resolveBrightness(
        followSystemBrightness: true,
        configuredBrightness: 0.4,
      );
      final apply = facade.resolveBrightness(
        followSystemBrightness: false,
        configuredBrightness: 1.3,
      );

      expect(restore.action, ReaderBrightnessAction.restoreSystem);
      expect(apply.action, ReaderBrightnessAction.applyReader);
      expect(apply.brightness, 1.0);
    });

    test('maps overlay visibility to system UI chrome state', () {
      expect(
        facade.resolveSystemUiVisibility(overlayVisible: true).chromeState,
        ReaderSystemUiChromeState.edgeToEdge,
      );
      expect(
        facade.resolveSystemUiVisibility(overlayVisible: false).chromeState,
        ReaderSystemUiChromeState.bottomOnly,
      );
    });

    test('delegates battery polling cadence to runtime wake policy', () {
      final now = DateTime(2026, 6, 6, 12, 10);

      expect(
        facade.shouldPollBattery(
          force: false,
          infoShowBattery: false,
          lastReadAt: null,
          now: now,
        ),
        isFalse,
      );
      expect(
        facade.shouldPollBattery(
          force: false,
          infoShowBattery: true,
          lastReadAt: now.subtract(const Duration(minutes: 5)),
          now: now,
        ),
        isTrue,
      );
    });
  });
}

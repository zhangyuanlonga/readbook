import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_runtime_wake_policy.dart';

void main() {
  group('ReaderRuntimeWakePolicy', () {
    const policy = ReaderRuntimeWakePolicy();

    test('aligns info refresh to next minute', () {
      final now = DateTime(2026, 5, 9, 12, 34, 45, 200);

      expect(
        policy.nextMinuteDelay(now),
        const Duration(seconds: 14, milliseconds: 800),
      );
    });

    test('polls battery only when visible info needs it or forced', () {
      final now = DateTime(2026, 5, 9, 12, 10);

      expect(
        policy.shouldPollBattery(
          force: false,
          infoShowBattery: false,
          lastReadAt: null,
          now: now,
        ),
        isFalse,
      );
      expect(
        policy.shouldPollBattery(
          force: false,
          infoShowBattery: true,
          lastReadAt: now.subtract(const Duration(minutes: 4)),
          now: now,
        ),
        isFalse,
      );
      expect(
        policy.shouldPollBattery(
          force: false,
          infoShowBattery: true,
          lastReadAt: now.subtract(const Duration(minutes: 5)),
          now: now,
        ),
        isTrue,
      );
      expect(
        policy.shouldPollBattery(
          force: true,
          infoShowBattery: false,
          lastReadAt: now,
          now: now,
        ),
        isTrue,
      );
    });

    test('throttles progress saves to minute cadence', () {
      final now = DateTime(2026, 5, 9, 12);

      expect(
        policy.progressSaveDelay(lastSavedAt: null, now: now),
        Duration.zero,
      );
      expect(
        policy.progressSaveDelay(
          lastSavedAt: now.subtract(const Duration(seconds: 40)),
          now: now,
        ),
        const Duration(seconds: 20),
      );
    });

    test('pauses auto read for hidden reader, overlay, or low battery', () {
      expect(
        policy.shouldPauseAutoRead(
          isReaderVisible: false,
          showOverlayControls: false,
          isLowBattery: false,
        ),
        isTrue,
      );
      expect(
        policy.shouldPauseAutoRead(
          isReaderVisible: true,
          showOverlayControls: true,
          isLowBattery: false,
        ),
        isTrue,
      );
      expect(
        policy.shouldPauseAutoRead(
          isReaderVisible: true,
          showOverlayControls: false,
          isLowBattery: true,
        ),
        isTrue,
      );
    });
  });
}

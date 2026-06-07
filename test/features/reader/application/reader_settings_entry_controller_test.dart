import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_settings_entry_controller.dart';

void main() {
  group('ReaderSettingsEntryController', () {
    const controller = ReaderSettingsEntryController();

    test('builds open plan with overlay restore flag', () {
      final plan = controller.buildOpenPlan(overlayVisible: true);

      expect(plan.shouldStopAutoRead, isTrue);
      expect(plan.shouldSuspendOverlayAutoHide, isTrue);
      expect(plan.shouldRestoreOverlayAfterClose, isTrue);
    });

    test('does not request overlay restore when overlay was hidden', () {
      final plan = controller.buildOpenPlan(overlayVisible: false);

      expect(plan.shouldStopAutoRead, isTrue);
      expect(plan.shouldSuspendOverlayAutoHide, isTrue);
      expect(plan.shouldRestoreOverlayAfterClose, isFalse);
    });
  });
}

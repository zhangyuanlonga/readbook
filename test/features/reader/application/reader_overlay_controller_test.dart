import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_overlay_controller.dart';

void main() {
  group('ReaderOverlayController', () {
    test('resets bottom draft progress', () {
      final controller =
          ReaderOverlayController()..bottomDraftProgressRatio = 0.42;

      controller.resetBottomDraftProgress();

      expect(controller.bottomDraftProgressRatio, isNull);
    });

    test('resets delayed loading indicators together', () {
      final controller =
          ReaderOverlayController()
            ..showChapterLoadingIndicator = true
            ..showBlockingLoadingCard = true
            ..showHiddenLoadingPlaceholder = true;

      controller.resetLoadingIndicators();

      expect(controller.showChapterLoadingIndicator, isFalse);
      expect(controller.showBlockingLoadingCard, isFalse);
      expect(controller.showHiddenLoadingPlaceholder, isFalse);
    });
  });
}

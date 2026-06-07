import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_content_load_controller.dart';

void main() {
  group('ReaderContentLoadController', () {
    const controller = ReaderContentLoadController();

    test('shows blocking card and hidden placeholder for blocking load', () {
      final decision = controller.resolveDelayedUi(
        needsBlockingLoadingUi: true,
        isBootstrapping: true,
        isSwitchSourceLoading: false,
        hasVisibleReaderContent: false,
        isLoadingContent: true,
        shouldShowBlockingReaderLoading: true,
      );

      expect(decision.showBlockingLoadingCard, isTrue);
      expect(decision.showHiddenLoadingPlaceholder, isTrue);
      expect(decision.showChapterLoadingIndicator, isFalse);
    });

    test('shows chapter indicator only for visible non-blocking load', () {
      final decision = controller.resolveDelayedUi(
        needsBlockingLoadingUi: false,
        isBootstrapping: false,
        isSwitchSourceLoading: false,
        hasVisibleReaderContent: true,
        isLoadingContent: true,
        shouldShowBlockingReaderLoading: false,
      );

      expect(decision.showBlockingLoadingCard, isFalse);
      expect(decision.showHiddenLoadingPlaceholder, isFalse);
      expect(decision.showChapterLoadingIndicator, isTrue);
    });

    test('hides chapter indicator while switching source', () {
      final decision = controller.resolveDelayedUi(
        needsBlockingLoadingUi: false,
        isBootstrapping: false,
        isSwitchSourceLoading: true,
        hasVisibleReaderContent: true,
        isLoadingContent: true,
        shouldShowBlockingReaderLoading: false,
      );

      expect(decision.showChapterLoadingIndicator, isFalse);
    });
  });
}

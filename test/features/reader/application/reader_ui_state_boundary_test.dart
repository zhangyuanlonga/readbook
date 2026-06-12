import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_ui_state_boundary.dart';

void main() {
  group('ReaderSharedUiStateBoundary', () {
    const boundary = ReaderSharedUiStateBoundary();

    test(
      'blocks navigation gestures while modal reader surfaces are visible',
      () {
        final decision = boundary.resolve(
          const ReaderSharedUiStateSnapshot(
            settingsSheetVisible: true,
            catalogVisible: false,
            isBootstrapping: false,
            isLoadingContent: false,
            isSwitchSourceLoading: false,
            hasVisibleReaderContent: true,
            hasRecoverableError: false,
          ),
        );

        expect(decision.blockNavigationGestures, isTrue);
        expect(decision.suspendOverlayAutoHide, isTrue);
      },
    );

    test('blocks settings entry while switch source is running', () {
      final decision = boundary.resolve(
        const ReaderSharedUiStateSnapshot(
          settingsSheetVisible: false,
          catalogVisible: false,
          isBootstrapping: false,
          isLoadingContent: false,
          isSwitchSourceLoading: true,
          hasVisibleReaderContent: true,
          hasRecoverableError: false,
        ),
      );

      expect(decision.blockSettingsEntry, isTrue);
      expect(decision.blockNavigationGestures, isTrue);
      expect(decision.showTransientLoading, isFalse);
    });

    test('shows transient loading only over existing visible content', () {
      final decision = boundary.resolve(
        const ReaderSharedUiStateSnapshot(
          settingsSheetVisible: false,
          catalogVisible: false,
          isBootstrapping: false,
          isLoadingContent: true,
          isSwitchSourceLoading: false,
          hasVisibleReaderContent: true,
          hasRecoverableError: false,
        ),
      );

      expect(decision.showTransientLoading, isTrue);
      expect(decision.suspendOverlayAutoHide, isTrue);
    });

    test(
      'shows recoverable error when reader is not bootstrapping or switching source',
      () {
        final decision = boundary.resolve(
          const ReaderSharedUiStateSnapshot(
            settingsSheetVisible: false,
            catalogVisible: false,
            isBootstrapping: false,
            isLoadingContent: false,
            isSwitchSourceLoading: false,
            hasVisibleReaderContent: false,
            hasRecoverableError: true,
          ),
        );

        expect(decision.showErrorRecovery, isTrue);
      },
    );
  });
}

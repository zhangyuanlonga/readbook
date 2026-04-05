import 'package:shuxiang_reading_next/domain/entities/reader_settings.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_auto_read_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReaderAutoReadCoordinator', () {
    const coordinator = ReaderAutoReadCoordinator();

    test('canRunNow requires valid runtime conditions', () {
      final runnable = coordinator.canRunNow(
        isAutoReadSessionEnabled: true,
        isMangaChapter: false,
        isPagedTextReaderEnabled: false,
        showOverlayControls: false,
        isBootstrapping: false,
        isLoadingContent: false,
        hasError: false,
        hasTextContent: true,
        hasScrollClients: true,
        maxScrollExtent: 500,
        scrollOffset: 240,
      );
      final blockedByOverlay = coordinator.canRunNow(
        isAutoReadSessionEnabled: true,
        isMangaChapter: false,
        isPagedTextReaderEnabled: false,
        showOverlayControls: true,
        isBootstrapping: false,
        isLoadingContent: false,
        hasError: false,
        hasTextContent: true,
        hasScrollClients: true,
        maxScrollExtent: 500,
        scrollOffset: 240,
      );

      expect(runnable, isTrue);
      expect(blockedByOverlay, isFalse);
    });

    test('isAtChapterEnd uses edge tolerance', () {
      expect(
        coordinator.isAtChapterEnd(
          hasScrollClients: true,
          maxScrollExtent: 1000,
          scrollOffset: 999.4,
        ),
        isTrue,
      );
      expect(
        coordinator.isAtChapterEnd(
          hasScrollClients: true,
          maxScrollExtent: 1000,
          scrollOffset: 996,
        ),
        isFalse,
      );
    });

    test('resolveStepTargetOffset clamps speed and max extent', () {
      final lowSpeedTarget = coordinator.resolveStepTargetOffset(
        currentOffset: 100,
        maxScrollExtent: 220,
        autoReadSpeed: ReaderSettings.minAutoReadSpeed - 20,
        stepDuration: const Duration(milliseconds: 200),
      );
      final highSpeedTarget = coordinator.resolveStepTargetOffset(
        currentOffset: 210,
        maxScrollExtent: 220,
        autoReadSpeed: ReaderSettings.maxAutoReadSpeed + 200,
        stepDuration: const Duration(milliseconds: 500),
      );

      expect(lowSpeedTarget, greaterThan(100));
      expect(highSpeedTarget, 220);
    });

    test('shouldTryAdvanceChapter mirrors advance guard conditions', () {
      final shouldAdvance = coordinator.shouldTryAdvanceChapter(
        isAutoReadSessionEnabled: true,
        isAutoReadAdvancingChapter: false,
        isMangaChapter: false,
        isPagedTextReaderEnabled: false,
        showOverlayControls: false,
        isBootstrapping: false,
        isLoadingContent: false,
        hasError: false,
        isAtChapterEnd: true,
      );
      final blocked = coordinator.shouldTryAdvanceChapter(
        isAutoReadSessionEnabled: true,
        isAutoReadAdvancingChapter: false,
        isMangaChapter: false,
        isPagedTextReaderEnabled: true,
        showOverlayControls: false,
        isBootstrapping: false,
        isLoadingContent: false,
        hasError: false,
        isAtChapterEnd: true,
      );

      expect(shouldAdvance, isTrue);
      expect(blocked, isFalse);
    });
  });
}

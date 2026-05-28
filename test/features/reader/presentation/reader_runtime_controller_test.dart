import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_reading_record_coordinator.dart';
import 'package:shuxiang_reading_next/features/reader/presentation/reader_runtime_controller.dart';

void main() {
  group('ReaderRuntimeController', () {
    const controller = ReaderRuntimeController();

    test('computes manga paged ratio from page index', () {
      final ratio = controller.currentScrollRatio(
        viewportKind: ReaderRuntimeViewportKind.mangaPaged,
        captureTextProgress: () => 0.1,
        mangaPageIndex: 3,
        mangaPageCount: 5,
        continuousChapterRatio: null,
        useContinuousTextFlow: false,
      );

      expect(ratio, 0.75);
    });

    test('prefers continuous chapter ratio for scroll viewport', () {
      final ratio = controller.currentScrollRatio(
        viewportKind: ReaderRuntimeViewportKind.textScroll,
        captureTextProgress: () => 0.1,
        mangaPageIndex: 0,
        mangaPageCount: 0,
        continuousChapterRatio: () => 0.6,
        useContinuousTextFlow: true,
      );

      expect(ratio, 0.6);
    });

    test('computes audio ratio from playback position and duration', () {
      final ratio = controller.currentScrollRatio(
        viewportKind: ReaderRuntimeViewportKind.audio,
        captureTextProgress: () => 0.1,
        mangaPageIndex: 0,
        mangaPageCount: 0,
        continuousChapterRatio: null,
        useContinuousTextFlow: false,
      );

      expect(ratio, 0.1);
    });

    test('falls back to zero audio ratio when duration is unavailable', () {
      final ratio = controller.currentScrollRatio(
        viewportKind: ReaderRuntimeViewportKind.audio,
        captureTextProgress: () => 0,
        mangaPageIndex: 0,
        mangaPageCount: 0,
        continuousChapterRatio: null,
        useContinuousTextFlow: false,
      );

      expect(ratio, 0);
    });

    test('resolves bottom drag end as next chapter only', () {
      final bottomAction = controller.resolveScrollEdgeDragEndAction(
        isArmed: false,
        armedActionDirection: 0,
        atTop: false,
        atBottom: true,
        isDragEnd: true,
        velocityDy: -120,
      );
      final topAction = controller.resolveScrollEdgeDragEndAction(
        isArmed: false,
        armedActionDirection: 0,
        atTop: true,
        atBottom: false,
        isDragEnd: true,
        velocityDy: 120,
      );

      expect(bottomAction, ReaderScrollEdgeAction.nextChapter);
      expect(topAction, ReaderScrollEdgeAction.refreshCurrent);
    });

    test('ignores mismatched armed scroll edge direction', () {
      final action = controller.resolveScrollEdgeDragEndAction(
        isArmed: true,
        armedActionDirection: -2,
        atTop: false,
        atBottom: true,
        isDragEnd: true,
        velocityDy: -120,
      );

      expect(action, ReaderScrollEdgeAction.none);
    });

    test('starts reading record session through coordinator', () {
      final result = controller.startOrUpdateReadingRecordSession(
        coordinator: const ReaderReadingRecordCoordinator(),
        readingRecordEnabled: true,
        isBootstrapping: false,
        isLoadingContent: false,
        hasError: false,
        hasVisibleReaderContent: true,
        sourceId: 'source-a',
        detailUrl: 'detail://a',
        bookTitle: '示例书',
        currentBookId: 'book-a',
        chapterId: 'chapter-1',
        chapterUrl: 'chapter://1',
        chapterTitle: '第一章',
        chapterIndex: 0,
        bookAuthor: '作者',
        coverUrl: 'cover://a',
        initialRatio: 0.35,
        now: DateTime(2026, 4, 26, 12),
        existingSession: null,
      );

      expect(result.session, isNotNull);
      expect(result.session?.furthestPositionRatio, 0.35);
      expect(result.scheduleAutoCommitTimer, isTrue);
    });
  });
}

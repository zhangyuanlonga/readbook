import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/reader/presentation/reader_page_turn_runtime_controller.dart';

void main() {
  group('ReaderPageTurnRuntimeController', () {
    test('tracks first page turn only once', () async {
      final controller = ReaderPageTurnRuntimeController();

      controller.markFirstPageTurnRequested();
      await Future<void>.delayed(const Duration(milliseconds: 1));

      final firstStopwatch = controller.completeFirstPageTurn();
      final secondStopwatch = controller.completeFirstPageTurn();

      expect(firstStopwatch, isNotNull);
      expect(firstStopwatch!.elapsedMilliseconds, greaterThanOrEqualTo(0));
      expect(secondStopwatch, isNull);
      expect(controller.hasLoggedFirstPageTurn, isTrue);
      expect(controller.firstPageTurnStopwatch, isNull);
    });

    test('centralizes curl preview and commit state', () {
      final controller =
          ReaderPageTurnRuntimeController()..currentPageIndex = 2;

      controller.beginCurlPreview(
        direction: 1,
        fromIndex: 2,
        toIndex: 3,
        progress: 0.35,
      );

      expect(controller.curlTransition.isPreview, isTrue);
      expect(controller.curlTransition.previewProgress, 0.35);
      expect(controller.curlTransition.toIndex, 3);

      controller.finishCurlPreview(commit: true);
      expect(controller.curlTransition.isAnimating, isTrue);
      expect(controller.curlTransition.commitOnAnimationEnd, isTrue);

      controller.commitCurlTurn(pageIndex: 3);
      expect(controller.currentPageIndex, 3);
      expect(controller.curlTransition.isAnimating, isFalse);
      expect(controller.curlTransition.fromIndex, 3);
      expect(controller.curlTransition.toIndex, 3);
    });

    test('tracks cross chapter snapshot generation', () {
      final controller = ReaderPageTurnRuntimeController();

      final firstGeneration = controller.nextCrossChapterSnapshotGeneration();
      final secondGeneration = controller.nextCrossChapterSnapshotGeneration();

      expect(firstGeneration, 1);
      expect(secondGeneration, 2);
      expect(
        controller.isCrossChapterSnapshotGenerationActive(firstGeneration),
        isFalse,
      );
      expect(
        controller.isCrossChapterSnapshotGenerationActive(secondGeneration),
        isTrue,
      );
    });

    test('commits paper curl page with restore ratio', () {
      final controller = ReaderPageTurnRuntimeController();

      controller.commitPaperCurlTurn(pageIndex: 2, pageCount: 5);

      expect(controller.currentPageIndex, 2);
      expect(controller.pagedPaginationState.pendingRestoreRatio, 0.5);
    });

    test('commits generic paged position with clamped restore ratio', () {
      final controller = ReaderPageTurnRuntimeController();

      controller.commitPagedPosition(pageIndex: 9, pageCount: 5);

      expect(controller.currentPageIndex, 4);
      expect(controller.pagedPaginationState.pendingRestoreRatio, 1);
    });

    test('commits forward cross chapter page at chapter start', () {
      final controller =
          ReaderPageTurnRuntimeController()..currentPageIndex = 8;

      controller.commitCrossChapterPagedTurn(direction: 1, pageCount: 6);

      expect(controller.currentPageIndex, 0);
      expect(controller.pagedPaginationState.pendingRestoreRatio, 0);
      expect(controller.pagedTransition.isAnimating, isFalse);
      expect(controller.curlTransition.isAnimating, isFalse);
    });

    test('commits backward cross chapter page at chapter end', () {
      final controller = ReaderPageTurnRuntimeController();

      controller.commitCrossChapterPagedTurn(direction: -1, pageCount: 6);

      expect(controller.currentPageIndex, 5);
      expect(controller.pagedPaginationState.pendingRestoreRatio, 1);
    });
  });
}

import 'dart:math';
import 'dart:ui' as ui;

import '../../../domain/entities/reader_settings.dart';
import '../application/paged_transition_controller.dart';
import '../application/reader_pagination_engine.dart';
import 'reader_page_support_models.dart';

class ReaderPageTurnRuntimeController {
  int currentPageIndex = 0;
  int pagedTextControllerSyncGeneration = 0;
  ReaderPaginationSessionState pagedPaginationState =
      const ReaderPaginationSessionState();

  PagedTransitionState pagedTransition = PagedTransitionController.idleState;
  ReaderCurlTransitionState curlTransition = const ReaderCurlTransitionState();
  ReaderCrossChapterSnapshotTransitionState crossChapterSnapshotTransition =
      const ReaderCrossChapterSnapshotTransitionState();
  int crossChapterSnapshotGeneration = 0;

  Stopwatch? firstPageTurnStopwatch;
  bool hasLoggedFirstPageTurn = false;

  int nextCrossChapterSnapshotGeneration() {
    crossChapterSnapshotGeneration += 1;
    return crossChapterSnapshotGeneration;
  }

  bool isCrossChapterSnapshotGenerationActive(int generation) {
    return generation == crossChapterSnapshotGeneration;
  }

  void beginPagedTransition(PagedTransitionState transition) {
    pagedTransition = transition;
  }

  void resetPagedTransition() {
    pagedTransition = PagedTransitionController.idleState;
  }

  void updateCurlTransition(
    ReaderCurlTransitionState Function(ReaderCurlTransitionState current)
    update,
  ) {
    curlTransition = update(curlTransition);
  }

  void beginCurlPreview({
    required int direction,
    required int fromIndex,
    required int toIndex,
    required double progress,
  }) {
    curlTransition = curlTransition.copyWith(
      direction: direction,
      fromIndex: fromIndex,
      toIndex: toIndex,
      previewProgress: progress,
      isPreview: true,
    );
  }

  void cancelCurlPreview({required int currentIndex}) {
    curlTransition = curlTransition.copyWith(
      isAnimating: false,
      isPreview: false,
      previewProgress: 0,
      fromIndex: currentIndex,
      toIndex: currentIndex,
    );
  }

  void finishCurlPreview({required bool commit}) {
    curlTransition = curlTransition.copyWith(
      commitOnAnimationEnd: commit,
      isPreview: false,
      isAnimating: true,
    );
  }

  void beginCurlAutoTurn({
    required int direction,
    required int fromIndex,
    required int toIndex,
    bool isCrossChapter = false,
  }) {
    curlTransition = curlTransition.copyWith(
      direction: direction,
      fromIndex: fromIndex,
      toIndex: toIndex,
      commitOnAnimationEnd: true,
      isPreview: false,
      previewProgress: 0,
      isAnimating: true,
      isCrossChapter: isCrossChapter,
    );
  }

  void commitCurlTurn({required int pageIndex}) {
    currentPageIndex = pageIndex;
    curlTransition = curlTransition.copyWith(
      isAnimating: false,
      isPreview: false,
      previewProgress: 0,
      fromIndex: pageIndex,
      toIndex: pageIndex,
      isCrossChapter: false,
    );
  }

  void commitPaperCurlTurn({required int pageIndex, required int pageCount}) {
    currentPageIndex = pageIndex;
    pagedPaginationState = pagedPaginationState.copyWith(
      pendingRestoreRatio: pageIndex / max(1, pageCount - 1),
    );
  }

  void resetCurlTransition({int pageIndex = 0}) {
    currentPageIndex = pageIndex;
    curlTransition = const ReaderCurlTransitionState();
  }

  ReaderCrossChapterSnapshotTransitionState
  buildCrossChapterSnapshotTransition({
    required int generation,
    required ui.Image fromImage,
    required ReaderPageAnimationStyle style,
    required int direction,
    required String completionMode,
  }) {
    return ReaderCrossChapterSnapshotTransitionState(
      fromImage: fromImage,
      style: style,
      direction: direction,
      generation: generation,
      completionMode: completionMode,
    );
  }

  bool attachCrossChapterSnapshotTarget({
    required int generation,
    required ui.Image toImage,
  }) {
    final current = crossChapterSnapshotTransition;
    if (!current.isActive || current.generation != generation) {
      return false;
    }
    crossChapterSnapshotTransition = current.copyWith(toImage: toImage);
    return true;
  }

  ReaderCrossChapterSnapshotTransitionState
  replaceCrossChapterSnapshotTransition(
    ReaderCrossChapterSnapshotTransitionState next,
  ) {
    final previous = crossChapterSnapshotTransition;
    crossChapterSnapshotTransition = next;
    return previous;
  }

  ReaderCrossChapterSnapshotTransitionState
  clearCrossChapterSnapshotTransition() {
    final previous = crossChapterSnapshotTransition;
    crossChapterSnapshotTransition =
        const ReaderCrossChapterSnapshotTransitionState();
    return previous;
  }

  void resetTransitions() {
    pagedTransition = PagedTransitionController.idleState;
    curlTransition = const ReaderCurlTransitionState();
    crossChapterSnapshotTransition =
        const ReaderCrossChapterSnapshotTransitionState();
  }

  void markFirstPageTurnRequested() {
    if (hasLoggedFirstPageTurn || firstPageTurnStopwatch != null) {
      return;
    }
    firstPageTurnStopwatch = Stopwatch()..start();
  }

  Stopwatch? completeFirstPageTurn() {
    final stopwatch = firstPageTurnStopwatch;
    if (hasLoggedFirstPageTurn || stopwatch == null) {
      return null;
    }
    hasLoggedFirstPageTurn = true;
    firstPageTurnStopwatch = null;
    return stopwatch;
  }

  void resetFirstPageTurnTracking() {
    firstPageTurnStopwatch = null;
    hasLoggedFirstPageTurn = false;
  }
}

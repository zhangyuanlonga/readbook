import 'dart:async';

import 'package:flutter/widgets.dart';

import '../application/reader_viewport_state.dart';
import '../application/reader_auto_read_coordinator.dart';
import '../application/reader_reading_record_coordinator.dart';

enum ReaderRuntimeViewportKind {
  textPaged,
  textScroll,
  mangaPaged,
  mangaContinuous,
  hybridPaged,
  audio,
}

enum ReaderScrollEdgeAction { none, refreshCurrent, nextChapter }

class ReaderRuntimeController {
  const ReaderRuntimeController();

  double currentScrollRatio({
    required ReaderRuntimeViewportKind viewportKind,
    required double Function() captureTextProgress,
    required int mangaPageIndex,
    required int mangaPageCount,
    required double Function()? continuousChapterRatio,
    required bool useContinuousTextFlow,
  }) {
    switch (viewportKind) {
      case ReaderRuntimeViewportKind.textPaged:
        return captureTextProgress();
      case ReaderRuntimeViewportKind.mangaPaged:
      case ReaderRuntimeViewportKind.hybridPaged:
        if (mangaPageCount <= 1) {
          return 0;
        }
        return (mangaPageIndex / (mangaPageCount - 1)).clamp(0.0, 1.0);
      case ReaderRuntimeViewportKind.textScroll:
      case ReaderRuntimeViewportKind.mangaContinuous:
      case ReaderRuntimeViewportKind.audio:
        if (useContinuousTextFlow && continuousChapterRatio != null) {
          return continuousChapterRatio();
        }
        return captureTextProgress();
    }
  }

  ReaderRuntimeViewportKind runtimeKindFromViewportState(
    ReaderViewportState state,
  ) {
    switch (state.kind) {
      case ReaderViewportStateKind.textPaged:
        return ReaderRuntimeViewportKind.textPaged;
      case ReaderViewportStateKind.textScroll:
        return ReaderRuntimeViewportKind.textScroll;
      case ReaderViewportStateKind.mangaPaged:
        return ReaderRuntimeViewportKind.mangaPaged;
      case ReaderViewportStateKind.mangaContinuous:
        return ReaderRuntimeViewportKind.mangaContinuous;
      case ReaderViewportStateKind.hybridPaged:
        return ReaderRuntimeViewportKind.hybridPaged;
      case ReaderViewportStateKind.audio:
        return ReaderRuntimeViewportKind.audio;
    }
  }

  Timer scheduleProgressSave({
    required Duration debounce,
    required Future<void> Function() onSave,
  }) {
    return Timer(debounce, () {
      unawaited(onSave());
    });
  }

  ReaderReadingRecordSessionStartResult startOrUpdateReadingRecordSession({
    required ReaderReadingRecordCoordinator coordinator,
    required bool readingRecordEnabled,
    required bool isBootstrapping,
    required bool isLoadingContent,
    required bool hasError,
    required bool hasVisibleReaderContent,
    required String? sourceId,
    required String? detailUrl,
    required String bookTitle,
    required String currentBookId,
    required String chapterId,
    required String? chapterUrl,
    required String? chapterTitle,
    required int? chapterIndex,
    required String? bookAuthor,
    required String? coverUrl,
    required double initialRatio,
    required DateTime now,
    required ReaderReadingRecordSession? existingSession,
  }) {
    return coordinator.startOrUpdateSession(
      readingRecordEnabled: readingRecordEnabled,
      isBootstrapping: isBootstrapping,
      isLoadingContent: isLoadingContent,
      hasError: hasError,
      hasVisibleReaderContent: hasVisibleReaderContent,
      sourceId: sourceId,
      detailUrl: detailUrl,
      bookTitle: bookTitle,
      currentBookId: currentBookId,
      chapterId: chapterId,
      chapterUrl: chapterUrl,
      chapterTitle: chapterTitle,
      chapterIndex: chapterIndex,
      bookAuthor: bookAuthor,
      coverUrl: coverUrl,
      initialRatio: initialRatio,
      now: now,
      existingSession: existingSession,
    );
  }

  ReaderReadingRecordSession? syncReadingRecordSessionProgress({
    required ReaderReadingRecordCoordinator coordinator,
    required ReaderReadingRecordSession? session,
    required double ratio,
  }) {
    if (session == null) {
      return null;
    }
    return coordinator.syncProgress(session: session, ratio: ratio);
  }

  Timer? buildReadingRecordAutoCommitTimer({
    required Duration interval,
    required ReaderReadingRecordSession? session,
    required VoidCallback onAutoCommit,
  }) {
    if (session == null) {
      return null;
    }
    return Timer(interval, onAutoCommit);
  }

  ReaderScrollEdgeAction resolveScrollEdgeDragEndAction({
    required bool isArmed,
    required int armedActionDirection,
    required bool atTop,
    required bool atBottom,
    required bool isDragEnd,
    required double velocityDy,
    double velocityThreshold = 36,
  }) {
    if (isArmed) {
      if (armedActionDirection > 0 && atBottom) {
        return ReaderScrollEdgeAction.nextChapter;
      }
      if (armedActionDirection < 0 && atTop) {
        return ReaderScrollEdgeAction.refreshCurrent;
      }
      return ReaderScrollEdgeAction.none;
    }

    if (!isDragEnd) {
      return ReaderScrollEdgeAction.none;
    }

    if (atBottom && velocityDy <= velocityThreshold) {
      return ReaderScrollEdgeAction.nextChapter;
    }
    if (atTop && velocityDy >= -velocityThreshold) {
      return ReaderScrollEdgeAction.refreshCurrent;
    }
    return ReaderScrollEdgeAction.none;
  }

  Future<void> reconcileAutoRead({
    required bool mounted,
    required bool restart,
    required VoidCallback stopAutoRead,
    required bool isAutoReadSessionEnabled,
    required void Function(void Function()) postFrame,
    required bool Function() canRunAutoReadNow,
    required VoidCallback startAutoReadIfNeeded,
    required Future<void> Function() tryAutoReadAdvanceChapter,
  }) async {
    if (!mounted) {
      return;
    }
    if (restart) {
      stopAutoRead();
    }
    if (!isAutoReadSessionEnabled) {
      stopAutoRead();
      return;
    }
    postFrame(() {
      if (!mounted) {
        return;
      }
      if (canRunAutoReadNow()) {
        startAutoReadIfNeeded();
      } else {
        stopAutoRead();
        unawaited(tryAutoReadAdvanceChapter());
      }
    });
  }

  Future<void> runAutoReadLoop({
    required int token,
    required int Function() currentToken,
    required bool Function() isMounted,
    required bool Function() canRunAutoReadNow,
    required ScrollController scrollController,
    required ReaderAutoReadCoordinator coordinator,
    required double autoReadSpeed,
    required Duration stepDuration,
    required VoidCallback onLoopFinished,
    required Future<void> Function() tryAdvanceChapter,
  }) async {
    while (isMounted() && token == currentToken()) {
      if (!canRunAutoReadNow()) {
        break;
      }

      final position = scrollController.position;
      final target = coordinator.resolveStepTargetOffset(
        currentOffset: position.pixels,
        maxScrollExtent: position.maxScrollExtent,
        autoReadSpeed: autoReadSpeed,
        stepDuration: stepDuration,
      );

      if ((target - position.pixels).abs() < 0.5) {
        break;
      }

      try {
        await scrollController.animateTo(
          target,
          duration: stepDuration,
          curve: Curves.linear,
        );
      } catch (_) {
        break;
      }
    }

    if (token == currentToken()) {
      onLoopFinished();
      await tryAdvanceChapter();
    }
  }
}

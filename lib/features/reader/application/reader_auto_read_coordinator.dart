import 'dart:math';

import '../../../domain/entities/reader_settings.dart';

class ReaderAutoReadCoordinator {
  const ReaderAutoReadCoordinator();

  bool canRunNow({
    required bool isAutoReadSessionEnabled,
    required bool isMangaChapter,
    required bool isPagedTextReaderEnabled,
    required bool showOverlayControls,
    required bool isBootstrapping,
    required bool isLoadingContent,
    required bool hasError,
    required bool hasTextContent,
    required bool hasScrollClients,
    required double maxScrollExtent,
    required double scrollOffset,
    double edgeTolerance = 0.8,
  }) {
    if (!isAutoReadSessionEnabled ||
        isMangaChapter ||
        isPagedTextReaderEnabled ||
        showOverlayControls ||
        isBootstrapping ||
        isLoadingContent ||
        hasError ||
        !hasTextContent) {
      return false;
    }
    if (!hasScrollClients || maxScrollExtent <= 0) {
      return false;
    }
    return scrollOffset < maxScrollExtent - edgeTolerance;
  }

  bool isAtChapterEnd({
    required bool hasScrollClients,
    required double maxScrollExtent,
    required double scrollOffset,
    double edgeTolerance = 0.8,
  }) {
    if (!hasScrollClients) {
      return false;
    }
    if (maxScrollExtent <= edgeTolerance) {
      return true;
    }
    return scrollOffset >= maxScrollExtent - edgeTolerance;
  }

  bool shouldTryAdvanceChapter({
    required bool isAutoReadSessionEnabled,
    required bool isAutoReadAdvancingChapter,
    required bool isMangaChapter,
    required bool isPagedTextReaderEnabled,
    required bool showOverlayControls,
    required bool isBootstrapping,
    required bool isLoadingContent,
    required bool hasError,
    required bool isAtChapterEnd,
  }) {
    return isAutoReadSessionEnabled &&
        !isAutoReadAdvancingChapter &&
        !isMangaChapter &&
        !isPagedTextReaderEnabled &&
        !showOverlayControls &&
        !isBootstrapping &&
        !isLoadingContent &&
        !hasError &&
        isAtChapterEnd;
  }

  double resolveStepTargetOffset({
    required double currentOffset,
    required double maxScrollExtent,
    required double autoReadSpeed,
    required Duration stepDuration,
  }) {
    final speed =
        autoReadSpeed
            .clamp(
              ReaderSettings.minAutoReadSpeed,
              ReaderSettings.maxAutoReadSpeed,
            )
            .toDouble();
    final distance = speed * (stepDuration.inMilliseconds / 1000.0);
    return min(currentOffset + distance, maxScrollExtent);
  }
}

import 'dart:math';

import '../../../domain/entities/reader_settings.dart';

class ReaderAutoReadCoordinator {
  const ReaderAutoReadCoordinator();

  bool canRunNow({
    required bool isAutoReadSessionEnabled,
    required bool isMangaChapter,
    required bool isPagedTextReaderEnabled,
    required bool isReaderVisible,
    required bool isLowBattery,
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
        !isReaderVisible ||
        isLowBattery ||
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

  bool canRunPagedNow({
    required bool isAutoReadSessionEnabled,
    required bool isMangaChapter,
    required bool isPagedTextReaderEnabled,
    required bool isReaderVisible,
    required bool isLowBattery,
    required bool showOverlayControls,
    required bool isBootstrapping,
    required bool isLoadingContent,
    required bool hasError,
    required bool hasTextContent,
    required bool isPaginating,
    required bool isAnimating,
    required int pageCount,
  }) {
    return isAutoReadSessionEnabled &&
        !isMangaChapter &&
        isPagedTextReaderEnabled &&
        isReaderVisible &&
        !isLowBattery &&
        !showOverlayControls &&
        !isBootstrapping &&
        !isLoadingContent &&
        !hasError &&
        hasTextContent &&
        !isPaginating &&
        !isAnimating &&
        pageCount > 0;
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
    required bool isReaderVisible,
    required bool isLowBattery,
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
        isReaderVisible &&
        !isLowBattery &&
        !showOverlayControls &&
        !isBootstrapping &&
        !isLoadingContent &&
        !hasError &&
        isAtChapterEnd;
  }

  Duration resolvePagedHoldDuration({required int speedLevel}) {
    final level =
        speedLevel
            .clamp(
              ReaderSettings.minAutoReadSpeedLevel,
              ReaderSettings.maxAutoReadSpeedLevel,
            )
            .toInt();
    final normalized =
        (level - ReaderSettings.minAutoReadSpeedLevel) /
        (ReaderSettings.maxAutoReadSpeedLevel -
            ReaderSettings.minAutoReadSpeedLevel);
    final seconds = 12.0 - normalized * 8.0;
    return Duration(milliseconds: (seconds * 1000).round());
  }

  Duration paragraphPauseDuration({required int speedLevel}) {
    final level =
        speedLevel
            .clamp(
              ReaderSettings.minAutoReadSpeedLevel,
              ReaderSettings.maxAutoReadSpeedLevel,
            )
            .toInt();
    final normalized =
        (level - ReaderSettings.minAutoReadSpeedLevel) /
        (ReaderSettings.maxAutoReadSpeedLevel -
            ReaderSettings.minAutoReadSpeedLevel);
    final milliseconds = 1400.0 - normalized * 700.0;
    return Duration(milliseconds: milliseconds.round());
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

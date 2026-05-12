import 'package:flutter/services.dart';

enum ReaderDesktopInputAction {
  none,
  toggleOverlay,
  previousPage,
  nextPage,
  chapterStart,
  chapterEnd,
}

class ReaderDesktopInputResolver {
  const ReaderDesktopInputResolver();

  ReaderDesktopInputAction resolveKeyAction(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.escape) {
      return ReaderDesktopInputAction.toggleOverlay;
    }
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.pageUp) {
      return ReaderDesktopInputAction.previousPage;
    }
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.pageDown) {
      return ReaderDesktopInputAction.nextPage;
    }
    if (key == LogicalKeyboardKey.home) {
      return ReaderDesktopInputAction.chapterStart;
    }
    if (key == LogicalKeyboardKey.end) {
      return ReaderDesktopInputAction.chapterEnd;
    }
    return ReaderDesktopInputAction.none;
  }

  ReaderDesktopInputAction resolvePointerScrollAction({
    required double deltaY,
    required bool isPagedViewport,
    required bool overlayVisible,
    required bool textSelectionActive,
    DateTime? lastPageTurnAt,
    required DateTime now,
    double threshold = 8,
    Duration throttle = const Duration(milliseconds: 180),
  }) {
    if (!isPagedViewport || overlayVisible || textSelectionActive) {
      return ReaderDesktopInputAction.none;
    }
    if (deltaY.abs() < threshold) {
      return ReaderDesktopInputAction.none;
    }
    if (lastPageTurnAt != null && now.difference(lastPageTurnAt) < throttle) {
      return ReaderDesktopInputAction.none;
    }
    return deltaY > 0
        ? ReaderDesktopInputAction.nextPage
        : ReaderDesktopInputAction.previousPage;
  }
}

import '../../../domain/entities/reader_settings.dart';

enum ReaderContentKind { text, image, document, audio }

enum ReaderLayoutMode { paged, scroll }

enum ReaderModeViewportKind {
  textPaged,
  textScroll,
  imagePaged,
  imageScroll,
  hybridPaged,
}

extension ReaderPageTurnModeX on ReaderPageTurnMode {
  bool get tapEnabled {
    return this == ReaderPageTurnMode.tap ||
        this == ReaderPageTurnMode.tapAndSwipe ||
        this == ReaderPageTurnMode.tapAndScroll;
  }

  bool get swipeEnabled {
    return this == ReaderPageTurnMode.swipe ||
        this == ReaderPageTurnMode.tapAndSwipe;
  }

  bool get usesScrollLayout {
    return this == ReaderPageTurnMode.scroll ||
        this == ReaderPageTurnMode.tapAndScroll;
  }
}

ReaderPageTurnMode composeReaderPageTurnMode({
  required bool tapEnabled,
  required bool swipeEnabled,
  required bool scrollEnabled,
}) {
  if (scrollEnabled) {
    return tapEnabled
        ? ReaderPageTurnMode.tapAndScroll
        : ReaderPageTurnMode.scroll;
  }
  if (swipeEnabled) {
    return tapEnabled
        ? ReaderPageTurnMode.tapAndSwipe
        : ReaderPageTurnMode.swipe;
  }
  return ReaderPageTurnMode.tap;
}

ReaderPageTurnMode applyReaderPageTurnModeToggle(
  ReaderPageTurnMode current, {
  bool? tapEnabled,
  bool? swipeEnabled,
  bool? scrollEnabled,
}) {
  var nextTapEnabled = current.tapEnabled;
  var nextSwipeEnabled = current.swipeEnabled;
  var nextScrollEnabled = current.usesScrollLayout;

  if (tapEnabled != null) {
    nextTapEnabled = tapEnabled;
  }
  if (swipeEnabled != null) {
    nextSwipeEnabled = swipeEnabled;
    if (nextSwipeEnabled) {
      nextScrollEnabled = false;
    }
  }
  if (scrollEnabled != null) {
    nextScrollEnabled = scrollEnabled;
    if (nextScrollEnabled) {
      nextSwipeEnabled = false;
    }
  }

  if (nextSwipeEnabled && nextScrollEnabled) {
    nextScrollEnabled = false;
  }
  if (!nextTapEnabled && !nextSwipeEnabled && !nextScrollEnabled) {
    nextTapEnabled = true;
  }

  return composeReaderPageTurnMode(
    tapEnabled: nextTapEnabled,
    swipeEnabled: nextSwipeEnabled,
    scrollEnabled: nextScrollEnabled,
  );
}

class ReaderModeModel {
  const ReaderModeModel({
    required this.contentKind,
    required this.layoutMode,
    required this.viewportKind,
    required this.supportsTextSelection,
    required this.supportsZoomGesture,
    required this.supportsAutoRead,
    required this.sourcePageTurnMode,
    required this.tapTurnEnabled,
    required this.swipeTurnEnabled,
    required this.pageAnimationStyle,
  });

  final ReaderContentKind contentKind;
  final ReaderLayoutMode layoutMode;
  final ReaderModeViewportKind viewportKind;
  final bool supportsTextSelection;
  final bool supportsZoomGesture;
  final bool supportsAutoRead;
  final ReaderPageTurnMode sourcePageTurnMode;
  final bool tapTurnEnabled;
  final bool swipeTurnEnabled;
  final ReaderPageAnimationStyle? pageAnimationStyle;

  bool get isText => contentKind == ReaderContentKind.text;
  bool get isImage => contentKind == ReaderContentKind.image;
  bool get isDocument => contentKind == ReaderContentKind.document;
  bool get isAudio => contentKind == ReaderContentKind.audio;
  bool get isPaged => layoutMode == ReaderLayoutMode.paged;
  bool get isScroll => layoutMode == ReaderLayoutMode.scroll;
}

import 'reader_content_session.dart';
import 'reader_mode_model.dart';
import 'reader_viewport_state.dart';

class ReaderViewportStateResolver {
  const ReaderViewportStateResolver();

  ReaderViewportState resolve({
    required ReaderContentMode contentMode,
    required ReaderModeModel mode,
    required double chapterPositionRatio,
    int? pageIndex,
    int? pageCount,
    double? scrollOffset,
    double? maxScrollExtent,
  }) {
    return ReaderViewportState(
      kind: _resolveKind(mode.viewportKind, contentMode),
      contentMode: contentMode,
      supportsTextSelection: mode.supportsTextSelection,
      supportsZoomGesture: mode.supportsZoomGesture,
      supportsAutoRead: mode.supportsAutoRead,
      pageIndex: pageIndex,
      pageCount: pageCount,
      scrollOffset: scrollOffset,
      maxScrollExtent: maxScrollExtent,
      chapterPositionRatio: chapterPositionRatio.clamp(0.0, 1.0),
    );
  }

  ReaderViewportStateKind _resolveKind(
    ReaderModeViewportKind viewportKind,
    ReaderContentMode contentMode,
  ) {
    switch (viewportKind) {
      case ReaderModeViewportKind.textPaged:
        return ReaderViewportStateKind.textPaged;
      case ReaderModeViewportKind.textScroll:
        return ReaderViewportStateKind.textScroll;
      case ReaderModeViewportKind.imagePaged:
        return ReaderViewportStateKind.mangaPaged;
      case ReaderModeViewportKind.imageScroll:
        return ReaderViewportStateKind.mangaContinuous;
      case ReaderModeViewportKind.hybridPaged:
        return ReaderViewportStateKind.hybridPaged;
      case ReaderModeViewportKind.audio:
        return ReaderViewportStateKind.audio;
    }
  }
}

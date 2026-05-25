import 'reader_content_session.dart';

enum ReaderViewportStateKind {
  textPaged,
  textScroll,
  mangaPaged,
  mangaContinuous,
  hybridPaged,
  audio,
}

class ReaderViewportState {
  const ReaderViewportState({
    required this.kind,
    required this.contentMode,
    required this.supportsTextSelection,
    required this.supportsZoomGesture,
    required this.supportsAutoRead,
    this.pageIndex,
    this.pageCount,
    this.scrollOffset,
    this.maxScrollExtent,
    this.chapterPositionRatio = 0,
  });

  final ReaderViewportStateKind kind;
  final ReaderContentMode contentMode;
  final bool supportsTextSelection;
  final bool supportsZoomGesture;
  final bool supportsAutoRead;
  final int? pageIndex;
  final int? pageCount;
  final double? scrollOffset;
  final double? maxScrollExtent;
  final double chapterPositionRatio;

  bool get isPaged =>
      kind == ReaderViewportStateKind.textPaged ||
      kind == ReaderViewportStateKind.mangaPaged ||
      kind == ReaderViewportStateKind.hybridPaged;

  bool get isScroll =>
      kind == ReaderViewportStateKind.textScroll ||
      kind == ReaderViewportStateKind.mangaContinuous ||
      kind == ReaderViewportStateKind.audio;
}

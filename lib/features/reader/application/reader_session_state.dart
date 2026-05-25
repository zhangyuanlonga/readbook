import 'reader_logical_position.dart';
import '../../../domain/entities/reading_progress.dart';

enum TextReaderRendererKind { scroll, paged }

class ReaderVisiblePosition {
  const ReaderVisiblePosition({
    this.pageIndex,
    this.pageCount,
    this.scrollOffset,
    this.maxScrollExtent,
  });

  final int? pageIndex;
  final int? pageCount;
  final double? scrollOffset;
  final double? maxScrollExtent;
}

class ReaderViewportSession {
  const ReaderViewportSession({
    required this.viewportMode,
    this.pageIndex,
    this.pageCount,
    this.scrollOffset,
    this.maxScrollExtent,
    this.zoomScale,
    this.panDx,
    this.panDy,
    this.audioPositionMs,
    this.audioDurationMs,
    this.audioSpeed,
  });

  final String viewportMode;
  final int? pageIndex;
  final int? pageCount;
  final double? scrollOffset;
  final double? maxScrollExtent;
  final double? zoomScale;
  final double? panDx;
  final double? panDy;
  final int? audioPositionMs;
  final int? audioDurationMs;
  final double? audioSpeed;

  ReaderPositionSnapshot toPositionSnapshot() {
    return ReaderPositionSnapshot(
      viewportMode: viewportMode,
      pageIndex: pageIndex,
      pageCount: pageCount,
      scrollOffset: scrollOffset,
      maxScrollExtent: maxScrollExtent,
      zoomScale: zoomScale,
      panDx: panDx,
      panDy: panDy,
      audioPositionMs: audioPositionMs,
      audioDurationMs: audioDurationMs,
      audioSpeed: audioSpeed,
    );
  }
}

class ReaderSessionState {
  const ReaderSessionState({
    required this.currentChapterIndex,
    required this.currentChapterId,
    required this.currentChapterUrl,
    required this.currentChapterTitle,
    required this.logicalPosition,
    required this.visiblePosition,
    required this.viewportSession,
    required this.rendererKind,
    required this.isAutoReading,
    required this.isChapterTransitioning,
  });

  final int currentChapterIndex;
  final String currentChapterId;
  final String currentChapterUrl;
  final String currentChapterTitle;
  final ReaderLogicalPosition logicalPosition;
  final ReaderVisiblePosition visiblePosition;
  final ReaderViewportSession viewportSession;
  final TextReaderRendererKind rendererKind;
  final bool isAutoReading;
  final bool isChapterTransitioning;

  ReaderSessionState copyWith({
    int? currentChapterIndex,
    String? currentChapterId,
    String? currentChapterUrl,
    String? currentChapterTitle,
    ReaderLogicalPosition? logicalPosition,
    ReaderVisiblePosition? visiblePosition,
    ReaderViewportSession? viewportSession,
    TextReaderRendererKind? rendererKind,
    bool? isAutoReading,
    bool? isChapterTransitioning,
  }) {
    return ReaderSessionState(
      currentChapterIndex: currentChapterIndex ?? this.currentChapterIndex,
      currentChapterId: currentChapterId ?? this.currentChapterId,
      currentChapterUrl: currentChapterUrl ?? this.currentChapterUrl,
      currentChapterTitle: currentChapterTitle ?? this.currentChapterTitle,
      logicalPosition: logicalPosition ?? this.logicalPosition,
      visiblePosition: visiblePosition ?? this.visiblePosition,
      viewportSession: viewportSession ?? this.viewportSession,
      rendererKind: rendererKind ?? this.rendererKind,
      isAutoReading: isAutoReading ?? this.isAutoReading,
      isChapterTransitioning:
          isChapterTransitioning ?? this.isChapterTransitioning,
    );
  }
}

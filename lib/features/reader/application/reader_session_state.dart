import 'reader_logical_position.dart';

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

class ReaderSessionState {
  const ReaderSessionState({
    required this.currentChapterIndex,
    required this.currentChapterId,
    required this.currentChapterUrl,
    required this.currentChapterTitle,
    required this.logicalPosition,
    required this.visiblePosition,
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
      rendererKind: rendererKind ?? this.rendererKind,
      isAutoReading: isAutoReading ?? this.isAutoReading,
      isChapterTransitioning:
          isChapterTransitioning ?? this.isChapterTransitioning,
    );
  }
}

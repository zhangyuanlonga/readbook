import 'reader_logical_position.dart';
import 'reader_session_state.dart';
import 'text_reader_renderer.dart';

class ReaderSessionStateResolver {
  const ReaderSessionStateResolver();

  ReaderSessionState? resolve({
    required int? chapterIndex,
    required String chapterId,
    required String? chapterUrl,
    required String? chapterTitle,
    required ReaderLogicalPosition? logicalPosition,
    required TextReaderRendererKind rendererKind,
    required ReaderRenderMetrics metrics,
    required bool isAutoReading,
    required bool isChapterTransitioning,
  }) {
    if (chapterIndex == null || logicalPosition == null) {
      return null;
    }

    return ReaderSessionState(
      currentChapterIndex: chapterIndex,
      currentChapterId: chapterId.trim(),
      currentChapterUrl: (chapterUrl ?? '').trim(),
      currentChapterTitle: (chapterTitle ?? '').trim(),
      logicalPosition: logicalPosition,
      visiblePosition: _resolveVisiblePosition(
        rendererKind: rendererKind,
        metrics: metrics,
      ),
      rendererKind: rendererKind,
      isAutoReading: isAutoReading,
      isChapterTransitioning: isChapterTransitioning,
    );
  }

  ReaderVisiblePosition _resolveVisiblePosition({
    required TextReaderRendererKind rendererKind,
    required ReaderRenderMetrics metrics,
  }) {
    if (rendererKind == TextReaderRendererKind.paged) {
      final pageCount = metrics.pageCount < 0 ? 0 : metrics.pageCount;
      final pageIndex =
          pageCount <= 0 ? 0 : metrics.currentPageIndex.clamp(0, pageCount - 1);
      return ReaderVisiblePosition(pageCount: pageCount, pageIndex: pageIndex);
    }

    if (!metrics.hasScrollClients) {
      return const ReaderVisiblePosition(scrollOffset: 0, maxScrollExtent: 0);
    }

    return ReaderVisiblePosition(
      scrollOffset: metrics.scrollOffset,
      maxScrollExtent: metrics.maxScrollExtent,
    );
  }
}

import '../../../domain/entities/bookmark.dart';
import '../domain/entities/reader_layout_models.dart';
import 'reader_layout_anchor_models.dart';
import 'reader_layout_hit_test_service.dart';
import 'reader_layout_progress_anchor_mapper.dart';
import 'reader_selection_runtime.dart';

class ReaderBookmarkLayoutAnchor {
  const ReaderBookmarkLayoutAnchor({
    required this.bookmarkId,
    required this.position,
    this.range,
  });

  final String bookmarkId;
  final ReaderLayoutAnchoredPosition position;
  final ReaderLayoutAnchoredRange? range;
}

class ReaderBookmarkAnchorMapper {
  const ReaderBookmarkAnchorMapper({
    this.hitTestService = const ReaderLayoutHitTestService(),
    this.progressMapper = const ReaderLayoutProgressAnchorMapper(),
    this.selectionRuntime = const ReaderSelectionRuntime(),
  });

  final ReaderLayoutHitTestService hitTestService;
  final ReaderLayoutProgressAnchorMapper progressMapper;
  final ReaderSelectionRuntime selectionRuntime;

  ReaderBookmarkLayoutAnchor? fromBookmark({
    required Bookmark bookmark,
    required List<ReaderLayoutPage> layoutPages,
  }) {
    if (layoutPages.isEmpty) {
      return null;
    }
    final restored = ReaderLayoutAnchoredRange.fromJson(
      bookmark.content.layoutAnchor ?? const <String, Object?>{},
    );
    final rangeSnapshot =
        restored == null
            ? selectionRuntime.selectOffsets(
              layoutPages: layoutPages,
              startOffset: bookmark.startOffset,
              endOffset: bookmark.endOffset,
              kind: ReaderLayoutAnchorKind.bookmark,
              sourceId: bookmark.id,
            )
            : selectionRuntime.selectPositions(
              layoutPages: layoutPages,
              start: restored.range.start,
              end: restored.range.end,
              kind: ReaderLayoutAnchorKind.bookmark,
              sourceId: bookmark.id,
            );
    final startPosition =
        rangeSnapshot?.range.start ??
        hitTestService.chapterOffsetToPosition(
          layoutPages,
          bookmark.startOffset,
        );
    if (startPosition == null) {
      return null;
    }
    final progress = progressMapper.toLegacyProgress(
      layoutPages: layoutPages,
      position: startPosition,
    );
    return ReaderBookmarkLayoutAnchor(
      bookmarkId: bookmark.id,
      position: ReaderLayoutAnchoredPosition(
        kind: ReaderLayoutAnchorKind.bookmark,
        position: startPosition,
        chapterProgressRatio: progress.chapterPositionRatio,
        layoutSignature: _layoutSignatureFor(
          layoutPages,
          startPosition.pageIndex,
        ),
        sourceId: bookmark.id,
        totalPageCount: layoutPages.length,
      ),
      range: rangeSnapshot?.anchor,
    );
  }

  Bookmark buildBookmarkForPosition({
    required ReaderLayoutAnchoredPosition position,
    required String bookId,
    required String chapterId,
    required int chapterIndex,
    required String bookmarkId,
    required DateTime timestamp,
    String label = '',
    Bookmark? existing,
  }) {
    final quote =
        label.trim().isEmpty ? '位置 ${position.chapterOffset}' : label.trim();
    return Bookmark(
      id: existing?.id ?? bookmarkId,
      bookId: bookId,
      chapterId: chapterId,
      chapterIndex: chapterIndex,
      startOffset: position.chapterOffset,
      endOffset: position.chapterOffset,
      snippet: Bookmark.buildLayoutSnippetPayload(
        quote: quote,
        note: existing?.note,
        layoutAnchor: position.toJson(),
      ),
      note: existing?.note,
      createdAt: existing?.createdAt ?? timestamp,
      updatedAt: timestamp,
    );
  }

  ReaderLayoutAnchoredPosition? restorePosition({
    required List<ReaderLayoutPage> layoutPages,
    required int legacyChapterOffset,
    double? legacyRatio,
    String? sourceId,
  }) {
    return progressMapper.fromLegacyProgress(
      layoutPages: layoutPages,
      chapterOffset: legacyChapterOffset,
      chapterProgressRatio: legacyRatio ?? 0,
      sourceId: sourceId,
    );
  }

  String? _layoutSignatureFor(
    List<ReaderLayoutPage> layoutPages,
    int pageIndex,
  ) {
    for (final page in layoutPages) {
      if (page.pageIndex == pageIndex) {
        return page.layoutSignature;
      }
    }
    return layoutPages.first.layoutSignature;
  }
}

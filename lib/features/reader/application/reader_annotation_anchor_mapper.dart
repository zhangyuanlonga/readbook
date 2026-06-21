import '../../../domain/entities/bookmark.dart';
import '../domain/entities/reader_layout_models.dart';
import 'reader_layout_anchor_models.dart';
import 'reader_selection_runtime.dart';

class ReaderAnnotationLayoutAnchor {
  const ReaderAnnotationLayoutAnchor({
    required this.bookmarkId,
    required this.anchor,
    required this.hasHighlight,
    required this.isBold,
    required this.isUnderline,
    required this.isWavy,
    this.note,
  });

  final String bookmarkId;
  final ReaderLayoutAnchoredRange anchor;
  final bool hasHighlight;
  final bool isBold;
  final bool isUnderline;
  final bool isWavy;
  final String? note;
}

class ReaderAnnotationAnchorMapper {
  const ReaderAnnotationAnchorMapper({
    this.selectionRuntime = const ReaderSelectionRuntime(),
  });

  final ReaderSelectionRuntime selectionRuntime;

  ReaderAnnotationLayoutAnchor? fromBookmark({
    required Bookmark bookmark,
    required List<ReaderLayoutPage> layoutPages,
  }) {
    final restored = ReaderLayoutAnchoredRange.fromJson(
      bookmark.content.layoutAnchor ?? const <String, Object?>{},
    );
    if (restored == null) {
      return null;
    }
    final snapshot = selectionRuntime.selectPositions(
      layoutPages: layoutPages,
      start: restored.range.start,
      end: restored.range.end,
      kind: ReaderLayoutAnchorKind.annotation,
      sourceId: bookmark.id,
    );
    if (snapshot == null || snapshot.isCollapsed) {
      return null;
    }
    return ReaderAnnotationLayoutAnchor(
      bookmarkId: bookmark.id,
      anchor: snapshot.anchor,
      hasHighlight: _bookmarkHasHighlight(bookmark),
      isBold: bookmark.isBold,
      isUnderline: bookmark.isWavy ? false : bookmark.isUnderline,
      isWavy: bookmark.isWavy,
      note: bookmark.note,
    );
  }

  List<ReaderAnnotationLayoutAnchor> fromBookmarks({
    required Iterable<Bookmark> bookmarks,
    required List<ReaderLayoutPage> layoutPages,
  }) {
    return bookmarks
        .map(
          (bookmark) =>
              fromBookmark(bookmark: bookmark, layoutPages: layoutPages),
        )
        .whereType<ReaderAnnotationLayoutAnchor>()
        .toList(growable: false);
  }

  Bookmark? buildBookmarkForAnchor({
    required ReaderLayoutAnchoredRange anchor,
    required String bookId,
    required String chapterId,
    required int chapterIndex,
    required String bookmarkId,
    required DateTime timestamp,
    Bookmark? existing,
    String? note,
    bool hasHighlight = true,
    bool isBold = false,
    bool isUnderline = false,
    bool isWavy = false,
  }) {
    final quote = anchor.selectedText.trim();
    if (anchor.endOffset <= anchor.startOffset || quote.isEmpty) {
      return null;
    }
    final effectiveWavy = isWavy;
    final effectiveUnderline = effectiveWavy ? false : isUnderline;
    final effectiveNote = note ?? existing?.note;
    return Bookmark(
      id: existing?.id ?? bookmarkId,
      bookId: bookId,
      chapterId: chapterId,
      chapterIndex: chapterIndex,
      startOffset: anchor.startOffset,
      endOffset: anchor.endOffset,
      snippet: Bookmark.buildLayoutSnippetPayload(
        quote: quote,
        note: effectiveNote,
        layoutAnchor: anchor.toJson(),
      ),
      note: effectiveNote,
      createdAt: existing?.createdAt ?? timestamp,
      updatedAt: timestamp,
      isBold: isBold,
      isUnderline: effectiveUnderline,
      isWavy: effectiveWavy,
      color: hasHighlight ? '__highlight__' : '__none__',
    );
  }

  List<ReaderAnnotationLayoutAnchor> removeByBookmarkId(
    Iterable<ReaderAnnotationLayoutAnchor> anchors,
    String bookmarkId,
  ) {
    return anchors
        .where((anchor) => anchor.bookmarkId != bookmarkId)
        .toList(growable: false);
  }

  bool _bookmarkHasHighlight(Bookmark bookmark) {
    final color = bookmark.color?.trim();
    if (color == null || color.isEmpty) {
      return !bookmark.isUnderline && !bookmark.isWavy;
    }
    return color != '__none__';
  }
}

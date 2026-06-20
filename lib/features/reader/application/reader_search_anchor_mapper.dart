import '../../../domain/entities/reader_logical_position.dart';
import '../domain/entities/reader_layout_models.dart';
import 'reader_layout_anchor_models.dart';
import 'reader_selection_runtime.dart';

class ReaderSearchLayoutAnchor {
  const ReaderSearchLayoutAnchor({
    required this.keyword,
    required this.anchor,
    required this.logicalPosition,
    required this.scrollRatio,
  });

  final String keyword;
  final ReaderLayoutAnchoredRange anchor;
  final ReaderLogicalPosition logicalPosition;
  final double scrollRatio;
}

class ReaderSearchAnchorMapper {
  const ReaderSearchAnchorMapper({
    this.selectionRuntime = const ReaderSelectionRuntime(),
  });

  final ReaderSelectionRuntime selectionRuntime;

  List<ReaderSearchLayoutAnchor> resolveKeywordHits({
    required String keyword,
    required List<String> paragraphs,
    required List<ReaderLayoutPage> layoutPages,
    required int chapterIndex,
    int paragraphSeparatorLength = 2,
    int maxHits = 60,
  }) {
    final normalizedKeyword = keyword.trim();
    if (normalizedKeyword.isEmpty ||
        paragraphs.isEmpty ||
        layoutPages.isEmpty ||
        maxHits <= 0) {
      return const <ReaderSearchLayoutAnchor>[];
    }

    final starts = _paragraphStarts(paragraphs, paragraphSeparatorLength);
    final totalLength = _totalLength(paragraphs, paragraphSeparatorLength);
    final hits = <ReaderSearchLayoutAnchor>[];
    for (
      var paragraphIndex = 0;
      paragraphIndex < paragraphs.length;
      paragraphIndex++
    ) {
      final paragraph = paragraphs[paragraphIndex];
      var searchFrom = 0;
      while (searchFrom < paragraph.length && hits.length < maxHits) {
        final match = _indexOf(paragraph, normalizedKeyword, searchFrom);
        if (match < 0) {
          break;
        }
        final startOffset = starts[paragraphIndex] + match;
        final endOffset = startOffset + normalizedKeyword.length;
        final snapshot = selectionRuntime.selectOffsets(
          layoutPages: layoutPages,
          startOffset: startOffset,
          endOffset: endOffset,
          kind: ReaderLayoutAnchorKind.search,
          sourceId: normalizedKeyword,
        );
        if (snapshot != null && !snapshot.isCollapsed) {
          final ratio =
              totalLength <= 0
                  ? 0.0
                  : (startOffset / totalLength).clamp(0.0, 1.0);
          hits.add(
            ReaderSearchLayoutAnchor(
              keyword: normalizedKeyword,
              anchor: snapshot.anchor,
              logicalPosition: ReaderLogicalPosition(
                chapterIndex: chapterIndex,
                blockIndex: paragraphIndex,
                offsetInBlock: match,
                chapterPositionRatio: ratio,
                pageIndex: snapshot.range.start.pageIndex,
                totalPageCount: layoutPages.length,
                viewportMode: 'layout',
              ),
              scrollRatio: ratio,
            ),
          );
        }
        searchFrom = match + normalizedKeyword.length;
      }
      if (hits.length >= maxHits) {
        break;
      }
    }
    return List<ReaderSearchLayoutAnchor>.unmodifiable(hits);
  }

  int _indexOf(String source, String keyword, int start) {
    final exact = source.indexOf(keyword, start);
    if (exact >= 0) {
      return exact;
    }
    return source.toLowerCase().indexOf(keyword.toLowerCase(), start);
  }

  List<int> _paragraphStarts(
    List<String> paragraphs,
    int paragraphSeparatorLength,
  ) {
    final starts = <int>[];
    var offset = 0;
    for (final paragraph in paragraphs) {
      starts.add(offset);
      offset += paragraph.length + paragraphSeparatorLength;
    }
    return starts;
  }

  int _totalLength(List<String> paragraphs, int paragraphSeparatorLength) {
    if (paragraphs.isEmpty) {
      return 0;
    }
    return paragraphs.fold<int>(0, (sum, text) => sum + text.length) +
        (paragraphs.length - 1) * paragraphSeparatorLength;
  }
}

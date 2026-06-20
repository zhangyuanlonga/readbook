import '../domain/entities/reader_layout_models.dart';
import 'reader_pagination_models.dart';
import 'reader_pagination_spec.dart';

class ReaderPagedSliceLayoutAdapter {
  const ReaderPagedSliceLayoutAdapter();

  List<ReaderLayoutPage> buildPages({
    required String chapterId,
    required int chapterIndex,
    required List<String> paragraphs,
    required List<List<ReaderPagedSlice>> pagedPages,
    required ReaderPaginationSpec spec,
    required String layoutSignature,
    int paragraphSeparatorLength = 2,
  }) {
    if (pagedPages.isEmpty) {
      return const <ReaderLayoutPage>[];
    }

    final separatorLength =
        paragraphSeparatorLength < 0 ? 0 : paragraphSeparatorLength;
    final paragraphStarts = _buildParagraphStarts(
      paragraphs,
      separatorLength: separatorLength,
    );

    return List<ReaderLayoutPage>.generate(pagedPages.length, (pageIndex) {
      final normalizedSlices = _normalizeSlices(
        pagedPages[pageIndex],
        paragraphs: paragraphs,
        paragraphStarts: paragraphStarts,
      );

      if (normalizedSlices.isEmpty) {
        return ReaderLayoutPage(
          chapterId: chapterId,
          chapterIndex: chapterIndex,
          pageIndex: pageIndex,
          startOffset: 0,
          endOffset: 0,
          contentWidth: spec.contentWidth,
          contentHeight: spec.contentHeight,
          layoutSignature: layoutSignature,
          lines: const <ReaderLayoutLine>[],
        );
      }

      final pageStartOffset = normalizedSlices.first.chapterStart;
      var y = 0.0;
      final lines = <ReaderLayoutLine>[];
      for (final slice in normalizedSlices) {
        final lineTop = y;
        final lineHeight = slice.height < 0 ? 0.0 : slice.height;
        final lineBottom = lineTop + lineHeight;
        final column = ReaderLayoutColumn(
          columnIndex: 0,
          kind: ReaderLayoutColumnKind.text,
          startOffset: slice.chapterStart,
          endOffset: slice.chapterEnd,
          rect: ReaderLayoutRect(
            left: 0,
            top: lineTop,
            right: spec.contentWidth,
            bottom: lineBottom,
          ),
          text: slice.text,
        );

        lines.add(
          ReaderLayoutLine(
            lineIndex: lines.length,
            paragraphIndex: slice.paragraphIndex,
            text: slice.text,
            chapterOffset: slice.chapterStart,
            pageOffset: slice.chapterStart - pageStartOffset,
            lineTop: lineTop,
            lineBase: lineBottom,
            lineBottom: lineBottom,
            columns: <ReaderLayoutColumn>[column],
            isParagraphEnd: slice.end == slice.paragraphLength,
          ),
        );
        y = lineBottom;
      }

      return ReaderLayoutPage(
        chapterId: chapterId,
        chapterIndex: chapterIndex,
        pageIndex: pageIndex,
        startOffset: pageStartOffset,
        endOffset: normalizedSlices.last.chapterEnd,
        contentWidth: spec.contentWidth,
        contentHeight: spec.contentHeight,
        layoutSignature: layoutSignature,
        lines: List<ReaderLayoutLine>.unmodifiable(lines),
      );
    }, growable: false);
  }

  List<int> _buildParagraphStarts(
    List<String> paragraphs, {
    required int separatorLength,
  }) {
    var nextStart = 0;
    return paragraphs
        .map((paragraph) {
          final start = nextStart;
          nextStart += paragraph.length + separatorLength;
          return start;
        })
        .toList(growable: false);
  }

  List<_NormalizedSlice> _normalizeSlices(
    List<ReaderPagedSlice> slices, {
    required List<String> paragraphs,
    required List<int> paragraphStarts,
  }) {
    final normalized = <_NormalizedSlice>[];
    for (final slice in slices) {
      if (slice.paragraphIndex < 0 ||
          slice.paragraphIndex >= paragraphs.length) {
        continue;
      }

      final paragraph = paragraphs[slice.paragraphIndex];
      final start = _clampInt(slice.start, 0, paragraph.length);
      final end = _clampInt(slice.end, start, paragraph.length);
      final chapterStart = paragraphStarts[slice.paragraphIndex] + start;
      final chapterEnd = paragraphStarts[slice.paragraphIndex] + end;
      normalized.add(
        _NormalizedSlice(
          paragraphIndex: slice.paragraphIndex,
          paragraphLength: paragraph.length,
          start: start,
          end: end,
          chapterStart: chapterStart,
          chapterEnd: chapterEnd,
          height: slice.height,
          text: paragraph.substring(start, end),
        ),
      );
    }
    return normalized;
  }

  int _clampInt(int value, int min, int max) {
    if (value < min) {
      return min;
    }
    if (value > max) {
      return max;
    }
    return value;
  }
}

class _NormalizedSlice {
  const _NormalizedSlice({
    required this.paragraphIndex,
    required this.paragraphLength,
    required this.start,
    required this.end,
    required this.chapterStart,
    required this.chapterEnd,
    required this.height,
    required this.text,
  });

  final int paragraphIndex;
  final int paragraphLength;
  final int start;
  final int end;
  final int chapterStart;
  final int chapterEnd;
  final double height;
  final String text;
}

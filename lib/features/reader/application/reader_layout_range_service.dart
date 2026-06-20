import '../domain/entities/reader_layout_models.dart';
import 'reader_layout_hit_test_service.dart';

class ReaderLayoutRangeService {
  const ReaderLayoutRangeService({
    this.hitTestService = const ReaderLayoutHitTestService(),
  });

  final ReaderLayoutHitTestService hitTestService;

  List<ReaderLayoutRect> rectsForRange(
    List<ReaderLayoutPage> layoutPages,
    ReaderLayoutRange range,
  ) {
    if (layoutPages.isEmpty) {
      return const <ReaderLayoutRect>[];
    }
    if (range.isCollapsed) {
      final caret = caretRectForPosition(layoutPages, range.start);
      return caret == null
          ? const <ReaderLayoutRect>[]
          : <ReaderLayoutRect>[caret];
    }

    final rects = <ReaderLayoutRect>[];
    for (final page in layoutPages) {
      if (page.pageIndex < range.start.pageIndex ||
          page.pageIndex > range.end.pageIndex) {
        continue;
      }
      for (final line in page.lines) {
        final lineStart = line.chapterOffset;
        final lineEnd = line.endChapterOffset;
        final selectedStart = _maxInt(lineStart, range.start.chapterOffset);
        final selectedEnd = _minInt(lineEnd, range.end.chapterOffset);
        if (selectedEnd <= selectedStart) {
          continue;
        }
        rects.addAll(_rectsForLine(line, selectedStart, selectedEnd));
      }
    }
    return List<ReaderLayoutRect>.unmodifiable(rects);
  }

  ReaderLayoutRect? caretRectForPosition(
    List<ReaderLayoutPage> layoutPages,
    ReaderLayoutPosition position, {
    double caretWidth = 1,
  }) {
    final resolved = hitTestService.chapterOffsetToPosition(
      layoutPages,
      position.chapterOffset,
    );
    if (resolved == null) {
      return null;
    }

    final page = _pageByIndex(layoutPages, resolved.pageIndex);
    if (page == null) {
      return null;
    }
    final line = _lineByIndex(page.lines, resolved.lineIndex);
    if (line == null) {
      return null;
    }
    final column = _columnByIndex(line.columns, resolved.columnIndex);
    if (column == null) {
      return ReaderLayoutRect(
        left: 0,
        top: line.lineTop,
        right: caretWidth,
        bottom: line.lineBottom,
      );
    }

    final x = _xForOffset(column, resolved.chapterOffset);
    return ReaderLayoutRect(
      left: x,
      top: column.rect.top,
      right: x + caretWidth,
      bottom: column.rect.bottom,
    );
  }

  List<ReaderLayoutRect> _rectsForLine(
    ReaderLayoutLine line,
    int selectedStart,
    int selectedEnd,
  ) {
    if (line.columns.isEmpty) {
      return <ReaderLayoutRect>[
        ReaderLayoutRect(
          left: 0,
          top: line.lineTop,
          right: 0,
          bottom: line.lineBottom,
        ),
      ];
    }

    final rects = <ReaderLayoutRect>[];
    for (final column in line.columns) {
      final columnStart = _maxInt(column.startOffset, selectedStart);
      final columnEnd = _minInt(column.endOffset, selectedEnd);
      if (columnEnd <= columnStart) {
        continue;
      }
      final left = _xForOffset(column, columnStart);
      final right = _xForOffset(column, columnEnd);
      rects.add(
        ReaderLayoutRect(
          left: left,
          top: column.rect.top,
          right: right,
          bottom: column.rect.bottom,
        ),
      );
    }
    return rects;
  }

  ReaderLayoutPage? _pageByIndex(List<ReaderLayoutPage> pages, int pageIndex) {
    for (final page in pages) {
      if (page.pageIndex == pageIndex) {
        return page;
      }
    }
    return null;
  }

  ReaderLayoutLine? _lineByIndex(List<ReaderLayoutLine> lines, int lineIndex) {
    for (final line in lines) {
      if (line.lineIndex == lineIndex) {
        return line;
      }
    }
    return null;
  }

  ReaderLayoutColumn? _columnByIndex(
    List<ReaderLayoutColumn> columns,
    int columnIndex,
  ) {
    for (final column in columns) {
      if (column.columnIndex == columnIndex) {
        return column;
      }
    }
    return null;
  }

  double _xForOffset(ReaderLayoutColumn column, int chapterOffset) {
    if (column.endOffset == column.startOffset || column.rect.width <= 0) {
      return column.rect.left;
    }
    final ratio = ((chapterOffset - column.startOffset) /
            (column.endOffset - column.startOffset))
        .clamp(0.0, 1.0);
    return column.rect.left + column.rect.width * ratio;
  }

  int _minInt(int a, int b) => a < b ? a : b;
  int _maxInt(int a, int b) => a > b ? a : b;
}

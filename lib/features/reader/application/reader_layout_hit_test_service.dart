import '../domain/entities/reader_layout_models.dart';

class ReaderLayoutHitTestResult {
  const ReaderLayoutHitTestResult({
    required this.page,
    required this.line,
    required this.column,
    required this.position,
    required this.dx,
    required this.dy,
  });

  final ReaderLayoutPage page;
  final ReaderLayoutLine line;
  final ReaderLayoutColumn? column;
  final ReaderLayoutPosition position;
  final double dx;
  final double dy;
}

class ReaderLayoutHitTestService {
  const ReaderLayoutHitTestService();

  ReaderLayoutHitTestResult? hitTestPage(
    ReaderLayoutPage page, {
    required double dx,
    required double dy,
  }) {
    if (page.lines.isEmpty) {
      return null;
    }

    final line = _nearestLine(page.lines, dy);
    final column = _nearestColumn(line.columns, dx: dx, dy: dy);
    final chapterOffset = column == null
        ? _clampInt(line.chapterOffset, page.startOffset, page.endOffset)
        : _resolveColumnOffset(column, dx);

    return ReaderLayoutHitTestResult(
      page: page,
      line: line,
      column: column,
      position: ReaderLayoutPosition(
        pageIndex: page.pageIndex,
        lineIndex: line.lineIndex,
        columnIndex: column?.columnIndex ?? 0,
        chapterOffset: chapterOffset,
        affinity: dx < (column?.rect.left ?? 0)
            ? ReaderLayoutPositionAffinity.upstream
            : ReaderLayoutPositionAffinity.downstream,
      ),
      dx: dx,
      dy: dy,
    );
  }

  ReaderLayoutPosition? chapterOffsetToPosition(
    List<ReaderLayoutPage> layoutPages,
    int chapterOffset,
  ) {
    if (layoutPages.isEmpty) {
      return null;
    }

    final page = _pageForOffset(layoutPages, chapterOffset);
    final clampedOffset = _clampInt(
      chapterOffset,
      page.startOffset,
      page.endOffset,
    );
    if (page.lines.isEmpty) {
      return ReaderLayoutPosition(
        pageIndex: page.pageIndex,
        lineIndex: 0,
        columnIndex: 0,
        chapterOffset: clampedOffset,
      );
    }

    final line = _lineForOffset(page.lines, clampedOffset);
    final column = _columnForOffset(line.columns, clampedOffset);
    return ReaderLayoutPosition(
      pageIndex: page.pageIndex,
      lineIndex: line.lineIndex,
      columnIndex: column?.columnIndex ?? 0,
      chapterOffset: clampedOffset,
    );
  }

  int positionToChapterOffset(
    ReaderLayoutPosition position, {
    List<ReaderLayoutPage> layoutPages = const <ReaderLayoutPage>[],
  }) {
    if (layoutPages.isEmpty) {
      return position.chapterOffset;
    }

    final page = _pageByIndex(layoutPages, position.pageIndex);
    if (page.lines.isEmpty) {
      return _clampInt(position.chapterOffset, page.startOffset, page.endOffset);
    }

    final line = _lineByIndex(page.lines, position.lineIndex);
    if (line.columns.isEmpty) {
      return _clampInt(
        position.chapterOffset,
        line.chapterOffset,
        line.endChapterOffset,
      );
    }

    final column = _columnByIndex(line.columns, position.columnIndex);
    return _clampInt(
      position.chapterOffset,
      column.startOffset,
      column.endOffset,
    );
  }

  ReaderLayoutPage _pageForOffset(
    List<ReaderLayoutPage> pages,
    int chapterOffset,
  ) {
    for (final page in pages) {
      if (chapterOffset >= page.startOffset && chapterOffset <= page.endOffset) {
        return page;
      }
    }
    if (chapterOffset < pages.first.startOffset) {
      return pages.first;
    }
    return pages.last;
  }

  ReaderLayoutPage _pageByIndex(List<ReaderLayoutPage> pages, int pageIndex) {
    for (final page in pages) {
      if (page.pageIndex == pageIndex) {
        return page;
      }
    }
    return pageIndex < pages.first.pageIndex ? pages.first : pages.last;
  }

  ReaderLayoutLine _nearestLine(List<ReaderLayoutLine> lines, double dy) {
    for (final line in lines) {
      if (dy >= line.lineTop && dy <= line.lineBottom) {
        return line;
      }
    }
    var nearest = lines.first;
    var nearestDistance = _lineDistance(nearest, dy);
    for (final line in lines.skip(1)) {
      final distance = _lineDistance(line, dy);
      if (distance < nearestDistance) {
        nearest = line;
        nearestDistance = distance;
      }
    }
    return nearest;
  }

  ReaderLayoutLine _lineForOffset(
    List<ReaderLayoutLine> lines,
    int chapterOffset,
  ) {
    for (final line in lines) {
      if (chapterOffset >= line.chapterOffset &&
          chapterOffset <= line.endChapterOffset) {
        return line;
      }
    }
    if (chapterOffset < lines.first.chapterOffset) {
      return lines.first;
    }
    return lines.last;
  }

  ReaderLayoutLine _lineByIndex(List<ReaderLayoutLine> lines, int lineIndex) {
    for (final line in lines) {
      if (line.lineIndex == lineIndex) {
        return line;
      }
    }
    return lineIndex < lines.first.lineIndex ? lines.first : lines.last;
  }

  ReaderLayoutColumn? _nearestColumn(
    List<ReaderLayoutColumn> columns, {
    required double dx,
    required double dy,
  }) {
    if (columns.isEmpty) {
      return null;
    }
    for (final column in columns) {
      if (column.rect.contains(dx: dx, dy: dy)) {
        return column;
      }
    }

    var nearest = columns.first;
    var nearestDistance = _columnDistance(nearest, dx);
    for (final column in columns.skip(1)) {
      final distance = _columnDistance(column, dx);
      if (distance < nearestDistance) {
        nearest = column;
        nearestDistance = distance;
      }
    }
    return nearest;
  }

  ReaderLayoutColumn? _columnForOffset(
    List<ReaderLayoutColumn> columns,
    int chapterOffset,
  ) {
    if (columns.isEmpty) {
      return null;
    }
    for (final column in columns) {
      if (chapterOffset >= column.startOffset &&
          chapterOffset <= column.endOffset) {
        return column;
      }
    }
    if (chapterOffset < columns.first.startOffset) {
      return columns.first;
    }
    return columns.last;
  }

  ReaderLayoutColumn _columnByIndex(
    List<ReaderLayoutColumn> columns,
    int columnIndex,
  ) {
    for (final column in columns) {
      if (column.columnIndex == columnIndex) {
        return column;
      }
    }
    return columnIndex < columns.first.columnIndex ? columns.first : columns.last;
  }

  int _resolveColumnOffset(ReaderLayoutColumn column, double dx) {
    if (column.endOffset == column.startOffset || column.rect.width <= 0) {
      return dx <= column.rect.left ? column.startOffset : column.endOffset;
    }
    final ratio = ((dx - column.rect.left) / column.rect.width).clamp(0.0, 1.0);
    return column.startOffset +
        ((column.endOffset - column.startOffset) * ratio).round();
  }

  double _lineDistance(ReaderLayoutLine line, double dy) {
    if (dy < line.lineTop) {
      return line.lineTop - dy;
    }
    if (dy > line.lineBottom) {
      return dy - line.lineBottom;
    }
    return 0;
  }

  double _columnDistance(ReaderLayoutColumn column, double dx) {
    if (dx < column.rect.left) {
      return column.rect.left - dx;
    }
    if (dx > column.rect.right) {
      return dx - column.rect.right;
    }
    return 0;
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

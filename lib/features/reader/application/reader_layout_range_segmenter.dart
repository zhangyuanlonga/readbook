import 'dart:math' as math;

import '../domain/entities/reader_layout_models.dart';
import 'reader_layout_anchor_models.dart';
import 'reader_layout_hit_test_service.dart';
import 'reader_layout_range_service.dart';

class ReaderLayoutRangeSegmenter {
  const ReaderLayoutRangeSegmenter({
    this.hitTestService = const ReaderLayoutHitTestService(),
    this.rangeService = const ReaderLayoutRangeService(),
  });

  final ReaderLayoutHitTestService hitTestService;
  final ReaderLayoutRangeService rangeService;

  List<ReaderLayoutRangeSegment> splitByPage(
    List<ReaderLayoutPage> layoutPages,
    ReaderLayoutRange range,
  ) {
    if (layoutPages.isEmpty) {
      return const <ReaderLayoutRangeSegment>[];
    }
    if (range.isCollapsed) {
      final position = hitTestService.chapterOffsetToPosition(
        layoutPages,
        range.start.chapterOffset,
      );
      if (position == null) {
        return const <ReaderLayoutRangeSegment>[];
      }
      final collapsedRange = ReaderLayoutRange(start: position, end: position);
      return <ReaderLayoutRangeSegment>[
        ReaderLayoutRangeSegment(
          pageIndex: position.pageIndex,
          range: collapsedRange,
          rects: rangeService.rectsForRange(layoutPages, collapsedRange),
        ),
      ];
    }

    final segments = <ReaderLayoutRangeSegment>[];
    for (final page in layoutPages) {
      final startOffset = math.max(page.startOffset, range.start.chapterOffset);
      final endOffset = math.min(page.endOffset, range.end.chapterOffset);
      if (endOffset <= startOffset) {
        continue;
      }
      final start = hitTestService.chapterOffsetToPosition(
        layoutPages,
        startOffset,
      );
      final end = hitTestService.chapterOffsetToPosition(
        layoutPages,
        endOffset,
      );
      if (start == null || end == null) {
        continue;
      }
      final segmentRange = ReaderLayoutRange(
        start: start,
        end: end,
        selectedText: textForRange(
          layoutPages,
          ReaderLayoutRange(start: start, end: end),
        ),
      );
      segments.add(
        ReaderLayoutRangeSegment(
          pageIndex: page.pageIndex,
          range: segmentRange,
          rects: rangeService.rectsForRange(layoutPages, segmentRange),
          selectedText: segmentRange.selectedText,
        ),
      );
    }
    return List<ReaderLayoutRangeSegment>.unmodifiable(segments);
  }

  ReaderLayoutRange? mergeSegments(List<ReaderLayoutRangeSegment> segments) {
    if (segments.isEmpty) {
      return null;
    }
    final sorted =
        segments.toList()..sort(
          (a, b) => ReaderLayoutPosition.compare(a.range.start, b.range.start),
        );
    final start = sorted.first.range.start;
    final end = sorted.last.range.end;
    if (ReaderLayoutPosition.compare(start, end) > 0) {
      return null;
    }
    return ReaderLayoutRange(
      start: start,
      end: end,
      selectedText: sorted
          .map((segment) => segment.selectedText)
          .where((text) => text.isNotEmpty)
          .join('\n'),
      rects: sorted.expand((segment) => segment.rects).toList(growable: false),
    );
  }

  String textForRange(
    List<ReaderLayoutPage> layoutPages,
    ReaderLayoutRange range,
  ) {
    if (layoutPages.isEmpty || range.isCollapsed) {
      return '';
    }
    final lineTexts = <String>[];
    for (final page in layoutPages) {
      if (page.pageIndex < range.start.pageIndex ||
          page.pageIndex > range.end.pageIndex) {
        continue;
      }
      for (final line in page.lines) {
        final lineStart = line.chapterOffset;
        final lineEnd = line.endChapterOffset;
        final selectedStart = math.max(lineStart, range.start.chapterOffset);
        final selectedEnd = math.min(lineEnd, range.end.chapterOffset);
        if (selectedEnd <= selectedStart) {
          continue;
        }
        final text = _textForLine(line, selectedStart, selectedEnd);
        if (text.isNotEmpty) {
          lineTexts.add(text);
        }
      }
    }
    return lineTexts.join('\n');
  }

  String _textForLine(
    ReaderLayoutLine line,
    int selectedStart,
    int selectedEnd,
  ) {
    if (line.columns.isEmpty) {
      final localStart =
          (selectedStart - line.chapterOffset)
              .clamp(0, line.text.length)
              .toInt();
      final localEnd =
          (selectedEnd - line.chapterOffset)
              .clamp(localStart, line.text.length)
              .toInt();
      return line.text.substring(localStart, localEnd);
    }

    final fragments = <String>[];
    for (final column in line.columns) {
      if (column.text.isEmpty) {
        continue;
      }
      final columnStart = math.max(column.startOffset, selectedStart);
      final columnEnd = math.min(column.endOffset, selectedEnd);
      if (columnEnd <= columnStart) {
        continue;
      }
      final localStart =
          (columnStart - column.startOffset)
              .clamp(0, column.text.length)
              .toInt();
      final localEnd =
          (columnEnd - column.startOffset)
              .clamp(localStart, column.text.length)
              .toInt();
      fragments.add(column.text.substring(localStart, localEnd));
    }
    return fragments.join();
  }
}

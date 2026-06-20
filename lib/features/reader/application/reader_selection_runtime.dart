import 'dart:math' as math;

import '../domain/entities/reader_layout_models.dart';
import 'reader_layout_anchor_models.dart';
import 'reader_layout_hit_test_service.dart';
import 'reader_layout_range_segmenter.dart';
import 'reader_layout_range_service.dart';

class ReaderLayoutSelectionSnapshot {
  const ReaderLayoutSelectionSnapshot({
    required this.anchor,
    required this.segments,
  });

  final ReaderLayoutAnchoredRange anchor;
  final List<ReaderLayoutRangeSegment> segments;

  ReaderLayoutRange get range => anchor.range;
  String get selectedText => anchor.selectedText;
  int get startOffset => anchor.startOffset;
  int get endOffset => anchor.endOffset;
  bool get isCollapsed => anchor.isCollapsed;
}

class ReaderSelectionRuntime {
  const ReaderSelectionRuntime({
    this.hitTestService = const ReaderLayoutHitTestService(),
    this.rangeService = const ReaderLayoutRangeService(),
    this.segmenter = const ReaderLayoutRangeSegmenter(),
  });

  final ReaderLayoutHitTestService hitTestService;
  final ReaderLayoutRangeService rangeService;
  final ReaderLayoutRangeSegmenter segmenter;

  ReaderLayoutSelectionSnapshot? selectWordAt({
    required List<ReaderLayoutPage> layoutPages,
    required int pageIndex,
    required double dx,
    required double dy,
    String? sourceId,
  }) {
    final page = _pageByIndex(layoutPages, pageIndex);
    if (page == null) {
      return null;
    }
    final hit = hitTestService.hitTestPage(page, dx: dx, dy: dy);
    final column = hit?.column;
    if (hit == null || column == null || column.text.isEmpty) {
      return null;
    }

    final localOffset =
        (hit.position.chapterOffset - column.startOffset)
            .clamp(0, column.text.length)
            .toInt();
    final localIndex =
        localOffset >= column.text.length
            ? math.max(0, column.text.length - 1)
            : localOffset;
    final bounds = _wordBounds(column.text, localIndex);
    if (bounds == null || bounds.end <= bounds.start) {
      return null;
    }
    return selectOffsets(
      layoutPages: layoutPages,
      startOffset: column.startOffset + bounds.start,
      endOffset: column.startOffset + bounds.end,
      kind: ReaderLayoutAnchorKind.selection,
      sourceId: sourceId,
    );
  }

  ReaderLayoutSelectionSnapshot? selectBetweenPoints({
    required List<ReaderLayoutPage> layoutPages,
    required int startPageIndex,
    required double startDx,
    required double startDy,
    required int endPageIndex,
    required double endDx,
    required double endDy,
    String? sourceId,
  }) {
    final startPage = _pageByIndex(layoutPages, startPageIndex);
    final endPage = _pageByIndex(layoutPages, endPageIndex);
    if (startPage == null || endPage == null) {
      return null;
    }
    final startHit = hitTestService.hitTestPage(
      startPage,
      dx: startDx,
      dy: startDy,
    );
    final endHit = hitTestService.hitTestPage(endPage, dx: endDx, dy: endDy);
    if (startHit == null || endHit == null) {
      return null;
    }
    return selectPositions(
      layoutPages: layoutPages,
      start: startHit.position,
      end: endHit.position,
      kind: ReaderLayoutAnchorKind.selection,
      sourceId: sourceId,
    );
  }

  ReaderLayoutSelectionSnapshot? selectOffsets({
    required List<ReaderLayoutPage> layoutPages,
    required int startOffset,
    required int endOffset,
    ReaderLayoutAnchorKind kind = ReaderLayoutAnchorKind.selection,
    String? sourceId,
  }) {
    if (layoutPages.isEmpty) {
      return null;
    }
    final start = hitTestService.chapterOffsetToPosition(
      layoutPages,
      startOffset,
    );
    final end = hitTestService.chapterOffsetToPosition(layoutPages, endOffset);
    if (start == null || end == null) {
      return null;
    }
    return selectPositions(
      layoutPages: layoutPages,
      start: start,
      end: end,
      kind: kind,
      sourceId: sourceId,
    );
  }

  ReaderLayoutSelectionSnapshot? selectPositions({
    required List<ReaderLayoutPage> layoutPages,
    required ReaderLayoutPosition start,
    required ReaderLayoutPosition end,
    ReaderLayoutAnchorKind kind = ReaderLayoutAnchorKind.selection,
    String? sourceId,
  }) {
    if (layoutPages.isEmpty) {
      return null;
    }
    final normalized =
        ReaderLayoutPosition.compare(start, end) <= 0
            ? (start: start, end: end)
            : (start: end, end: start);
    final baseRange = ReaderLayoutRange(
      start: normalized.start,
      end: normalized.end,
    );
    final selectedText = segmenter.textForRange(layoutPages, baseRange);
    final rects = rangeService.rectsForRange(layoutPages, baseRange);
    final range = ReaderLayoutRange(
      start: normalized.start,
      end: normalized.end,
      selectedText: selectedText,
      rects: rects,
    );
    final segments = segmenter.splitByPage(layoutPages, range);
    return ReaderLayoutSelectionSnapshot(
      anchor: ReaderLayoutAnchoredRange(
        kind: kind,
        range: range,
        selectedText: selectedText,
        rects: rects,
        layoutSignature: _layoutSignatureFor(
          layoutPages,
          range.start.pageIndex,
        ),
        sourceId: sourceId,
      ),
      segments: segments,
    );
  }

  String copyText(ReaderLayoutSelectionSnapshot snapshot) {
    return snapshot.selectedText;
  }

  ReaderLayoutPage? _pageByIndex(
    List<ReaderLayoutPage> layoutPages,
    int pageIndex,
  ) {
    for (final page in layoutPages) {
      if (page.pageIndex == pageIndex) {
        return page;
      }
    }
    return null;
  }

  String? _layoutSignatureFor(
    List<ReaderLayoutPage> layoutPages,
    int pageIndex,
  ) {
    return _pageByIndex(layoutPages, pageIndex)?.layoutSignature;
  }

  ({int start, int end})? _wordBounds(String text, int localIndex) {
    if (text.isEmpty || localIndex < 0 || localIndex >= text.length) {
      return null;
    }
    final codeUnit = text.codeUnitAt(localIndex);
    if (_isWhitespace(codeUnit)) {
      return null;
    }
    if (!_isAsciiWord(codeUnit)) {
      return (start: localIndex, end: localIndex + 1);
    }

    var start = localIndex;
    var end = localIndex + 1;
    while (start > 0 && _isAsciiWord(text.codeUnitAt(start - 1))) {
      start -= 1;
    }
    while (end < text.length && _isAsciiWord(text.codeUnitAt(end))) {
      end += 1;
    }
    return (start: start, end: end);
  }

  bool _isWhitespace(int codeUnit) {
    return codeUnit == 0x20 ||
        codeUnit == 0x09 ||
        codeUnit == 0x0A ||
        codeUnit == 0x0D;
  }

  bool _isAsciiWord(int codeUnit) {
    return (codeUnit >= 0x30 && codeUnit <= 0x39) ||
        (codeUnit >= 0x41 && codeUnit <= 0x5A) ||
        (codeUnit >= 0x61 && codeUnit <= 0x7A) ||
        codeUnit == 0x5F;
  }
}

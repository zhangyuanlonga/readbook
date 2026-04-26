import 'dart:math';

import 'package:flutter/material.dart';

import '../../../domain/entities/bookmark.dart';
import 'reader_annotated_text.dart';
import 'reader_annotation_interaction.dart';
import 'reader_selection_state.dart';

const String readerBookmarkNoHighlightToken = '__none__';
const String readerBookmarkDefaultHighlightToken = '__highlight__';

typedef ReaderParagraphOffsetResolver =
    int Function({required int paragraphIndex, required int paragraphOffset});

class ReaderAnnotationRange {
  const ReaderAnnotationRange(
    this.start,
    this.end, {
    required this.hasHighlight,
    required this.isBold,
    required this.isUnderline,
    required this.isWavy,
  });

  final int start;
  final int end;
  final bool hasHighlight;
  final bool isBold;
  final bool isUnderline;
  final bool isWavy;

  ReaderTextAnnotationRange toTextAnnotationRange() {
    return ReaderTextAnnotationRange(
      start,
      end,
      hasHighlight: hasHighlight,
      isBold: isBold,
      isUnderline: isUnderline,
      isWavy: isWavy,
    );
  }
}

class ReaderAnnotationHitTestRequest {
  const ReaderAnnotationHitTestRequest({
    required this.paragraphIndex,
    required this.paragraphText,
    required this.visibleStart,
    required this.visibleEnd,
    required this.displayText,
    required this.indentLength,
    required this.ranges,
    required this.localPosition,
    required this.maxWidth,
    required this.textStyle,
    required this.textDirection,
    required this.textAlign,
    required this.offsetResolver,
  });

  final int paragraphIndex;
  final String paragraphText;
  final int visibleStart;
  final int visibleEnd;
  final String displayText;
  final int indentLength;
  final List<ReaderAnnotationRange> ranges;
  final Offset localPosition;
  final double maxWidth;
  final TextStyle textStyle;
  final TextDirection textDirection;
  final TextAlign textAlign;
  final ReaderParagraphOffsetResolver offsetResolver;
}

class ReaderAnnotationActivation {
  const ReaderAnnotationActivation({
    required this.paragraphIndex,
    required this.paragraphStart,
    required this.paragraphEnd,
    required this.chapterStartOffset,
    required this.chapterEndOffset,
    required this.snippet,
    required this.hasHighlight,
    required this.isBold,
    required this.isUnderline,
    required this.isWavy,
  });

  final int paragraphIndex;
  final int paragraphStart;
  final int paragraphEnd;
  final int chapterStartOffset;
  final int chapterEndOffset;
  final String snippet;
  final bool hasHighlight;
  final bool isBold;
  final bool isUnderline;
  final bool isWavy;

  ReaderSelectionSnapshot toSelectionSnapshot() {
    return ReaderSelectionSnapshot(
      startOffset: chapterStartOffset,
      endOffset: chapterEndOffset,
      snippet: snippet,
      hasHighlight: hasHighlight,
      isBold: isBold,
      isUnderline: isUnderline,
      isWavy: isWavy,
    );
  }

  ReaderSelectionState applyTo(ReaderSelectionState state) {
    return state.activate(
      startOffset: chapterStartOffset,
      endOffset: chapterEndOffset,
      snippet: snippet,
      highlight: hasHighlight,
      bold: isBold,
      underline: isUnderline,
      wavy: isWavy,
    );
  }
}

class ReaderAnnotationToolbarState {
  const ReaderAnnotationToolbarState({
    required this.hasSelection,
    required this.existingBookmark,
    required this.isHighlight,
    required this.isBold,
    required this.isUnderline,
    required this.isWavy,
  });

  final bool hasSelection;
  final Bookmark? existingBookmark;
  final bool isHighlight;
  final bool isBold;
  final bool isUnderline;
  final bool isWavy;

  bool get hasExistingBookmark => existingBookmark != null;
}

enum ReaderAnnotationToolbarActionKind {
  copy,
  saveOrRemoveBookmark,
  editNote,
  toggleHighlight,
  toggleBold,
  toggleUnderline,
  toggleWavy,
  clearSelection,
}

class ReaderAnnotationToolbarAction {
  const ReaderAnnotationToolbarAction({
    required this.kind,
    required this.label,
    this.isActive = false,
    this.isDestructive = false,
  });

  final ReaderAnnotationToolbarActionKind kind;
  final String label;
  final bool isActive;
  final bool isDestructive;
}

class ReaderAnnotationBookmarkSaveRequest {
  const ReaderAnnotationBookmarkSaveRequest({
    required this.bookId,
    required this.chapterId,
    required this.chapterIndex,
    required this.selection,
    required this.bookmarkId,
    required this.timestamp,
    this.existing,
    this.forceHighlight,
    this.note,
  });

  final String bookId;
  final String chapterId;
  final int chapterIndex;
  final ReaderSelectionSnapshot selection;
  final String bookmarkId;
  final DateTime timestamp;
  final Bookmark? existing;
  final bool? forceHighlight;
  final String? note;
}

class ReaderAnnotationController {
  const ReaderAnnotationController();

  Map<int, List<ReaderAnnotationRange>> buildRangesByParagraph({
    required List<String> paragraphs,
    required Iterable<Bookmark> bookmarks,
  }) {
    if (paragraphs.isEmpty) {
      return const <int, List<ReaderAnnotationRange>>{};
    }
    final bookmarkList = bookmarks.toList(growable: false);
    if (bookmarkList.isEmpty) {
      return const <int, List<ReaderAnnotationRange>>{};
    }

    final totalLength =
        paragraphs.fold<int>(0, (sum, item) => sum + item.length) +
        max(0, paragraphs.length - 1) * 2;

    final paragraphStarts = <int>[];
    var offset = 0;
    for (final paragraph in paragraphs) {
      paragraphStarts.add(offset);
      offset += paragraph.length + 2;
    }

    final result = <int, List<ReaderAnnotationRange>>{};
    for (final bookmark in bookmarkList) {
      var start = clampInt(bookmark.startOffset, 0, totalLength);
      var end = clampInt(bookmark.endOffset, 0, totalLength);
      if (end < start) {
        final swapped = start;
        start = end;
        end = swapped;
      }
      if (start == end) {
        continue;
      }

      final startIndex = findParagraphIndexByOffset(
        paragraphStarts,
        paragraphs,
        start,
      );
      final endIndex = findParagraphIndexByOffset(
        paragraphStarts,
        paragraphs,
        end,
      );
      for (var index = startIndex; index <= endIndex; index++) {
        final paragraphStart = paragraphStarts[index];
        final paragraphLength = paragraphs[index].length;
        final paragraphEnd = paragraphStart + paragraphLength;
        final localStart = index == startIndex ? start - paragraphStart : 0;
        final localEnd =
            index == endIndex
                ? min(end, paragraphEnd) - paragraphStart
                : paragraphLength;
        if (localEnd <= localStart) {
          continue;
        }
        final list = result.putIfAbsent(index, () => <ReaderAnnotationRange>[]);
        list.add(
          ReaderAnnotationRange(
            localStart,
            localEnd,
            hasHighlight: bookmarkHasHighlight(bookmark),
            isBold: bookmark.isBold,
            isUnderline: bookmark.isUnderline,
            isWavy: bookmark.isWavy,
          ),
        );
      }
    }
    return result;
  }

  List<ReaderTextAnnotationRange> buildTextAnnotationRanges(
    Iterable<ReaderAnnotationRange> ranges,
  ) {
    return ranges
        .map((range) => range.toTextAnnotationRange())
        .toList(growable: false);
  }

  ReaderAnnotationActivation? resolveTapSelection(
    ReaderAnnotationHitTestRequest request,
  ) {
    if (request.ranges.isEmpty || request.displayText.isEmpty) {
      return null;
    }
    final visibleLength = request.visibleEnd - request.visibleStart;
    if (visibleLength <= 0) {
      return null;
    }

    final localRanges = <ReaderTextAnnotationRange>[];
    for (final range in request.ranges) {
      final overlapStart = max(range.start, request.visibleStart);
      final overlapEnd = min(range.end, request.visibleEnd);
      if (overlapEnd <= overlapStart) {
        continue;
      }
      localRanges.add(
        ReaderTextAnnotationRange(
          overlapStart - request.visibleStart,
          overlapEnd - request.visibleStart,
          hasHighlight: range.hasHighlight,
          isBold: range.isBold,
          isUnderline: range.isUnderline,
          isWavy: range.isWavy,
        ),
      );
    }
    if (localRanges.isEmpty) {
      return null;
    }

    final localRange = resolveTappedAnnotationRange(
      ranges: localRanges,
      displayText: request.displayText,
      indentLength: request.indentLength,
      rawTextLength: visibleLength,
      localPosition: request.localPosition,
      maxWidth: request.maxWidth,
      textStyle: request.textStyle,
      textDirection: request.textDirection,
      textAlign: request.textAlign,
    );
    if (localRange == null) {
      return null;
    }

    final paragraphStart = localRange.start + request.visibleStart;
    final paragraphEnd = localRange.end + request.visibleStart;
    if (paragraphEnd <= paragraphStart ||
        paragraphStart < 0 ||
        paragraphEnd > request.paragraphText.length) {
      return null;
    }

    final snippet =
        request.paragraphText.substring(paragraphStart, paragraphEnd).trim();
    if (snippet.isEmpty) {
      return null;
    }

    final chapterStartOffset = request.offsetResolver(
      paragraphIndex: request.paragraphIndex,
      paragraphOffset: paragraphStart,
    );
    final chapterEndOffset = request.offsetResolver(
      paragraphIndex: request.paragraphIndex,
      paragraphOffset: paragraphEnd,
    );

    return ReaderAnnotationActivation(
      paragraphIndex: request.paragraphIndex,
      paragraphStart: paragraphStart,
      paragraphEnd: paragraphEnd,
      chapterStartOffset: chapterStartOffset,
      chapterEndOffset: chapterEndOffset,
      snippet: snippet,
      hasHighlight: localRange.hasHighlight,
      isBold: localRange.isBold,
      isUnderline: localRange.isUnderline,
      isWavy: localRange.isWavy,
    );
  }

  ReaderSelectionStyle resolveSelectionStyleByOverlap({
    required int startOffset,
    required int endOffset,
    required Iterable<Bookmark> bookmarks,
  }) {
    var hasHighlight = false;
    var hasBold = false;
    var hasUnderline = false;
    var hasWavy = false;

    for (final bookmark in bookmarks) {
      final overlaps =
          endOffset > bookmark.startOffset && startOffset < bookmark.endOffset;
      if (!overlaps) {
        continue;
      }
      if (bookmarkHasHighlight(bookmark)) {
        hasHighlight = true;
      }
      if (bookmark.isBold) {
        hasBold = true;
      }
      if (bookmark.isWavy) {
        hasWavy = true;
      }
      if (bookmark.isUnderline) {
        hasUnderline = true;
      }
    }

    if (hasWavy) {
      hasUnderline = false;
    }

    return ReaderSelectionStyle(
      highlight: hasHighlight,
      bold: hasBold,
      underline: hasUnderline,
      wavy: hasWavy,
    );
  }

  ReaderAnnotationToolbarState resolveToolbarState({
    required ReaderSelectionState selectionState,
    required Bookmark? existingBookmark,
  }) {
    return ReaderAnnotationToolbarState(
      hasSelection: selectionState.isActive && selectionState.hasSnippet,
      existingBookmark: existingBookmark,
      isHighlight: selectionState.highlight,
      isBold: selectionState.bold,
      isUnderline: selectionState.underline,
      isWavy: selectionState.wavy,
    );
  }

  List<ReaderAnnotationToolbarAction> buildToolbarActions(
    ReaderAnnotationToolbarState state,
  ) {
    if (!state.hasSelection) {
      return const <ReaderAnnotationToolbarAction>[];
    }

    return <ReaderAnnotationToolbarAction>[
      const ReaderAnnotationToolbarAction(
        kind: ReaderAnnotationToolbarActionKind.copy,
        label: '复制',
      ),
      ReaderAnnotationToolbarAction(
        kind: ReaderAnnotationToolbarActionKind.saveOrRemoveBookmark,
        label: state.hasExistingBookmark ? '删除灵感' : '保存灵感',
        isDestructive: state.hasExistingBookmark,
      ),
      ReaderAnnotationToolbarAction(
        kind: ReaderAnnotationToolbarActionKind.editNote,
        label:
            state.existingBookmark?.hasNote == true ? '编辑笔记' : '记笔记',
      ),
      ReaderAnnotationToolbarAction(
        kind: ReaderAnnotationToolbarActionKind.toggleHighlight,
        label: state.isHighlight ? '取消高亮' : '高亮',
        isActive: state.isHighlight,
      ),
      ReaderAnnotationToolbarAction(
        kind: ReaderAnnotationToolbarActionKind.toggleBold,
        label: state.isBold ? '取消加粗重点' : '加粗重点',
        isActive: state.isBold,
      ),
      ReaderAnnotationToolbarAction(
        kind: ReaderAnnotationToolbarActionKind.toggleUnderline,
        label: state.isUnderline ? '取消划线' : '划线',
        isActive: state.isUnderline,
      ),
      ReaderAnnotationToolbarAction(
        kind: ReaderAnnotationToolbarActionKind.toggleWavy,
        label: state.isWavy ? '取消波浪线' : '波浪线',
        isActive: state.isWavy,
      ),
      const ReaderAnnotationToolbarAction(
        kind: ReaderAnnotationToolbarActionKind.clearSelection,
        label: '取消选择',
      ),
    ];
  }

  Bookmark? findBookmarkByOffsets({
    required Iterable<Bookmark> bookmarks,
    required int startOffset,
    required int endOffset,
  }) {
    for (final bookmark in bookmarks) {
      if (bookmark.startOffset == startOffset &&
          bookmark.endOffset == endOffset) {
        return bookmark;
      }
    }
    return null;
  }

  Bookmark? buildBookmarkForSelection(ReaderAnnotationBookmarkSaveRequest request) {
    final selection = request.selection;
    if (selection.endOffset <= selection.startOffset ||
        selection.snippet.trim().isEmpty) {
      return null;
    }

    final isWavy = selection.isWavy;
    final isUnderline = isWavy ? false : selection.isUnderline;
    final hasHighlight = request.forceHighlight ?? selection.hasHighlight;
    final note = request.note ?? request.existing?.note;

    return Bookmark(
      id: request.existing?.id ?? request.bookmarkId,
      bookId: request.bookId,
      chapterId: request.chapterId,
      chapterIndex: request.chapterIndex,
      startOffset: selection.startOffset,
      endOffset: selection.endOffset,
      snippet: Bookmark.buildSnippetPayload(
        quote: selection.snippet,
        note: note,
      ),
      note: note,
      createdAt: request.existing?.createdAt ?? request.timestamp,
      updatedAt: request.timestamp,
      isBold: selection.isBold,
      isUnderline: isUnderline,
      isWavy: isWavy,
      color:
          hasHighlight
              ? readerBookmarkDefaultHighlightToken
              : readerBookmarkNoHighlightToken,
    );
  }

  bool bookmarkHasHighlight(Bookmark bookmark) {
    final color = bookmark.color?.trim();
    if (color == null || color.isEmpty) {
      return !bookmark.isUnderline && !bookmark.isWavy;
    }
    return color != readerBookmarkNoHighlightToken;
  }

  int findParagraphIndexByOffset(
    List<int> paragraphStarts,
    List<String> paragraphs,
    int offset,
  ) {
    for (var index = 0; index < paragraphStarts.length; index++) {
      final start = paragraphStarts[index];
      final end = start + paragraphs[index].length;
      if (offset < start) {
        return max(0, index - 1);
      }
      if (offset <= end) {
        return index;
      }
    }
    return max(0, paragraphs.length - 1);
  }

  int clampInt(int value, int minValue, int maxValue) {
    if (value < minValue) {
      return minValue;
    }
    if (value > maxValue) {
      return maxValue;
    }
    return value;
  }
}

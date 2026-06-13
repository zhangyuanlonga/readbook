import 'dart:math';

import '../../../domain/entities/bookmark.dart';
import 'reader_page_support_models.dart';

class ReaderBookmarkRangePresenter {
  const ReaderBookmarkRangePresenter({
    this.noHighlightToken = defaultNoHighlightToken,
  });

  static const String defaultNoHighlightToken = '__none__';

  final String noHighlightToken;

  bool isBookmarkInChapter(
    Bookmark bookmark, {
    required String chapterId,
    required int? chapterIndex,
  }) {
    final normalizedChapterId = chapterId.trim();
    if (normalizedChapterId.isNotEmpty &&
        bookmark.chapterId.trim().isNotEmpty) {
      return bookmark.chapterId.trim() == normalizedChapterId;
    }
    if (chapterIndex != null) {
      return bookmark.chapterIndex == chapterIndex;
    }
    return false;
  }

  Map<int, List<ReaderBookmarkRange>> buildRangesByParagraph({
    required List<Bookmark> bookmarks,
    required List<String> paragraphs,
    required String fallbackContent,
  }) {
    final effectiveParagraphs =
        paragraphs.isEmpty ? <String>[fallbackContent.trim()] : paragraphs;
    if (effectiveParagraphs.isEmpty || bookmarks.isEmpty) {
      return const <int, List<ReaderBookmarkRange>>{};
    }

    final totalLength =
        effectiveParagraphs.fold<int>(0, (sum, item) => sum + item.length) +
        max(0, effectiveParagraphs.length - 1) * 2;
    final starts = <int>[];
    var offset = 0;
    for (final paragraph in effectiveParagraphs) {
      starts.add(offset);
      offset += paragraph.length + 2;
    }

    final result = <int, List<ReaderBookmarkRange>>{};
    for (final bookmark in bookmarks) {
      var start = _clampInt(bookmark.startOffset, 0, totalLength);
      var end = _clampInt(bookmark.endOffset, 0, totalLength);
      if (end < start) {
        final tmp = start;
        start = end;
        end = tmp;
      }
      if (end == start) {
        continue;
      }

      final startIndex = _findParagraphIndexByOffset(
        starts,
        effectiveParagraphs,
        start,
      );
      final endIndex = _findParagraphIndexByOffset(
        starts,
        effectiveParagraphs,
        end,
      );

      for (var index = startIndex; index <= endIndex; index++) {
        final paragraphStart = starts[index];
        final paragraphLength = effectiveParagraphs[index].length;
        final paragraphEnd = paragraphStart + paragraphLength;
        final localStart = index == startIndex ? start - paragraphStart : 0;
        final localEnd =
            index == endIndex
                ? min(end, paragraphEnd) - paragraphStart
                : paragraphLength;
        if (localEnd <= localStart) {
          continue;
        }
        final list = result.putIfAbsent(index, () => <ReaderBookmarkRange>[]);
        list.add(
          ReaderBookmarkRange(
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

  bool bookmarkHasHighlight(Bookmark bookmark) {
    final color = bookmark.color?.trim();
    if (color == null || color.isEmpty) {
      return !bookmark.isUnderline && !bookmark.isWavy;
    }
    return color != noHighlightToken;
  }

  Bookmark? findBookmarkByOffsets({
    required List<Bookmark> bookmarks,
    required String chapterId,
    required int? chapterIndex,
    required int startOffset,
    required int endOffset,
  }) {
    if (bookmarks.isEmpty) {
      return null;
    }
    for (final bookmark in bookmarks) {
      if (!isBookmarkInChapter(
        bookmark,
        chapterId: chapterId,
        chapterIndex: chapterIndex,
      )) {
        continue;
      }
      if (bookmark.startOffset == startOffset &&
          bookmark.endOffset == endOffset) {
        return bookmark;
      }
    }
    return null;
  }

  int _findParagraphIndexByOffset(
    List<int> starts,
    List<String> paragraphs,
    int offset,
  ) {
    for (var i = 0; i < starts.length; i++) {
      final start = starts[i];
      final end = start + paragraphs[i].length;
      if (offset < start) {
        return max(0, i - 1);
      }
      if (offset <= end) {
        return i;
      }
    }
    return max(0, paragraphs.length - 1);
  }

  int _clampInt(int value, int minValue, int maxValue) {
    if (value < minValue) {
      return minValue;
    }
    if (value > maxValue) {
      return maxValue;
    }
    return value;
  }
}

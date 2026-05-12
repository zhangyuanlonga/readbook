import '../application/reader_pagination_models.dart';

int resolveChapterOffsetFromDisplayOffset({
  required List<String> paragraphs,
  required List<List<ReaderPagedSlice>> pagedPages,
  required int currentPageIndex,
  required int paragraphIndentLength,
  required int displayOffset,
}) {
  if (pagedPages.isNotEmpty) {
    return resolveChapterOffsetFromPagedDisplayOffset(
      paragraphs: paragraphs,
      pagedPages: pagedPages,
      currentPageIndex: currentPageIndex,
      paragraphIndentLength: paragraphIndentLength,
      displayOffset: displayOffset,
    );
  }
  if (paragraphs.isEmpty) {
    return displayOffset;
  }

  final totalDisplayLength = paragraphs.fold<int>(
    0,
    (sum, item) => sum + item.length + paragraphIndentLength,
  );
  var remaining = _clampInt(displayOffset, 0, totalDisplayLength);
  var chapterOffset = 0;
  for (var i = 0; i < paragraphs.length; i++) {
    final rawLength = paragraphs[i].length;
    final displayLength = rawLength + paragraphIndentLength;
    if (remaining <= displayLength) {
      final localRaw = _clampInt(
        remaining - paragraphIndentLength,
        0,
        rawLength,
      );
      return chapterOffset + localRaw;
    }
    remaining -= displayLength;
    chapterOffset += rawLength + 2;
  }

  final last = paragraphs.last;
  return (chapterOffset - 2 + last.length).clamp(0, 1 << 31).toInt();
}

int resolveChapterOffsetFromPagedDisplayOffset({
  required List<String> paragraphs,
  required List<List<ReaderPagedSlice>> pagedPages,
  required int currentPageIndex,
  required int paragraphIndentLength,
  required int displayOffset,
}) {
  if (paragraphs.isEmpty || pagedPages.isEmpty) {
    return displayOffset;
  }

  final pageIndex = currentPageIndex.clamp(0, pagedPages.length - 1);
  final page = pagedPages[pageIndex];
  if (page.isEmpty) {
    return displayOffset;
  }

  final starts = <int>[];
  var offset = 0;
  for (final paragraph in paragraphs) {
    starts.add(offset);
    offset += paragraph.length + 2;
  }

  var totalDisplayLength = 0;
  for (final slice in page) {
    final sliceIndent = slice.start == 0 ? paragraphIndentLength : 0;
    totalDisplayLength += (slice.end - slice.start) + sliceIndent;
  }

  var remaining = _clampInt(displayOffset, 0, totalDisplayLength);
  for (final slice in page) {
    final paragraphIndex = slice.paragraphIndex;
    if (paragraphIndex < 0 || paragraphIndex >= paragraphs.length) {
      continue;
    }

    final sliceIndent = slice.start == 0 ? paragraphIndentLength : 0;
    final sliceDisplayLength = (slice.end - slice.start) + sliceIndent;
    if (remaining <= sliceDisplayLength) {
      final localRaw = _clampInt(
        remaining - sliceIndent,
        0,
        slice.end - slice.start,
      );
      return starts[paragraphIndex] + slice.start + localRaw;
    }
    remaining -= sliceDisplayLength;
  }

  final lastSlice = page.last;
  final safeParagraphIndex = lastSlice.paragraphIndex.clamp(
    0,
    paragraphs.length - 1,
  );
  return starts[safeParagraphIndex] + lastSlice.end;
}

int resolveChapterOffsetFromParagraph({
  required List<String> paragraphs,
  required int paragraphIndex,
  required int paragraphOffset,
}) {
  if (paragraphs.isEmpty) {
    return paragraphOffset;
  }

  final safeIndex = _clampInt(paragraphIndex, 0, paragraphs.length - 1);
  var offset = 0;
  for (var i = 0; i < safeIndex; i++) {
    offset += paragraphs[i].length + 2;
  }
  offset += _clampInt(paragraphOffset, 0, paragraphs[safeIndex].length);
  return offset;
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

import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/bookmark.dart';
import 'package:shuxiang_reading_next/features/reader/presentation/reader_bookmark_range_presenter.dart';

void main() {
  group('ReaderBookmarkRangePresenter', () {
    const presenter = ReaderBookmarkRangePresenter();

    test('splits bookmark ranges across paragraphs', () {
      final bookmark = _bookmark(startOffset: 3, endOffset: 9);

      final ranges = presenter.buildRangesByParagraph(
        bookmarks: <Bookmark>[bookmark],
        paragraphs: const <String>['hello', 'world'],
        fallbackContent: '',
      );

      expect(ranges[0], hasLength(1));
      expect(ranges[0]!.single.start, 3);
      expect(ranges[0]!.single.end, 5);
      expect(ranges[1], hasLength(1));
      expect(ranges[1]!.single.start, 0);
      expect(ranges[1]!.single.end, 2);
    });

    test('resolves highlight state from token and style flags', () {
      expect(presenter.bookmarkHasHighlight(_bookmark()), isTrue);
      expect(
        presenter.bookmarkHasHighlight(
          _bookmark(
            color: ReaderBookmarkRangePresenter.defaultNoHighlightToken,
          ),
        ),
        isFalse,
      );
      expect(presenter.bookmarkHasHighlight(_bookmark(isWavy: true)), isFalse);
    });

    test('finds matching bookmark in current chapter', () {
      final target = _bookmark(id: 'target', chapterId: 'chapter-1');
      final other = _bookmark(id: 'other', chapterId: 'chapter-2');

      final found = presenter.findBookmarkByOffsets(
        bookmarks: <Bookmark>[other, target],
        chapterId: 'chapter-1',
        chapterIndex: 0,
        startOffset: 0,
        endOffset: 4,
      );

      expect(found?.id, 'target');
    });
  });
}

Bookmark _bookmark({
  String id = 'bookmark-1',
  String chapterId = 'chapter-1',
  int chapterIndex = 0,
  int startOffset = 0,
  int endOffset = 4,
  String? color,
  bool isUnderline = false,
  bool isWavy = false,
}) {
  final now = DateTime(2026, 6, 13);
  return Bookmark(
    id: id,
    bookId: 'book-1',
    chapterId: chapterId,
    chapterIndex: chapterIndex,
    startOffset: startOffset,
    endOffset: endOffset,
    snippet: 'text',
    createdAt: now,
    updatedAt: now,
    color: color,
    isUnderline: isUnderline,
    isWavy: isWavy,
  );
}

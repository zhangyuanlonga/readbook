import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/bookmark.dart';
import 'package:shuxiang_reading_next/features/reader/presentation/reader_annotation_presenter.dart';
import 'package:shuxiang_reading_next/features/reader/presentation/reader_selection_state.dart';

void main() {
  group('ReaderAnnotationPresenter', () {
    const presenter = ReaderAnnotationPresenter();

    test('resolves toolbar state and actions from selection', () {
      final bookmark = Bookmark(
        id: 'b1',
        bookId: 'book-1',
        chapterId: 'c1',
        chapterIndex: 0,
        startOffset: 1,
        endOffset: 3,
        snippet: '片段',
        createdAt: DateTime(2026, 4, 26, 12),
        updatedAt: DateTime(2026, 4, 26, 12),
      );
      final state = const ReaderSelectionState().activate(
        startOffset: 1,
        endOffset: 3,
        snippet: '片段',
        highlight: true,
        bold: false,
        underline: false,
        wavy: false,
      );

      final resolved = presenter.resolveState(
        selectionState: state,
        existingBookmark: bookmark,
      );

      expect(resolved.toolbarState.hasSelection, isTrue);
      expect(resolved.toolbarState.existingBookmark, bookmark);
      expect(resolved.actions, isNotEmpty);
    });
  });
}

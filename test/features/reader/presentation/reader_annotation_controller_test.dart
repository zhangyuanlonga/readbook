import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shuxiang_reading_next/domain/entities/bookmark.dart';
import 'package:shuxiang_reading_next/features/reader/presentation/reader_annotation_controller.dart';
import 'package:shuxiang_reading_next/features/reader/presentation/reader_selection_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReaderAnnotationController', () {
    const controller = ReaderAnnotationController();

    test('buildRangesByParagraph splits cross-paragraph bookmark ranges', () {
      final bookmark = Bookmark(
        id: 'bookmark-1',
        bookId: 'book-1',
        chapterId: 'chapter-1',
        chapterIndex: 0,
        startOffset: 1,
        endOffset: 6,
        snippet: 'bcde',
        createdAt: DateTime(2026, 4, 26, 10),
        updatedAt: DateTime(2026, 4, 26, 10),
        isBold: true,
        color: readerBookmarkDefaultHighlightToken,
      );

      final result = controller.buildRangesByParagraph(
        paragraphs: const <String>['abc', 'de'],
        bookmarks: <Bookmark>[bookmark],
      );

      expect(result.keys, containsAll(<int>[0, 1]));
      expect(result[0], hasLength(1));
      expect(result[0]!.single.start, 1);
      expect(result[0]!.single.end, 3);
      expect(result[0]!.single.isBold, isTrue);
      expect(result[1], hasLength(1));
      expect(result[1]!.single.start, 0);
      expect(result[1]!.single.end, 1);
    });

    test('resolveTapSelection returns activation for paragraph tap', () {
      const textStyle = TextStyle(fontSize: 18, height: 1.6);
      final activation = controller.resolveTapSelection(
        ReaderAnnotationHitTestRequest(
          paragraphIndex: 2,
          paragraphText: '测试文本',
          visibleStart: 0,
          visibleEnd: 4,
          displayText: '测试文本',
          indentLength: 0,
          ranges: const <ReaderAnnotationRange>[
            ReaderAnnotationRange(
              1,
              2,
              hasHighlight: true,
              isBold: true,
              isUnderline: false,
              isWavy: false,
            ),
          ],
          localPosition: const Offset(24, 8),
          maxWidth: 300,
          textStyle: textStyle,
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.start,
          offsetResolver: ({
            required int paragraphIndex,
            required int paragraphOffset,
          }) {
            return paragraphIndex * 100 + paragraphOffset;
          },
        ),
      );

      expect(activation, isNotNull);
      expect(activation!.paragraphIndex, 2);
      expect(activation.paragraphStart, 1);
      expect(activation.paragraphEnd, 2);
      expect(activation.chapterStartOffset, 201);
      expect(activation.chapterEndOffset, 202);
      expect(activation.snippet, '试');
      expect(activation.isBold, isTrue);
      expect(activation.hasHighlight, isTrue);
    });

    test('resolveTapSelection clamps annotations to visible slice', () {
      const textStyle = TextStyle(fontSize: 18, height: 1.6);
      final activation = controller.resolveTapSelection(
        ReaderAnnotationHitTestRequest(
          paragraphIndex: 0,
          paragraphText: '0123456789',
          visibleStart: 3,
          visibleEnd: 7,
          displayText: '3456',
          indentLength: 0,
          ranges: const <ReaderAnnotationRange>[
            ReaderAnnotationRange(
              1,
              5,
              hasHighlight: false,
              isBold: false,
              isUnderline: true,
              isWavy: false,
            ),
          ],
          localPosition: const Offset(12, 8),
          maxWidth: 300,
          textStyle: textStyle,
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.start,
          offsetResolver: ({
            required int paragraphIndex,
            required int paragraphOffset,
          }) {
            return paragraphOffset;
          },
        ),
      );

      expect(activation, isNotNull);
      expect(activation!.paragraphStart, 3);
      expect(activation.paragraphEnd, 5);
      expect(activation.snippet, '34');
      expect(activation.isUnderline, isTrue);
    });

    test('resolveSelectionStyleByOverlap suppresses underline when wavy exists', () {
      final bookmarks = <Bookmark>[
        Bookmark(
          id: 'bookmark-1',
          bookId: 'book-1',
          chapterId: 'chapter-1',
          chapterIndex: 0,
          startOffset: 10,
          endOffset: 20,
          snippet: 'a',
          createdAt: DateTime(2026, 4, 26, 10),
          updatedAt: DateTime(2026, 4, 26, 10),
          isUnderline: true,
          color: readerBookmarkNoHighlightToken,
        ),
        Bookmark(
          id: 'bookmark-2',
          bookId: 'book-1',
          chapterId: 'chapter-1',
          chapterIndex: 0,
          startOffset: 15,
          endOffset: 18,
          snippet: 'b',
          createdAt: DateTime(2026, 4, 26, 10),
          updatedAt: DateTime(2026, 4, 26, 10),
          isWavy: true,
          color: readerBookmarkDefaultHighlightToken,
        ),
      ];

      final style = controller.resolveSelectionStyleByOverlap(
        startOffset: 16,
        endOffset: 17,
        bookmarks: bookmarks,
      );

      expect(style.highlight, isTrue);
      expect(style.wavy, isTrue);
      expect(style.underline, isFalse);
    });

    test('buildToolbarActions and buildBookmarkForSelection expose md3-like action model', () {
      final existingBookmark = Bookmark(
        id: 'bookmark-1',
        bookId: 'book-1',
        chapterId: 'chapter-1',
        chapterIndex: 0,
        startOffset: 12,
        endOffset: 16,
        snippet: Bookmark.buildSnippetPayload(quote: '片段', note: '旧笔记'),
        createdAt: DateTime(2026, 4, 26, 10),
        updatedAt: DateTime(2026, 4, 26, 10),
        color: readerBookmarkDefaultHighlightToken,
      );
      const selectionState = ReaderSelectionState(
        isActive: true,
        startOffset: 12,
        endOffset: 16,
        snippet: '片段',
        highlight: true,
        bold: true,
      );

      final toolbarState = controller.resolveToolbarState(
        selectionState: selectionState,
        existingBookmark: existingBookmark,
      );
      final actions = controller.buildToolbarActions(toolbarState);
      final bookmark = controller.buildBookmarkForSelection(
        ReaderAnnotationBookmarkSaveRequest(
          bookId: 'book-1',
          chapterId: 'chapter-1',
          chapterIndex: 0,
          selection: const ReaderSelectionSnapshot(
            startOffset: 12,
            endOffset: 16,
            snippet: '片段',
            hasHighlight: false,
            isBold: true,
            isUnderline: true,
            isWavy: true,
          ),
          bookmarkId: 'bookmark-new',
          timestamp: DateTime(2026, 4, 26, 11),
          existing: existingBookmark,
          note: '新笔记',
        ),
      );

      expect(toolbarState.hasExistingBookmark, isTrue);
      expect(
        actions
            .firstWhere(
              (action) =>
                  action.kind ==
                  ReaderAnnotationToolbarActionKind.saveOrRemoveBookmark,
            )
            .label,
        '删除灵感',
      );
      expect(
        actions
            .firstWhere(
              (action) =>
                  action.kind == ReaderAnnotationToolbarActionKind.editNote,
            )
            .label,
        '编辑笔记',
      );
      expect(bookmark, isNotNull);
      expect(bookmark!.isWavy, isTrue);
      expect(bookmark.isUnderline, isFalse);
      expect(bookmark.note, '新笔记');
      expect(bookmark.color, readerBookmarkNoHighlightToken);
      expect(bookmark.displaySnippet, '片段');
    });
  });
}

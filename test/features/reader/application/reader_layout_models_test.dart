import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/reader/domain/entities/reader_layout_models.dart';

void main() {
  group('ReaderLayout models', () {
    test('constructs a page with line and column metadata', () {
      const column = ReaderLayoutColumn(
        columnIndex: 0,
        kind: ReaderLayoutColumnKind.text,
        startOffset: 10,
        endOffset: 14,
        rect: ReaderLayoutRect(left: 0, top: 0, right: 120, bottom: 24),
        text: '测试文本',
      );
      const line = ReaderLayoutLine(
        lineIndex: 0,
        paragraphIndex: 1,
        text: '测试文本',
        chapterOffset: 10,
        pageOffset: 0,
        lineTop: 0,
        lineBase: 20,
        lineBottom: 24,
        columns: <ReaderLayoutColumn>[column],
        isParagraphEnd: true,
      );
      const page = ReaderLayoutPage(
        chapterId: 'chapter-1',
        chapterIndex: 0,
        pageIndex: 0,
        startOffset: 10,
        endOffset: 14,
        contentWidth: 320,
        contentHeight: 480,
        layoutSignature: 'sig',
        lines: <ReaderLayoutLine>[line],
      );

      expect(page.isEmpty, isFalse);
      expect(page.lineCount, 1);
      expect(line.height, 24);
      expect(line.endChapterOffset, 14);
      expect(column.rect.contains(dx: 12, dy: 12), isTrue);
    });

    test('guards line and column offset invariants', () {
      expect(
        () => ReaderLayoutColumn(
          columnIndex: 0,
          kind: ReaderLayoutColumnKind.text,
          startOffset: 4,
          endOffset: 3,
          rect: const ReaderLayoutRect(left: 0, top: 0, right: 1, bottom: 1),
        ),
        throwsAssertionError,
      );

      expect(
        () => ReaderLayoutLine(
          lineIndex: 0,
          paragraphIndex: 0,
          text: 'x',
          chapterOffset: 0,
          pageOffset: 0,
          lineTop: 10,
          lineBase: 8,
          lineBottom: 12,
        ),
        throwsAssertionError,
      );
    });

    test('supports collapsed and multi-line ranges', () {
      const start = ReaderLayoutPosition(
        pageIndex: 0,
        lineIndex: 0,
        columnIndex: 0,
        chapterOffset: 10,
      );
      const end = ReaderLayoutPosition(
        pageIndex: 0,
        lineIndex: 1,
        columnIndex: 0,
        chapterOffset: 20,
      );
      final collapsed = ReaderLayoutRange(start: start, end: start);
      final multiLine = ReaderLayoutRange(
        start: start,
        end: end,
        selectedText: '跨行内容',
      );

      expect(collapsed.isCollapsed, isTrue);
      expect(multiLine.isCollapsed, isFalse);
      expect(multiLine.spansMultipleLines, isTrue);
      expect(multiLine.spansMultiplePages, isFalse);
    });

    test('rejects reversed ranges', () {
      const start = ReaderLayoutPosition(
        pageIndex: 0,
        lineIndex: 2,
        columnIndex: 0,
        chapterOffset: 20,
      );
      const end = ReaderLayoutPosition(
        pageIndex: 0,
        lineIndex: 1,
        columnIndex: 0,
        chapterOffset: 10,
      );

      expect(
        () => ReaderLayoutRange(start: start, end: end),
        throwsAssertionError,
      );
    });
  });
}

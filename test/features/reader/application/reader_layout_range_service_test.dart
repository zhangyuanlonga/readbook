import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_layout_range_service.dart';
import 'package:shuxiang_reading_next/features/reader/domain/entities/reader_layout_models.dart';

void main() {
  group('ReaderLayoutRangeService', () {
    const service = ReaderLayoutRangeService();

    test('returns empty rects for empty layouts', () {
      final range = ReaderLayoutRange(
        start: const ReaderLayoutPosition(
          pageIndex: 0,
          lineIndex: 0,
          columnIndex: 0,
          chapterOffset: 0,
        ),
        end: const ReaderLayoutPosition(
          pageIndex: 0,
          lineIndex: 0,
          columnIndex: 0,
          chapterOffset: 0,
        ),
      );

      expect(service.rectsForRange(const <ReaderLayoutPage>[], range), isEmpty);
    });

    test('builds a single-line range rect', () {
      final range = ReaderLayoutRange(
        start: const ReaderLayoutPosition(
          pageIndex: 0,
          lineIndex: 0,
          columnIndex: 0,
          chapterOffset: 2,
        ),
        end: const ReaderLayoutPosition(
          pageIndex: 0,
          lineIndex: 0,
          columnIndex: 0,
          chapterOffset: 7,
        ),
      );

      final rects = service.rectsForRange(<ReaderLayoutPage>[_page()], range);

      expect(rects, hasLength(1));
      expect(rects.single.left, 20);
      expect(rects.single.right, 70);
      expect(rects.single.top, 0);
      expect(rects.single.bottom, 24);
    });

    test('builds rects across multiple lines', () {
      final range = ReaderLayoutRange(
        start: const ReaderLayoutPosition(
          pageIndex: 0,
          lineIndex: 0,
          columnIndex: 0,
          chapterOffset: 5,
        ),
        end: const ReaderLayoutPosition(
          pageIndex: 0,
          lineIndex: 1,
          columnIndex: 0,
          chapterOffset: 15,
        ),
      );

      final rects = service.rectsForRange(<ReaderLayoutPage>[_page()], range);

      expect(rects, hasLength(2));
      expect(rects.first.left, 50);
      expect(rects.first.right, 100);
      expect(rects.last.left, 0);
      expect(rects.last.right, 50);
    });

    test('returns a caret rect for collapsed ranges', () {
      final range = ReaderLayoutRange(
        start: const ReaderLayoutPosition(
          pageIndex: 0,
          lineIndex: 0,
          columnIndex: 0,
          chapterOffset: 5,
        ),
        end: const ReaderLayoutPosition(
          pageIndex: 0,
          lineIndex: 0,
          columnIndex: 0,
          chapterOffset: 5,
        ),
      );

      final rects = service.rectsForRange(<ReaderLayoutPage>[_page()], range);

      expect(rects, hasLength(1));
      expect(rects.single.left, 50);
      expect(rects.single.right, 51);
    });
  });
}

ReaderLayoutPage _page() {
  return const ReaderLayoutPage(
    chapterId: 'chapter-1',
    chapterIndex: 0,
    pageIndex: 0,
    startOffset: 0,
    endOffset: 20,
    contentWidth: 320,
    contentHeight: 480,
    layoutSignature: 'sig',
    lines: <ReaderLayoutLine>[
      ReaderLayoutLine(
        lineIndex: 0,
        paragraphIndex: 0,
        text: '0123456789',
        chapterOffset: 0,
        pageOffset: 0,
        lineTop: 0,
        lineBase: 18,
        lineBottom: 24,
        columns: <ReaderLayoutColumn>[
          ReaderLayoutColumn(
            columnIndex: 0,
            kind: ReaderLayoutColumnKind.text,
            startOffset: 0,
            endOffset: 10,
            rect: ReaderLayoutRect(left: 0, top: 0, right: 100, bottom: 24),
            text: '0123456789',
          ),
        ],
      ),
      ReaderLayoutLine(
        lineIndex: 1,
        paragraphIndex: 0,
        text: '0123456789',
        chapterOffset: 10,
        pageOffset: 10,
        lineTop: 30,
        lineBase: 48,
        lineBottom: 54,
        columns: <ReaderLayoutColumn>[
          ReaderLayoutColumn(
            columnIndex: 0,
            kind: ReaderLayoutColumnKind.text,
            startOffset: 10,
            endOffset: 20,
            rect: ReaderLayoutRect(left: 0, top: 30, right: 100, bottom: 54),
            text: '0123456789',
          ),
        ],
      ),
    ],
  );
}

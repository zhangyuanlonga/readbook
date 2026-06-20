import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_layout_hit_test_service.dart';
import 'package:shuxiang_reading_next/features/reader/domain/entities/reader_layout_models.dart';

void main() {
  group('ReaderLayoutHitTestService', () {
    const service = ReaderLayoutHitTestService();

    test('returns null for empty pages', () {
      const page = ReaderLayoutPage(
        chapterId: 'chapter-1',
        chapterIndex: 0,
        pageIndex: 0,
        startOffset: 0,
        endOffset: 0,
        contentWidth: 320,
        contentHeight: 480,
        layoutSignature: 'sig',
      );

      expect(service.hitTestPage(page, dx: 10, dy: 10), isNull);
    });

    test('hits line and column and resolves chapter offset', () {
      final page = _page();
      final result = service.hitTestPage(page, dx: 50, dy: 12);

      expect(result, isNotNull);
      expect(result!.line.lineIndex, 0);
      expect(result.column!.columnIndex, 0);
      expect(result.position.chapterOffset, 5);
      expect(result.position.pageIndex, 0);
    });

    test('uses nearest column when x is outside all column rects', () {
      final page = _pageWithTwoColumns();
      final result = service.hitTestPage(page, dx: 145, dy: 12);

      expect(result, isNotNull);
      expect(result!.column!.columnIndex, 1);
      expect(result.position.chapterOffset, 13);
    });

    test('maps chapter offsets to layout positions with clamping', () {
      final pages = <ReaderLayoutPage>[_page(), _page(pageIndex: 1, start: 20)];

      final before = service.chapterOffsetToPosition(pages, -10);
      final inside = service.chapterOffsetToPosition(pages, 25);
      final after = service.chapterOffsetToPosition(pages, 999);

      expect(before!.chapterOffset, 0);
      expect(before.pageIndex, 0);
      expect(inside!.chapterOffset, 25);
      expect(inside.pageIndex, 1);
      expect(after!.chapterOffset, 30);
      expect(after.pageIndex, 1);
    });

    test('maps positions back to chapter offsets with boundary defense', () {
      final pages = <ReaderLayoutPage>[_page(), _page(pageIndex: 1, start: 20)];

      final offset = service.positionToChapterOffset(
        const ReaderLayoutPosition(
          pageIndex: 99,
          lineIndex: 99,
          columnIndex: 99,
          chapterOffset: 999,
        ),
        layoutPages: pages,
      );

      expect(offset, 30);
    });
  });
}

ReaderLayoutPage _page({int pageIndex = 0, int start = 0}) {
  return ReaderLayoutPage(
    chapterId: 'chapter-$pageIndex',
    chapterIndex: 0,
    pageIndex: pageIndex,
    startOffset: start,
    endOffset: start + 10,
    contentWidth: 320,
    contentHeight: 480,
    layoutSignature: 'sig',
    lines: <ReaderLayoutLine>[
      ReaderLayoutLine(
        lineIndex: 0,
        paragraphIndex: 0,
        text: '0123456789',
        chapterOffset: start,
        pageOffset: 0,
        lineTop: 0,
        lineBase: 18,
        lineBottom: 24,
        columns: <ReaderLayoutColumn>[
          ReaderLayoutColumn(
            columnIndex: 0,
            kind: ReaderLayoutColumnKind.text,
            startOffset: start,
            endOffset: start + 10,
            rect: const ReaderLayoutRect(
              left: 0,
              top: 0,
              right: 100,
              bottom: 24,
            ),
            text: '0123456789',
          ),
        ],
      ),
    ],
  );
}

ReaderLayoutPage _pageWithTwoColumns() {
  return ReaderLayoutPage(
    chapterId: 'chapter-1',
    chapterIndex: 0,
    pageIndex: 0,
    startOffset: 0,
    endOffset: 20,
    contentWidth: 320,
    contentHeight: 480,
    layoutSignature: 'sig',
    lines: const <ReaderLayoutLine>[
      ReaderLayoutLine(
        lineIndex: 0,
        paragraphIndex: 0,
        text: '01234567890123456789',
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
          ReaderLayoutColumn(
            columnIndex: 1,
            kind: ReaderLayoutColumnKind.text,
            startOffset: 10,
            endOffset: 20,
            rect: ReaderLayoutRect(left: 120, top: 0, right: 220, bottom: 24),
            text: '0123456789',
          ),
        ],
      ),
    ],
  );
}

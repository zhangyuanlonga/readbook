import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_layout_render_model.dart';
import 'package:shuxiang_reading_next/features/reader/domain/entities/reader_layout_models.dart';

void main() {
  group('ReaderLayoutRenderModelBuilder', () {
    test('maps text and image columns to render fragments', () {
      final pages = const ReaderLayoutRenderModelBuilder().buildPages(
        <ReaderLayoutPage>[_page()],
      );

      expect(pages, hasLength(1));
      expect(pages.single.fragments, hasLength(2));
      expect(
        pages.single.fragments.first.kind,
        ReaderLayoutRenderFragmentKind.text,
      );
      expect(pages.single.fragments.first.text, '正文');
      expect(
        pages.single.fragments.last.kind,
        ReaderLayoutRenderFragmentKind.image,
      );
      expect(pages.single.fragments.last.payload['imageUrl'], 'image.png');
    });
  });
}

ReaderLayoutPage _page() {
  return const ReaderLayoutPage(
    chapterId: 'chapter-1',
    chapterIndex: 0,
    pageIndex: 0,
    startOffset: 0,
    endOffset: 3,
    contentWidth: 320,
    contentHeight: 480,
    layoutSignature: 'sig',
    lines: <ReaderLayoutLine>[
      ReaderLayoutLine(
        lineIndex: 0,
        paragraphIndex: 0,
        text: '正文',
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
            endOffset: 2,
            rect: ReaderLayoutRect(left: 0, top: 0, right: 40, bottom: 24),
            text: '正文',
          ),
        ],
      ),
      ReaderLayoutLine(
        lineIndex: 1,
        paragraphIndex: 1,
        text: '',
        chapterOffset: 2,
        pageOffset: 2,
        lineTop: 30,
        lineBase: 90,
        lineBottom: 90,
        columns: <ReaderLayoutColumn>[
          ReaderLayoutColumn(
            columnIndex: 0,
            kind: ReaderLayoutColumnKind.image,
            startOffset: 2,
            endOffset: 3,
            rect: ReaderLayoutRect(left: 0, top: 30, right: 100, bottom: 90),
            payload: <String, Object?>{'imageUrl': 'image.png'},
          ),
        ],
        isImage: true,
      ),
    ],
  );
}

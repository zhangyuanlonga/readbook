import 'package:shuxiang_reading_next/domain/entities/reader_document.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_document_render_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildReaderRenderBlockItems', () {
    test('preserves title, paragraph, list item and image ordering', () {
      final document = ReaderDocument(
        blocks: const <ReaderBlock>[
          ReaderTitleBlock(text: '第一章', level: 1),
          ReaderTextBlock(text: '正文段落'),
          ReaderListItemBlock(text: '列表项'),
          ReaderQuoteBlock(text: '引用块'),
          ReaderCaptionBlock(text: '图注'),
          ReaderFootnoteBlock(text: '脚注'),
          ReaderImageBlock(imageUrl: 'file:///tmp/p1.jpg'),
        ],
      );

      final items = buildReaderRenderBlockItems(document);

      expect(items, hasLength(7));
      expect(items[0], isA<ReaderRenderTextItem>());
      expect(
        (items[0] as ReaderRenderTextItem).kind,
        ReaderRenderTextKind.title,
      );
      expect((items[0] as ReaderRenderTextItem).paragraphIndex, 0);
      expect(
        (items[1] as ReaderRenderTextItem).kind,
        ReaderRenderTextKind.paragraph,
      );
      expect((items[1] as ReaderRenderTextItem).paragraphIndex, 1);
      expect(
        (items[2] as ReaderRenderTextItem).kind,
        ReaderRenderTextKind.listItem,
      );
      expect((items[2] as ReaderRenderTextItem).paragraphIndex, 2);
      expect(
        (items[3] as ReaderRenderTextItem).kind,
        ReaderRenderTextKind.quote,
      );
      expect(
        (items[4] as ReaderRenderTextItem).kind,
        ReaderRenderTextKind.caption,
      );
      expect(
        (items[5] as ReaderRenderTextItem).kind,
        ReaderRenderTextKind.footnote,
      );
      expect(items[6], isA<ReaderRenderImageItem>());
      expect(items[6].paragraphIndex, isNull);
    });

    test('builds text item index by paragraph index', () {
      final document = ReaderDocument(
        blocks: const <ReaderBlock>[
          ReaderTitleBlock(text: '第一章'),
          ReaderTextBlock(text: '正文段落'),
          ReaderImageBlock(imageUrl: 'file:///tmp/p1.jpg'),
          ReaderFootnoteBlock(text: '脚注'),
        ],
      );

      final items = buildReaderRenderBlockItems(document);
      final index = buildReaderRenderTextItemIndex(items);

      expect(index.length, 3);
      expect(index[0]?.kind, ReaderRenderTextKind.title);
      expect(index[1]?.kind, ReaderRenderTextKind.paragraph);
      expect(index[2]?.kind, ReaderRenderTextKind.footnote);
    });
  });
}

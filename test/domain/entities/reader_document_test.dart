import 'package:flutter_appread/domain/entities/reader_document.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReaderDocument', () {
    test('builds mixed text and image document from compatibility content', () {
      final document = ReaderDocument.fromContent(
        content:
            '第一段文字。\n\n${ReaderDocument.inlineImageMarkerPrefix}https://example.com/1.jpg${ReaderDocument.inlineImageMarkerSuffix}\n\n第二段文字。',
      );

      expect(document.isPureImageDocument, isFalse);
      expect(document.blocks, hasLength(3));
      expect(document.blocks[0], isA<ReaderTextBlock>());
      expect(document.blocks[1], isA<ReaderImageBlock>());
      expect(document.blocks[2], isA<ReaderTextBlock>());
      expect(document.imageUrls, <String>['https://example.com/1.jpg']);
      expect(document.paragraphs, hasLength(3));
      expect(document.compatibilityContent, contains('第一段文字。'));
      expect(document.compatibilityContent, contains('第二段文字。'));
    });

    test('treats pure image chapters as image-only document', () {
      final document = ReaderDocument.fromContent(
        content: '',
        imageUrls: const <String>[
          'https://example.com/1.jpg',
          'https://example.com/2.jpg',
        ],
      );

      expect(document.isPureImageDocument, isTrue);
      expect(document.blocks, everyElement(isA<ReaderImageBlock>()));
      expect(document.imageUrls, hasLength(2));
      expect(
        document.paragraphs.first,
        ReaderDocument.inlineImageParagraph('https://example.com/1.jpg'),
      );
    });

    test('supports json round trip and debug summary', () {
      final document = ReaderDocument(
        blocks: const <ReaderBlock>[
          ReaderTitleBlock(text: '第一章'),
          ReaderTextBlock(text: '正文'),
          ReaderListItemBlock(text: '条目'),
          ReaderQuoteBlock(text: '引用'),
          ReaderCaptionBlock(text: '图注'),
          ReaderFootnoteBlock(text: '脚注内容'),
          ReaderImageBlock(imageUrl: 'https://example.com/1.jpg'),
        ],
      );

      final restored = ReaderDocument.fromJson(document.toJson());

      expect(restored.blocks, hasLength(7));
      expect(restored.blocks.first, isA<ReaderTitleBlock>());
      expect(restored.blocks[1], isA<ReaderTextBlock>());
      expect(restored.blocks[2], isA<ReaderListItemBlock>());
      expect(restored.blocks[3], isA<ReaderQuoteBlock>());
      expect(restored.blocks[4], isA<ReaderCaptionBlock>());
      expect(restored.blocks[5], isA<ReaderFootnoteBlock>());
      expect(restored.blocks[6], isA<ReaderImageBlock>());
      expect(restored.debugSummary, contains('blocks=7'));
      expect(restored.debugSummary, contains('lists=1'));
      expect(restored.debugSummary, contains('quotes=1'));
      expect(restored.debugSummary, contains('captions=1'));
      expect(restored.debugSummary, contains('footnotes=1'));
      expect(restored.debugSummary, contains('images=1'));
    });

    test('serializes footnote blocks into compatibility paragraphs', () {
      final document = ReaderDocument(
        blocks: const <ReaderBlock>[
          ReaderTextBlock(text: '正文段落'),
          ReaderFootnoteBlock(text: '这是脚注'),
        ],
      );

      expect(document.paragraphs, containsAll(<String>['正文段落', '注: 这是脚注']));
      expect(document.compatibilityContent, contains('注: 这是脚注'));
    });

    test('builds list and quote blocks from compatibility content markers', () {
      final document = ReaderDocument.fromContent(
        content: '• 第一项\n\n> 引用内容\n\n普通段落',
      );

      expect(document.blocks[0], isA<ReaderListItemBlock>());
      expect(document.blocks[1], isA<ReaderQuoteBlock>());
      expect(document.blocks[2], isA<ReaderTextBlock>());
      expect(document.paragraphs, containsAll(<String>['• 第一项', '引用内容']));
    });
  });
}

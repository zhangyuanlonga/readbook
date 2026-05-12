import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/reader_document.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_content_mode_resolver.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_content_session.dart';

void main() {
  group('ReaderContentModeResolver', () {
    const resolver = ReaderContentModeResolver();

    test('resolves mixed text with inline image as text mode', () {
      final document = ReaderDocument.fromContent(
        content: '第一段\n\n[[appread-image:https://example.com/1.jpg]]\n\n第二段',
      );

      expect(document.isPureImageDocument, isFalse);
      expect(resolver.resolveFromDocument(document), ReaderContentMode.text);
      expect(resolver.isComicDocument(document), isFalse);
    });

    test('resolves pure image document as comic mode', () {
      final document = ReaderDocument.fromContent(
        content: '',
        imageUrls: const <String>[
          'https://example.com/1.jpg',
          'https://example.com/2.jpg',
        ],
      );

      expect(document.isPureImageDocument, isTrue);
      expect(resolver.resolveFromDocument(document), ReaderContentMode.comic);
      expect(resolver.isComicDocument(document), isTrue);
    });
  });
}

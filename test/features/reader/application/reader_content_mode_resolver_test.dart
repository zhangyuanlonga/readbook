import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/reader_document.dart';
import 'package:shuxiang_reading_next/features/reader/application/chapter_content_service.dart';
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

    test('prefers explicit audio signal over document fallback', () {
      final result = ChapterContentResult(
        content: '',
        fromCache: false,
        contentType: 'audio',
        audioUrl: 'https://cdn.example/chapter-1.mp3',
      );

      expect(
        resolver.resolveFromChapterResult(result),
        ReaderContentMode.audio,
      );
    });

    test('prefers explicit manga signal over text document fallback', () {
      final result = ChapterContentResult(
        content: '这是兼容文本',
        fromCache: false,
        contentType: 'manga',
        imageUrls: const <String>['https://img.example/1.jpg'],
      );

      expect(result.imageUrls, hasLength(1));
      expect(result.document.isPureImageDocument, isTrue);
      expect(
        resolver.resolveFromChapterResult(result),
        ReaderContentMode.comic,
      );
    });

    test('resolves explicit pdf signal as hybrid mode', () {
      final result = ChapterContentResult(
        content: '',
        fromCache: false,
        contentType: 'pdf',
      );

      expect(
        resolver.resolveFromChapterResult(result),
        ReaderContentMode.hybrid,
      );
      expect(resolver.resolveHybridSubMode(result), ReaderHybridSubMode.pdf);
    });
  });
}

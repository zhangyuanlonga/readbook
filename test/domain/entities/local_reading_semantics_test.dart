import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/local_book.dart';
import 'package:shuxiang_reading_next/domain/entities/local_chapter.dart';
import 'package:shuxiang_reading_next/domain/entities/reader_document.dart';

void main() {
  group('LocalBook semantics', () {
    final now = DateTime.parse('2026-04-21T12:00:00.000Z');

    test('exposes ready and asset-directory semantics', () {
      final book = LocalBook(
        id: 'local_1',
        title: '测试',
        format: LocalBookFormat.epub,
        storagePath: '/tmp/test.epub',
        fileSize: 1,
        createdAt: now,
        updatedAt: now,
        indexStatus: LocalBookIndexStatus.ready,
        chapterCount: 3,
      );

      expect(book.isReadableReady, isTrue);
      expect(book.needsIndex, isFalse);
      expect(book.requiresManagedAssetDirectory, isTrue);
      expect(book.supportsBootstrapPreview, isFalse);
      expect(book.format.displayLabel, 'EPUB');
    });
  });

  group('LocalChapter semantics', () {
    final now = DateTime.parse('2026-04-21T12:00:00.000Z');

    test('treats document or text as readable payload', () {
      final chapter = LocalChapter(
        id: 'chapter_1',
        bookId: 'book_1',
        chapterIndex: 0,
        title: '第一章',
        content: '',
        document: ReaderDocument(
          blocks: const <ReaderBlock>[ReaderTextBlock(text: '正文')],
        ),
        createdAt: now,
        updatedAt: now,
      );

      expect(chapter.hasStructuredContent, isTrue);
      expect(chapter.hasReadablePayload, isTrue);
      expect(chapter.hasOffsetRange, isFalse);
    });
  });
}

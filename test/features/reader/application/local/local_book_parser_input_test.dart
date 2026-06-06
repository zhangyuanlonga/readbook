import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/local_book.dart';
import 'package:shuxiang_reading_next/features/reader/application/local/local_book_parser.dart';

void main() {
  group('LocalBookParserInput', () {
    final now = DateTime(2026, 6, 6);

    test('treats identical source and storage path as managed file input', () {
      final input = LocalBookParserInput.fromBook(
        LocalBook(
          id: 'book',
          title: 'Book',
          format: LocalBookFormat.txt,
          storagePath: '/managed/book.txt',
          sourcePath: '/managed/book.txt',
          fileSize: 12,
          createdAt: now,
          updatedAt: now,
        ),
      );

      expect(input.source, LocalBookParserInputSource.managedFile);
      expect(input.usesPathBackedFile, isTrue);
    });

    test('keeps native source path semantics when import source differs', () {
      final input = LocalBookParserInput.fromBook(
        LocalBook(
          id: 'book',
          title: 'Book',
          format: LocalBookFormat.epub,
          storagePath: '/managed/book.epub',
          sourcePath: '/Users/me/Downloads/book.epub',
          fileSize: 12,
          createdAt: now,
          updatedAt: now,
        ),
      );

      expect(input.source, LocalBookParserInputSource.nativeFilePath);
      expect(input.displayPath, '/managed/book.epub');
    });

    test('supports web uploaded bytes without path backed assumptions', () {
      final input = LocalBookParserInput(
        book: LocalBook(
          id: 'book',
          title: 'Book',
          format: LocalBookFormat.txt,
          storagePath: 'browser-upload/book.txt',
          fileSize: 12,
          createdAt: now,
          updatedAt: now,
        ),
        source: LocalBookParserInputSource.webUploadedBytes,
        bytes: const [1, 2, 3],
      );

      expect(input.hasBytes, isTrue);
      expect(input.usesPathBackedFile, isFalse);
    });
  });
}

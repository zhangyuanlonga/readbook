import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/book_metadata_override.dart';
import 'package:shuxiang_reading_next/domain/entities/bookshelf_book.dart';
import 'package:shuxiang_reading_next/domain/entities/local_book.dart';
import 'package:shuxiang_reading_next/domain/entities/reading_record.dart';
import 'package:shuxiang_reading_next/features/book/application/book_metadata_presentation_resolver.dart';

void main() {
  late Directory tempDir;
  late File customCoverFile;
  const resolver = BookMetadataPresentationResolver();
  final now = DateTime.parse('2026-04-27T12:00:00.000Z');

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync(
      'book_metadata_presentation_resolver_test_',
    );
    customCoverFile = File('${tempDir.path}/custom.png')
      ..writeAsBytesSync(const <int>[1, 2, 3]);
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('resolveBookshelfBook prefers override cover and metadata', () {
    final presentation = resolver.resolveBookshelfBook(
      book: BookshelfBook(
        bookId: 'book_1',
        sourceId: 'source_a',
        title: '原始标题',
        detailUrl: 'https://example.com/book/1',
        addedAt: now,
        author: '原始作者',
        coverUrl: 'https://example.com/cover.jpg',
      ),
      localBook: LocalBook(
        id: 'book_1',
        title: '本地标题',
        format: LocalBookFormat.epub,
        storagePath: '/tmp/book.epub',
        fileSize: 1,
        createdAt: now,
        updatedAt: now,
        author: '本地作者',
      ),
      metadataOverride: BookMetadataOverride.forRemote(
        sourceId: 'source_a',
        detailUrl: 'https://example.com/book/1',
        title: '覆盖标题',
        author: '覆盖作者',
        coverPath: customCoverFile.path,
        createdAt: now,
        updatedAt: now,
      ),
    );

    expect(presentation.displayTitle, '覆盖标题');
    expect(presentation.displayAuthor, '覆盖作者');
    expect(presentation.customCoverPath, customCoverFile.path);
    expect(
      presentation.displayCoverSource,
      BookMetadataPresentationCoverSource.overrideCustom,
    );
    expect(
      presentation.displayCover,
      Uri.file(customCoverFile.path).toString(),
    );
  });

  test(
    'resolveReadingRecord falls back to record values when no overrides',
    () {
      final presentation = resolver.resolveReadingRecord(
        record: ReadingRecord(
          bookId: 'book_2',
          sourceId: 'source_b',
          detailUrl: 'https://example.com/book/2',
          bookTitle: '记录标题',
          bookAuthor: '记录作者',
          coverUrl: 'https://example.com/record-cover.jpg',
          lastReadAt: now,
        ),
      );

      expect(presentation.displayTitle, '记录标题');
      expect(presentation.displayAuthor, '记录作者');
      expect(
        presentation.displayCoverSource,
        BookMetadataPresentationCoverSource.remote,
      );
      expect(presentation.displayCover, 'https://example.com/record-cover.jpg');
    },
  );
}

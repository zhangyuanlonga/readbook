import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_appread/domain/entities/local_book.dart';
import 'package:flutter_appread/features/reader/application/local/epub_local_book_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EpubLocalBookParser', () {
    late Directory tempDir;
    const parser = EpubLocalBookParser();

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('epub_local_parser_test');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('extracts readable html chapters from epub zip', () async {
      final archive =
          Archive()
            ..addFile(
              ArchiveFile(
                'OPS/chapter1.xhtml',
                0,
                utf8.encode(
                  '<html><body><h1>第一章</h1><p>第一章内容第一章内容第一章内容第一章内容第一章内容第一章内容。</p></body></html>',
                ),
              ),
            )
            ..addFile(
              ArchiveFile(
                'OPS/chapter2.xhtml',
                0,
                utf8.encode(
                  '<html><body><h1>第二章</h1><p>第二章内容第二章内容第二章内容第二章内容第二章内容第二章内容。</p></body></html>',
                ),
              ),
            );

      final encoded = ZipEncoder().encode(archive);
      expect(encoded, isNotNull);

      final file = File('${tempDir.path}/sample.epub');
      await file.writeAsBytes(encoded!);

      final now = DateTime.parse('2026-02-23T12:00:00.000Z');
      final result = await parser.parse(
        LocalBook(
          id: 'local_epub_1',
          title: 'epub测试',
          format: LocalBookFormat.epub,
          storagePath: file.path,
          fileSize: await file.length(),
          createdAt: now,
          updatedAt: now,
        ),
      );

      expect(result.chapters, hasLength(2));
      expect(result.chapters.first.title, contains('第一章'));
      expect(result.chapters.last.title, contains('第二章'));
    });
  });
}

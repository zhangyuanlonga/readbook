import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/local_book.dart';
import 'package:shuxiang_reading_next/features/reader/application/local/html_local_book_parser.dart';

void main() {
  group('HtmlLocalBookParser', () {
    late Directory tempDir;
    const parser = HtmlLocalBookParser();

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('html_local_parser_test');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'splits chapters by headings and materializes relative images',
      () async {
        final imageDir = Directory('${tempDir.path}/assets');
        await imageDir.create(recursive: true);
        final imageFile = File('${imageDir.path}/p1.png');
        await imageFile.writeAsBytes(const <int>[1, 2, 3], flush: true);
        final file = File('${tempDir.path}/sample.html');
        await file.writeAsString('''
<html>
  <head>
    <title>HTML 标题</title>
    <meta name="author" content="HTML 作者" />
    <meta name="description" content="HTML 简介" />
  </head>
  <body>
    <h1>第一章</h1>
    <p>第一章内容。</p>
    <h2>第二章</h2>
    <p>第二章内容。</p>
    <img src="assets/p1.png" />
  </body>
</html>
''');

        final now = DateTime.parse('2026-04-16T12:00:00.000Z');
        final result = await parser.parse(
          LocalBook(
            id: 'local_html_1',
            title: 'fallback',
            format: LocalBookFormat.html,
            storagePath: file.path,
            sourcePath: file.path,
            fileSize: await file.length(),
            createdAt: now,
            updatedAt: now,
          ),
        );

        expect(result.title, 'HTML 标题');
        expect(result.author, 'HTML 作者');
        expect(result.description, 'HTML 简介');
        expect(result.chapters, hasLength(2));
        expect(result.chapters.first.title, '第一章');
        expect(result.chapters.last.title, '第二章');
        expect(result.chapters.last.imageUrls, isNotEmpty);
        expect(File(result.coverPath!).existsSync(), isTrue);
      },
    );
  });
}

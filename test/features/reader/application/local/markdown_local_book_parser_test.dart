import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/local_book.dart';
import 'package:shuxiang_reading_next/features/reader/application/local/markdown_local_book_parser.dart';

void main() {
  group('MarkdownLocalBookParser', () {
    late Directory tempDir;
    const parser = MarkdownLocalBookParser();

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'markdown_local_parser_test',
      );
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'parses front matter metadata and explicit cover from markdown',
      () async {
        final imageDir = Directory('${tempDir.path}/images');
        await imageDir.create(recursive: true);
        final imageFile = File('${imageDir.path}/cover.png');
        await imageFile.writeAsBytes(const <int>[1, 2, 3, 4], flush: true);
        final file = File('${tempDir.path}/sample.md');
        await file.writeAsString('''
---
title: Front Matter 标题
author: Front Matter 作者
description: Front Matter 简介
cover: images/cover.png
---

# 第一章

第一章内容。

## 第二章

![插图](images/cover.png)

第二章内容。
''');

        final now = DateTime.parse('2026-04-16T12:00:00.000Z');
        final result = await parser.parse(
          LocalBook(
            id: 'local_md_1',
            title: 'fallback',
            format: LocalBookFormat.md,
            storagePath: file.path,
            sourcePath: file.path,
            fileSize: await file.length(),
            createdAt: now,
            updatedAt: now,
          ),
        );

        expect(result.title, 'Front Matter 标题');
        expect(result.author, 'Front Matter 作者');
        expect(result.description, 'Front Matter 简介');
        expect(result.chapters, hasLength(2));
        expect(result.chapters.first.content, contains('第一章内容'));
        expect(result.chapters.last.content, contains('第二章内容'));
        expect(result.chapters.last.imageUrls, isNotEmpty);
        expect(File(result.coverPath!).existsSync(), isTrue);
      },
    );
  });
}

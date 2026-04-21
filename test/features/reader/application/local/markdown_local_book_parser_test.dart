import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/core/errors/app_exception.dart';
import 'package:shuxiang_reading_next/core/errors/error_codes.dart';
import 'package:shuxiang_reading_next/core/errors/error_stage.dart';
import 'package:shuxiang_reading_next/domain/entities/local_book.dart';
import 'package:shuxiang_reading_next/features/reader/application/local/local_book_parser.dart';
import 'package:shuxiang_reading_next/features/reader/application/local/local_markup_book_parser_support.dart';
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

    test(
      'throws markdown-specific error when support reports empty content',
      () async {
        final file = File('${tempDir.path}/empty.md');
        await file.writeAsString('   \n\n   ');
        final parser = MarkdownLocalBookParser(
          support: const _ThrowingMarkupSupport(),
        );

        final now = DateTime.parse('2026-04-16T12:00:00.000Z');
        await expectLater(
          () async => parser.parse(
            LocalBook(
              id: 'local_md_empty_1',
              title: 'fallback',
              format: LocalBookFormat.md,
              storagePath: file.path,
              sourcePath: file.path,
              fileSize: await file.length(),
              createdAt: now,
              updatedAt: now,
            ),
          ),
          throwsA(
            isA<AppException>().having(
              (error) => error.briefMessage,
              'briefMessage',
              contains('Markdown 未解析出可读内容'),
            ),
          ),
        );
      },
    );
  });
}

class _ThrowingMarkupSupport extends LocalMarkupBookParserSupport {
  const _ThrowingMarkupSupport();

  @override
  Future<String> decodeTextFile(LocalBook book) async => '';

  @override
  Future<LocalParsedBook> parseHtmlBook({
    required LocalBook book,
    required String html,
    String? title,
    bool preferProvidedTitle = false,
    String? preferredAuthor,
    String? preferredDescription,
    String? preferredCoverSource,
    List<Directory> additionalBaseDirectories = const <Directory>[],
    bool resetAssetDirectory = true,
  }) async {
    throw AppException(
      code: ErrorCode.ruleMatchEmpty,
      stage: ErrorStage.content,
      briefMessage: '本地 HTML 未解析出可读内容。',
    );
  }
}

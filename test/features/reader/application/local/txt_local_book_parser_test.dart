import 'dart:io';

import 'package:flutter_appread/domain/entities/local_book.dart';
import 'package:flutter_appread/features/reader/application/local/txt_local_book_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TxtLocalBookParser', () {
    late Directory tempDir;
    const parser = TxtLocalBookParser();

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('txt_local_parser_test');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('splits chapters by title pattern', () async {
      final file = File('${tempDir.path}/book.txt');
      await file.writeAsString('''
第1章 初始
第一章内容。

第2章 继续
第二章内容。
''');

      final now = DateTime.parse('2026-02-23T12:00:00.000Z');
      final result = await parser.parse(
        LocalBook(
          id: 'local_txt_1',
          title: '测试书',
          format: LocalBookFormat.txt,
          storagePath: file.path,
          fileSize: await file.length(),
          createdAt: now,
          updatedAt: now,
        ),
      );

      expect(result.chapters, hasLength(2));
      expect(result.chapters.first.title, '第1章 初始');
      expect(result.chapters.last.title, '第2章 继续');
    });

    test('falls back to fixed chunks when title pattern missing', () async {
      final file = File('${tempDir.path}/chunk.txt');
      final content = List.filled(5000, '内容').join();
      await file.writeAsString(content);

      final now = DateTime.parse('2026-02-23T12:00:00.000Z');
      final result = await parser.parse(
        LocalBook(
          id: 'local_txt_2',
          title: '无章节书',
          format: LocalBookFormat.txt,
          storagePath: file.path,
          fileSize: await file.length(),
          createdAt: now,
          updatedAt: now,
        ),
      );

      expect(result.chapters.length, greaterThanOrEqualTo(2));
      expect(result.chapters.first.title, startsWith('第 '));
    });
  });
}

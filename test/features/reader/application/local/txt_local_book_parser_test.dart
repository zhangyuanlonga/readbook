import 'dart:io';

import 'package:charset/charset.dart';
import 'package:flutter_appread/domain/entities/local_book.dart';
import 'package:flutter_appread/features/reader/application/local/txt_local_book_parser.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('TxtLocalBookParser', () {
    late Directory tempDir;
    late TxtLocalBookParser parser;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      tempDir = await Directory.systemTemp.createTemp('txt_local_parser_test');
      parser = const TxtLocalBookParser();
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
      expect(result.charset, 'utf-8');
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

    test(
      'detects english chapter headings from built-in chapter patterns',
      () async {
        final file = File('${tempDir.path}/chapter_en.txt');
        await file.writeAsString('''
Chapter 1 Arrival
First chapter content.

Chapter 2 Return
Second chapter content.
''');

        final now = DateTime.parse('2026-02-23T12:00:00.000Z');
        final result = await parser.parse(
          LocalBook(
            id: 'local_txt_3',
            title: 'English Book',
            format: LocalBookFormat.txt,
            storagePath: file.path,
            fileSize: await file.length(),
            createdAt: now,
            updatedAt: now,
          ),
        );

        expect(result.chapters, hasLength(2));
        expect(result.chapters.first.title, 'Chapter 1 Arrival');
        expect(result.chapters.last.title, 'Chapter 2 Return');
      },
    );

    test(
      'creates a preface chapter when content exists before first heading',
      () async {
        final file = File('${tempDir.path}/preface.txt');
        await file.writeAsString('''
这是一本书的简介。
这里还有前言内容。

第1章 开始
第一章内容。
''');

        final now = DateTime.parse('2026-02-23T12:00:00.000Z');
        final result = await parser.parse(
          LocalBook(
            id: 'local_txt_4',
            title: '有前言的书',
            format: LocalBookFormat.txt,
            storagePath: file.path,
            fileSize: await file.length(),
            createdAt: now,
            updatedAt: now,
          ),
        );

        expect(result.chapters, hasLength(2));
        expect(result.chapters.first.title, '前言');
        expect(result.chapters.first.content, contains('简介'));
        expect(result.chapters.last.title, '第1章 开始');
      },
    );

    test('splits long chapters when splitLongChapter is enabled', () async {
      final file = File('${tempDir.path}/long_chapter.txt');
      final longContent = List.filled(60000, '内容').join('\n');
      await file.writeAsString('''
第1章 长章节
$longContent
''');

      final now = DateTime.parse('2026-02-23T12:00:00.000Z');
      final result = await parser.parse(
        LocalBook(
          id: 'local_txt_5',
          title: '长章节书',
          format: LocalBookFormat.txt,
          storagePath: file.path,
          fileSize: await file.length(),
          createdAt: now,
          updatedAt: now,
          splitLongChapter: true,
        ),
      );

      expect(result.chapters.length, greaterThan(1));
      expect(result.chapters.first.title, '第1章 长章节(1)');
    });

    test('detects gbk text without rewriting original bytes', () async {
      final file = File('${tempDir.path}/gbk_book.txt');
      final gbk = Charset.getByName('gbk');
      expect(gbk, isNotNull);

      const content = '第1章 开始\n第一章内容。\n\n第2章 继续\n第二章内容。';
      final rawBytes = gbk!.encode(content);
      await file.writeAsBytes(rawBytes, flush: true);

      final now = DateTime.parse('2026-02-23T12:00:00.000Z');
      final result = await parser.parse(
        LocalBook(
          id: 'local_txt_gbk',
          title: 'GBK 测试书',
          format: LocalBookFormat.txt,
          storagePath: file.path,
          fileSize: await file.length(),
          createdAt: now,
          updatedAt: now,
        ),
      );

      expect(result.charset, 'gbk');
      expect(result.chapters, hasLength(2));
      expect(await file.readAsBytes(), rawBytes);
    });

    test('detects utf-16be text without rewriting original bytes', () async {
      final file = File('${tempDir.path}/utf16be_book.txt');
      const content = '第1章 开始\n第一章内容。\n\n第2章 继续\n第二章内容。';
      final rawBytes = _encodeUtf16(content, littleEndian: false);
      await file.writeAsBytes(rawBytes, flush: true);

      final now = DateTime.parse('2026-02-23T12:00:00.000Z');
      final result = await parser.parse(
        LocalBook(
          id: 'local_txt_utf16be',
          title: 'UTF16BE 测试书',
          format: LocalBookFormat.txt,
          storagePath: file.path,
          fileSize: await file.length(),
          createdAt: now,
          updatedAt: now,
        ),
      );

      expect(result.charset, 'utf-16be');
      expect(result.chapters, hasLength(2));
      expect(result.chapters.first.title, '第1章 开始');
      expect(await file.readAsBytes(), rawBytes);
    });

    test(
      'detects utf-16le with bom without rewriting original bytes',
      () async {
        final file = File('${tempDir.path}/utf16le_bom_book.txt');
        const content = '第1章 开始\n第一章内容。\n\n第2章 继续\n第二章内容。';
        final rawBytes = _encodeUtf16(
          content,
          littleEndian: true,
          withBom: true,
        );
        await file.writeAsBytes(rawBytes, flush: true);

        final now = DateTime.parse('2026-02-23T12:00:00.000Z');
        final result = await parser.parse(
          LocalBook(
            id: 'local_txt_utf16le_bom',
            title: 'UTF16LE BOM 测试书',
            format: LocalBookFormat.txt,
            storagePath: file.path,
            fileSize: await file.length(),
            createdAt: now,
            updatedAt: now,
          ),
        );

        expect(result.charset, 'utf-16le');
        expect(result.chapters, hasLength(2));
        expect(result.chapters.first.title, '第1章 开始');
        expect(result.chapters.first.content, contains('第一章内容'));
        expect(await file.readAsBytes(), rawBytes);
      },
    );

    test('detects big5 text without rewriting original bytes', () async {
      final file = File('${tempDir.path}/big5_book.txt');
      final big5 = Charset.getByName('big5');
      if (big5 == null) {
        return;
      }

      const content = '第1章 開始\n第一章內容。\n\n第2章 繼續\n第二章內容。';
      final rawBytes = big5.encode(content);
      await file.writeAsBytes(rawBytes, flush: true);

      final now = DateTime.parse('2026-02-23T12:00:00.000Z');
      final result = await parser.parse(
        LocalBook(
          id: 'local_txt_big5',
          title: 'Big5 測試書',
          format: LocalBookFormat.txt,
          storagePath: file.path,
          fileSize: await file.length(),
          createdAt: now,
          updatedAt: now,
        ),
      );

      expect(result.charset, 'big5');
      expect(result.chapters, hasLength(2));
      expect(result.chapters.first.title, '第1章 開始');
      expect(await file.readAsBytes(), rawBytes);
    });

    test('uses streaming index path for large utf8 books', () async {
      final file = File('${tempDir.path}/large_streaming.txt');
      final buffer = StringBuffer();
      for (var index = 1; index <= 120; index += 1) {
        buffer.writeln('第$index章 流式章节');
        for (var line = 0; line < 900; line += 1) {
          buffer.writeln('这是第$index章的正文内容，行号$line。');
        }
        buffer.writeln();
      }
      await file.writeAsString(buffer.toString());
      expect(await file.length(), greaterThan(1024 * 1024));

      final now = DateTime.parse('2026-02-23T12:00:00.000Z');
      final result = await parser.parse(
        LocalBook(
          id: 'local_txt_streaming',
          title: '大文件流式索引测试',
          format: LocalBookFormat.txt,
          storagePath: file.path,
          charset: 'utf-8',
          fileSize: await file.length(),
          createdAt: now,
          updatedAt: now,
        ),
      );

      expect(result.charset, 'utf-8');
      expect(result.chapters.length, greaterThan(50));
      expect(result.chapters.first.title, '第1章 流式章节');
      expect(result.chapters.first.content, isEmpty);
      expect(result.chapters.first.startOffset, isNotNull);
      expect(result.chapters.first.endOffset, isNotNull);
    });
  });
}

List<int> _encodeUtf16(
  String value, {
  required bool littleEndian,
  bool withBom = false,
}) {
  final bytes = <int>[];
  if (withBom) {
    if (littleEndian) {
      bytes.addAll(const <int>[0xFF, 0xFE]);
    } else {
      bytes.addAll(const <int>[0xFE, 0xFF]);
    }
  }
  for (final unit in value.codeUnits) {
    if (littleEndian) {
      bytes.add(unit & 0xFF);
      bytes.add((unit >> 8) & 0xFF);
    } else {
      bytes.add((unit >> 8) & 0xFF);
      bytes.add(unit & 0xFF);
    }
  }
  return bytes;
}

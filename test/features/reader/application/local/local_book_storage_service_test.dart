import 'dart:io';

import 'package:charset/charset.dart';
import 'package:shuxiang_reading_next/domain/entities/local_book.dart';
import 'package:shuxiang_reading_next/features/reader/application/local/local_book_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LocalBookStorageService', () {
    late Directory tempDir;
    late LocalBookStorageService storageService;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'local_book_storage_service_test',
      );
      storageService = LocalBookStorageService(
        supportDirectoryProvider: () async => tempDir,
      );
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'keeps raw bytes when preferred charset is explicitly provided',
      () async {
        final gbk = Charset.getByName('gbk');
        expect(gbk, isNotNull);

        const content = '第1章 开始\n正文内容。';
        final rawBytes = gbk!.encode(content);
        final sourceFile = File('${tempDir.path}/source_gbk.txt');
        await sourceFile.writeAsBytes(rawBytes, flush: true);
        final targetFile = File('${tempDir.path}/copy_gbk.txt');

        final result = await storageService.copyIntoStorage(
          sourceFile: sourceFile,
          targetFile: targetFile,
          format: LocalBookFormat.txt,
          sourcePath: sourceFile.path,
          bookId: 'local_storage_1',
          preferredCharset: 'gbk',
        );

        expect(await targetFile.readAsBytes(), rawBytes);
        expect(result.normalizedCharset, anyOf('gbk', 'gb18030'));
        expect(result.originalCharset, anyOf('gbk', 'gb18030'));
        expect(result.convertedToUtf8, isFalse);
      },
    );

    test(
      'detects gbk from middle and tail samples when large txt head is ascii',
      () async {
        final gbk = Charset.getByName('gbk');
        expect(gbk, isNotNull);

        final sourceFile = File('${tempDir.path}/ascii_head_gbk_body.txt');
        final header = List<int>.filled(24000, 'A'.codeUnitAt(0));
        final bodyText = List<String>.generate(
          50000,
          (index) => '第${index + 1}章 正文内容测试。',
        ).join('\n');
        final bodyBytes = gbk!.encode(bodyText);
        expect(header.length + bodyBytes.length, greaterThan(1024 * 1024));
        await sourceFile.writeAsBytes(<int>[
          ...header,
          ...bodyBytes,
        ], flush: true);

        final targetFile = File('${tempDir.path}/ascii_head_gbk_body_copy.txt');
        final result = await storageService.copyIntoStorage(
          sourceFile: sourceFile,
          targetFile: targetFile,
          format: LocalBookFormat.txt,
          sourcePath: sourceFile.path,
          bookId: 'local_storage_ascii_gbk',
        );

        expect(await targetFile.readAsBytes(), await sourceFile.readAsBytes());
        expect(result.normalizedCharset, anyOf('gbk', 'gb18030'));
        expect(result.originalCharset, anyOf('gbk', 'gb18030'));
        expect(result.convertedToUtf8, isFalse);
      },
    );

    test(
      'keeps small utf16le txt raw bytes and freezes detected charset',
      () async {
        const content = '第1章 开始\n正文内容。';
        final rawBytes = _encodeUtf16(
          content,
          littleEndian: true,
          withBom: true,
        );
        final sourceFile = File('${tempDir.path}/source_utf16le.txt');
        await sourceFile.writeAsBytes(rawBytes, flush: true);
        final targetFile = File('${tempDir.path}/copy_utf16le.txt');

        final result = await storageService.copyIntoStorage(
          sourceFile: sourceFile,
          targetFile: targetFile,
          format: LocalBookFormat.txt,
          sourcePath: sourceFile.path,
          bookId: 'local_storage_utf16le',
        );

        expect(await targetFile.readAsBytes(), rawBytes);
        expect(result.normalizedCharset, 'utf-16le');
        expect(result.originalCharset, 'utf-16le');
        expect(result.convertedToUtf8, isFalse);
      },
    );
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

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
        expect(result.normalizedCharset, 'gbk');
        expect(result.originalCharset, 'gbk');
        expect(result.convertedToUtf8, isFalse);
      },
    );
  });
}

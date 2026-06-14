import 'dart:io';

import 'package:charset/charset.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/core/errors/app_exception.dart';
import 'package:shuxiang_reading_next/data/datasources/local/app_database.dart';
import 'package:shuxiang_reading_next/data/repositories/local_book_repository_impl.dart';
import 'package:shuxiang_reading_next/domain/entities/local_book.dart';
import 'package:shuxiang_reading_next/features/reader/application/local/local_book_preview_service.dart';
import 'package:shuxiang_reading_next/features/reader/application/local/local_book_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocalBookPreviewService', () {
    late Directory tempDir;
    late AppDatabase database;
    late LocalBookRepositoryImpl repository;
    late LocalBookPreviewService previewService;
    late LocalBookStorageService storageService;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'local_book_preview_service_test',
      );
      database = AppDatabase(executor: NativeDatabase.memory());
      repository = LocalBookRepositoryImpl(database);
      storageService = LocalBookStorageService(
        supportDirectoryProvider: () async => tempDir,
      );
      previewService = LocalBookPreviewService(
        localBookRepository: repository,
        storageService: storageService,
      );
    });

    tearDown(() async {
      await database.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('exposes formal bootstrap preview capability for non-ready txt', () {
      final now = DateTime.parse('2026-03-21T12:00:00.000Z');
      final pendingTxt = LocalBook(
        id: 'local_pending_capability_1',
        title: '能力判断 TXT',
        format: LocalBookFormat.txt,
        storagePath: '/tmp/pending.txt',
        fileSize: 128,
        indexStatus: LocalBookIndexStatus.pending,
        createdAt: now,
        updatedAt: now,
      );
      final readyTxt = pendingTxt.copyWith(
        indexStatus: LocalBookIndexStatus.ready,
        chapterCount: 1,
      );
      final pendingEpub = pendingTxt.copyWith(format: LocalBookFormat.epub);

      expect(
        LocalBookPreviewService.canOpenBootstrapPreview(pendingTxt),
        isTrue,
      );
      expect(
        LocalBookPreviewService.canOpenBootstrapPreview(readyTxt),
        isFalse,
      );
      expect(
        LocalBookPreviewService.canOpenBootstrapPreview(pendingEpub),
        isFalse,
      );
    });

    test('loads bootstrap preview for pending txt book', () async {
      final file = File('${tempDir.path}/pending_bootstrap_book.txt');
      await file.writeAsString('''
第1章 开始
第一章正文内容。

第2章 继续
第二章正文内容。
''');

      final now = DateTime.parse('2026-03-21T12:00:00.000Z');
      await repository.upsertBook(
        LocalBook(
          id: 'local_pending_bootstrap_1',
          title: '待建立正文直读测试',
          format: LocalBookFormat.txt,
          storagePath: file.path,
          fileSize: await file.length(),
          indexStatus: LocalBookIndexStatus.pending,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final chapter = await previewService.loadTxtBootstrapPreview(
        bookId: 'local_pending_bootstrap_1',
      );

      expect(chapter.content, contains('第一章正文内容'));
      expect(chapter.chapterIndex, 0);
      expect(chapter.id, 'local_pending_bootstrap_1_bootstrap');
    });

    test('rejects non-txt bootstrap preview', () async {
      final file = File('${tempDir.path}/book.epub');
      await file.writeAsBytes(const <int>[1, 2, 3], flush: true);
      final now = DateTime.parse('2026-03-21T12:00:00.000Z');
      await repository.upsertBook(
        LocalBook(
          id: 'local_epub_preview_1',
          title: '非 TXT 预览测试',
          format: LocalBookFormat.epub,
          storagePath: file.path,
          fileSize: await file.length(),
          createdAt: now,
          updatedAt: now,
        ),
      );

      await expectLater(
        () => previewService.loadTxtBootstrapPreview(
          bookId: 'local_epub_preview_1',
        ),
        throwsA(
          isA<AppException>().having(
            (error) => error.briefMessage,
            'briefMessage',
            contains('仅 TXT'),
          ),
        ),
      );
    });

    test('loads bootstrap preview for gbk txt book', () async {
      final file = File('${tempDir.path}/pending_bootstrap_book_gbk.txt');
      final gbk = Charset.getByName('gbk');
      expect(gbk, isNotNull);
      await file.writeAsBytes(gbk!.encode('第1章 开始\n第一章正文内容。'), flush: true);

      final now = DateTime.parse('2026-03-21T12:00:00.000Z');
      await repository.upsertBook(
        LocalBook(
          id: 'local_pending_bootstrap_gbk_1',
          title: '待建立正文直读 GBK 测试',
          format: LocalBookFormat.txt,
          storagePath: file.path,
          fileSize: await file.length(),
          charset: 'gbk',
          indexStatus: LocalBookIndexStatus.pending,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final chapter = await previewService.loadTxtBootstrapPreview(
        bookId: 'local_pending_bootstrap_gbk_1',
      );

      expect(chapter.content, contains('第一章正文内容'));
    });

    test('loads bootstrap preview for utf16 txt book', () async {
      final file = File('${tempDir.path}/pending_bootstrap_book_utf16le.txt');
      await file.writeAsBytes(
        _encodeUtf16(
          '第1章 开始\n第一章 UTF-16 正文内容。',
          littleEndian: true,
          withBom: true,
        ),
        flush: true,
      );

      final now = DateTime.parse('2026-03-21T12:00:00.000Z');
      await repository.upsertBook(
        LocalBook(
          id: 'local_pending_bootstrap_utf16_1',
          title: '待建立正文直读 UTF-16 测试',
          format: LocalBookFormat.txt,
          storagePath: file.path,
          fileSize: await file.length(),
          charset: 'utf-16le',
          indexStatus: LocalBookIndexStatus.pending,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final chapter = await previewService.loadTxtBootstrapPreview(
        bookId: 'local_pending_bootstrap_utf16_1',
      );

      expect(chapter.content, contains('UTF-16 正文内容'));
    });

    test('loads bounded bootstrap preview for large txt book', () async {
      final file = File('${tempDir.path}/pending_bootstrap_book_large.txt');
      final buffer = StringBuffer('第1章 开始\n第一屏正文。\n');
      for (var index = 0; index < 9000; index += 1) {
        buffer.writeln('中间内容 $index');
      }
      buffer.writeln('末尾不应出现在 bootstrap 预览');
      await file.writeAsString(buffer.toString(), flush: true);

      final now = DateTime.parse('2026-03-21T12:00:00.000Z');
      await repository.upsertBook(
        LocalBook(
          id: 'local_pending_bootstrap_large_1',
          title: '待建立正文直读大文件测试',
          format: LocalBookFormat.txt,
          storagePath: file.path,
          fileSize: await file.length(),
          indexStatus: LocalBookIndexStatus.indexing,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final chapter = await previewService.loadTxtBootstrapPreview(
        bookId: 'local_pending_bootstrap_large_1',
      );

      expect(chapter.content, contains('第一屏正文'));
      expect(chapter.content, isNot(contains('末尾不应出现在 bootstrap 预览')));
      expect(chapter.endOffset, lessThan(await file.length()));
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

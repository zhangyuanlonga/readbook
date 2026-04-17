import 'dart:io';

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
  });
}

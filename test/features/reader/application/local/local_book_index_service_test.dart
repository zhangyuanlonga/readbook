import 'dart:io';

import 'package:drift/native.dart';
import 'package:shuxiang_reading_next/core/errors/error_codes.dart';
import 'package:shuxiang_reading_next/core/errors/error_stage.dart';
import 'package:shuxiang_reading_next/core/errors/app_exception.dart';
import 'package:shuxiang_reading_next/data/datasources/local/app_database.dart';
import 'package:shuxiang_reading_next/data/repositories/local_book_repository_impl.dart';
import 'package:shuxiang_reading_next/domain/entities/local_book.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_system_settings_service.dart';
import 'package:shuxiang_reading_next/features/reader/application/local/local_book_index_service.dart';
import 'package:shuxiang_reading_next/features/reader/application/local/local_book_parser.dart';
import 'package:shuxiang_reading_next/features/reader/application/local/local_book_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocalBookIndexService', () {
    late AppDatabase database;
    late LocalBookRepositoryImpl repository;
    late Directory tempDir;
    late LocalBookStorageService storageService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      database = AppDatabase(executor: NativeDatabase.memory());
      repository = LocalBookRepositoryImpl(database);
      tempDir = await Directory.systemTemp.createTemp('local_book_index_test');
      storageService = LocalBookStorageService(
        supportDirectoryProvider: () async => tempDir,
      );
    });

    tearDown(() async {
      await database.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('writes parsed chapters and marks book ready', () async {
      final now = DateTime.parse('2026-02-23T12:00:00.000Z');
      final file = File('${tempDir.path}/index_1.txt');
      await file.writeAsString('第一章\n内容');
      await repository.upsertBook(
        LocalBook(
          id: 'local_index_1',
          title: '索引测试',
          format: LocalBookFormat.txt,
          storagePath: file.path,
          fileSize: await file.length(),
          createdAt: now,
          updatedAt: now,
        ),
      );

      final service = LocalBookIndexService(
        localBookRepository: repository,
        parsers: const [_FakeSuccessParser()],
        storageService: storageService,
      );

      final chapters = await service.ensureIndexed(bookId: 'local_index_1');

      expect(chapters, hasLength(2));
      final updated = await repository.getBookById('local_index_1');
      expect(updated, isNotNull);
      expect(updated!.indexStatus, LocalBookIndexStatus.ready);
      expect(updated.chapterCount, 2);
    });

    test('marks book failed when parser throws', () async {
      final now = DateTime.parse('2026-02-23T12:00:00.000Z');
      final file = File('${tempDir.path}/index_2.txt');
      await file.writeAsString('第一章\n内容');
      await repository.upsertBook(
        LocalBook(
          id: 'local_index_2',
          title: '失败测试',
          format: LocalBookFormat.txt,
          storagePath: file.path,
          fileSize: await file.length(),
          createdAt: now,
          updatedAt: now,
        ),
      );

      final service = LocalBookIndexService(
        localBookRepository: repository,
        parsers: const [_FakeFailureParser()],
        storageService: storageService,
      );

      await expectLater(
        service.ensureIndexed(bookId: 'local_index_2'),
        throwsA(isA<AppException>()),
      );

      final updated = await repository.getBookById('local_index_2');
      expect(updated, isNotNull);
      expect(updated!.indexStatus, LocalBookIndexStatus.failed);
      expect(updated.chapterCount, 0);
      expect(updated.lastError, contains('模拟解析失败'));
    });

    test('syncs split long chapter from system setting on reindex', () async {
      final now = DateTime.parse('2026-02-23T12:00:00.000Z');
      final file = File('${tempDir.path}/split.txt');
      await file.writeAsString('第一章\n内容');
      await repository.upsertBook(
        LocalBook(
          id: 'local_index_split_1',
          title: '系统设置同步测试',
          format: LocalBookFormat.txt,
          storagePath: file.path,
          fileSize: await file.length(),
          splitLongChapter: true,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final prefs = await SharedPreferences.getInstance();
      final systemSettingsService = ReaderSystemSettingsService(
        preferences: prefs,
      );
      await systemSettingsService.saveLocalTxtSplitLongChapterEnabled(false);

      final service = LocalBookIndexService(
        localBookRepository: repository,
        parsers: const [_FakeSuccessParser()],
        readerSystemSettingsService: systemSettingsService,
        storageService: storageService,
      );

      await service.ensureIndexed(bookId: 'local_index_split_1');

      final updated = await repository.getBookById('local_index_split_1');
      expect(updated, isNotNull);
      expect(updated!.splitLongChapter, isFalse);
    });

    test('marks ready book stale when source file changed', () async {
      final sourceFile = File('${tempDir.path}/source.txt');
      final storageFile = File('${tempDir.path}/storage.txt');
      await sourceFile.writeAsString('第一章\n原始内容');
      await storageFile.writeAsString('第一章\n旧内容');
      final sourceStat = await sourceFile.stat();
      final storageStat = await storageFile.stat();
      final now = DateTime.parse('2026-02-23T12:00:00.000Z');

      await repository.upsertBook(
        LocalBook(
          id: 'local_index_stale_1',
          title: 'stale 测试',
          format: LocalBookFormat.txt,
          storagePath: storageFile.path,
          sourcePath: sourceFile.path,
          fileSize: storageStat.size,
          sourceFileSize: sourceStat.size,
          sourceFileLastModifiedMs: sourceStat.modified.millisecondsSinceEpoch,
          storageFileLastModifiedMs:
              storageStat.modified.millisecondsSinceEpoch,
          indexStatus: LocalBookIndexStatus.ready,
          chapterCount: 2,
          createdAt: now,
          updatedAt: now,
        ),
      );

      await sourceFile.writeAsString('第一章\n源文件已变化');

      final service = LocalBookIndexService(
        localBookRepository: repository,
        parsers: const [_FakeSuccessParser()],
        storageService: storageService,
      );
      final refreshed = await service.refreshBookState(
        bookId: 'local_index_stale_1',
      );

      expect(refreshed, isNotNull);
      expect(refreshed!.indexStatus, LocalBookIndexStatus.stale);
      expect(await storageFile.readAsString(), contains('源文件已变化'));
    });

    test(
      'keeps relative storage path readable when source path is unavailable',
      () async {
        final supportDir = Directory('${tempDir.path}/app_support');
        await supportDir.create(recursive: true);
        final managedDir = Directory('${supportDir.path}/local_books');
        await managedDir.create(recursive: true);
        final managedFile = File('${managedDir.path}/book_rel_1.txt');
        await managedFile.writeAsString('第一章\n相对路径内容');

        final now = DateTime.parse('2026-02-23T12:00:00.000Z');
        await repository.upsertBook(
          LocalBook(
            id: 'local_index_relative_1',
            title: '相对路径测试',
            format: LocalBookFormat.txt,
            storagePath: 'local_books/book_rel_1.txt',
            fileSize: await managedFile.length(),
            createdAt: now,
            updatedAt: now,
          ),
        );

      final service = LocalBookIndexService(
        localBookRepository: repository,
        parsers: const [_FakeSuccessParser()],
        storageService: LocalBookStorageService(
          supportDirectoryProvider: () async => supportDir,
        ),
      );

        final refreshed = await service.refreshBookState(
          bookId: 'local_index_relative_1',
        );

        expect(refreshed, isNotNull);
        expect(refreshed!.storagePath, 'local_books/book_rel_1.txt');
        expect(refreshed.fileSize, await managedFile.length());
      },
    );
  });
}

class _FakeSuccessParser implements LocalBookParser {
  const _FakeSuccessParser();

  @override
  Future<LocalParsedBook> parse(LocalBook book) async {
    return const LocalParsedBook(
      chapters: [
        LocalParsedChapter(title: '第一章', content: '内容1'),
        LocalParsedChapter(title: '第二章', content: '内容2'),
      ],
    );
  }

  @override
  bool supports(LocalBookFormat format) => true;
}

class _FakeFailureParser implements LocalBookParser {
  const _FakeFailureParser();

  @override
  Future<LocalParsedBook> parse(LocalBook book) {
    throw AppException(
      code: ErrorCode.ruleParse,
      stage: ErrorStage.content,
      briefMessage: '模拟解析失败',
    );
  }

  @override
  bool supports(LocalBookFormat format) => true;
}

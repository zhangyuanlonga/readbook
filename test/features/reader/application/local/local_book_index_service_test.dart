import 'dart:io';

import 'package:drift/native.dart';
import 'package:shuxiang_reading_next/core/errors/error_codes.dart';
import 'package:shuxiang_reading_next/core/errors/error_stage.dart';
import 'package:shuxiang_reading_next/core/errors/app_exception.dart';
import 'package:shuxiang_reading_next/data/datasources/local/app_database.dart';
import 'package:shuxiang_reading_next/data/repositories/local_book_repository_impl.dart';
import 'package:shuxiang_reading_next/domain/entities/local_book.dart';
import 'package:shuxiang_reading_next/domain/entities/local_chapter.dart';
import 'package:shuxiang_reading_next/features/bookshelf/application/bookshelf_service.dart';
import 'package:shuxiang_reading_next/features/reader/application/reading_record_service.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_system_settings_service.dart';
import 'package:shuxiang_reading_next/features/reader/application/local/local_book_index_service.dart';
import 'package:shuxiang_reading_next/features/reader/application/local/local_book_parser.dart';
import 'package:shuxiang_reading_next/features/reader/application/local/local_book_storage_service.dart';
import 'package:shuxiang_reading_next/features/reader/application/local/txt_local_book_parser.dart';
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

    LocalBookIndexService buildService({
      required List<LocalBookParser> parsers,
      ReaderSystemSettingsService? systemSettingsService,
      LocalBookStorageService? localStorageService,
    }) {
      return LocalBookIndexService(
        localBookRepository: repository,
        parsers: parsers,
        readerSystemSettingsService:
            systemSettingsService ?? ReaderSystemSettingsService(),
        storageService: localStorageService ?? storageService,
        bookshelfService: BookshelfService(),
        readingRecordService: ReadingRecordService(database: database),
      );
    }

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

      final service = buildService(parsers: const [_FakeSuccessParser()]);

      final chapters = await service.ensureIndexed(bookId: 'local_index_1');

      expect(chapters, hasLength(2));
      final updated = await repository.getBookById('local_index_1');
      expect(updated, isNotNull);
      expect(updated!.indexStatus, LocalBookIndexStatus.ready);
      expect(updated.chapterCount, 2);
      expect(chapters.first.content, '内容1');
      expect(chapters.last.content, '内容2');
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

      final service = buildService(parsers: const [_FakeFailureParser()]);

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

    test('syncs split long chapter from persisted global setting', () async {
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

      final service = buildService(
        parsers: const [_FakeSuccessParser()],
        systemSettingsService: systemSettingsService,
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

      final service = buildService(parsers: const [_FakeSuccessParser()]);
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

        final service = buildService(
          parsers: const [_FakeSuccessParser()],
          localStorageService: LocalBookStorageService(
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

    test(
      'marks ready txt with empty content and missing offsets as stale',
      () async {
        final now = DateTime.parse('2026-02-23T12:00:00.000Z');
        final file = File('${tempDir.path}/legacy_txt.txt');
        await file.writeAsString('第1章\n旧内容');
        await repository.upsertBook(
          LocalBook(
            id: 'local_index_legacy_txt',
            title: 'legacy txt',
            format: LocalBookFormat.txt,
            storagePath: file.path,
            fileSize: await file.length(),
            indexStatus: LocalBookIndexStatus.ready,
            chapterCount: 1,
            createdAt: now,
            updatedAt: now,
          ),
        );
        await repository.replaceChapters(
          bookId: 'local_index_legacy_txt',
          chapters: <LocalChapter>[
            LocalChapter(
              id: 'local_index_legacy_txt_0',
              bookId: 'local_index_legacy_txt',
              chapterIndex: 0,
              title: '第1章',
              content: '',
              sourceRef: null,
              createdAt: now,
              updatedAt: now,
            ),
          ],
        );

        final service = buildService(parsers: const [_FakeSuccessParser()]);

        final refreshed = await service.refreshBookState(
          bookId: 'local_index_legacy_txt',
        );

        expect(refreshed, isNotNull);
        expect(refreshed!.indexStatus, LocalBookIndexStatus.stale);
      },
    );

    test(
      'marks ready txt with empty content and valid offsets as stale',
      () async {
        final now = DateTime.parse('2026-02-23T12:00:00.000Z');
        final file = File('${tempDir.path}/streamed_txt.txt');
        await file.writeAsString('第1章\n按偏移读取的正文');
        final fileStat = await file.stat();
        await repository.upsertBook(
          LocalBook(
            id: 'local_index_streamed_txt',
            title: 'streamed txt',
            format: LocalBookFormat.txt,
            storagePath: file.path,
            fileSize: fileStat.size,
            storageFileLastModifiedMs: fileStat.modified.millisecondsSinceEpoch,
            indexStatus: LocalBookIndexStatus.ready,
            chapterCount: 1,
            createdAt: now,
            updatedAt: now,
          ),
        );
        await repository.replaceChapters(
          bookId: 'local_index_streamed_txt',
          chapters: <LocalChapter>[
            LocalChapter(
              id: 'local_index_streamed_txt_0',
              bookId: 'local_index_streamed_txt',
              chapterIndex: 0,
              title: '第1章',
              content: '',
              sourceRef: null,
              startOffset: 4,
              endOffset: 26,
              createdAt: now,
              updatedAt: now,
            ),
          ],
        );

        final service = buildService(parsers: const [_FakeSuccessParser()]);

        final refreshed = await service.refreshBookState(
          bookId: 'local_index_streamed_txt',
        );

        expect(refreshed, isNotNull);
        expect(refreshed!.indexStatus, LocalBookIndexStatus.stale);
      },
    );

    test('reindex succeeds after correcting frozen txt charset', () async {
      final file = File('${tempDir.path}/reindex_charset_utf16le.txt');
      const content = '第1章 开始\n第一章内容。\n\n第2章 继续\n第二章内容。';
      await file.writeAsBytes(
        _encodeUtf16(content, littleEndian: true, withBom: true),
        flush: true,
      );
      final now = DateTime.parse('2026-02-23T12:00:00.000Z');

      await repository.upsertBook(
        LocalBook(
          id: 'local_index_reindex_charset_1',
          title: '重建编码测试',
          format: LocalBookFormat.txt,
          storagePath: file.path,
          charset: 'utf-8',
          fileSize: await file.length(),
          createdAt: now,
          updatedAt: now,
        ),
      );

      final service = buildService(
        parsers: const <LocalBookParser>[TxtLocalBookParser()],
      );

      await expectLater(
        service.ensureIndexed(bookId: 'local_index_reindex_charset_1'),
        throwsA(isA<AppException>()),
      );

      final wrongIndexed = await repository.getBookById(
        'local_index_reindex_charset_1',
      );
      expect(wrongIndexed, isNotNull);
      await repository.upsertBook(
        wrongIndexed!.copyWith(charset: 'utf-16le', updatedAt: DateTime.now()),
      );

      final chapters = await service.ensureIndexed(
        bookId: 'local_index_reindex_charset_1',
        force: true,
      );

      expect(chapters, hasLength(2));
      expect(chapters.first.title, '第1章 开始');
      expect(chapters.last.content, contains('第二章内容'));

      final updated = await repository.getBookById(
        'local_index_reindex_charset_1',
      );
      expect(updated, isNotNull);
      expect(updated!.indexStatus, LocalBookIndexStatus.ready);
      expect(updated.charset, 'utf-16le');
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

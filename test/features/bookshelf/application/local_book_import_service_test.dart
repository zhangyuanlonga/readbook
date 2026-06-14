import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuxiang_reading_next/core/logging/app_logger.dart';
import 'package:shuxiang_reading_next/data/datasources/local/app_database.dart';
import 'package:shuxiang_reading_next/data/repositories/local_book_repository_impl.dart';
import 'package:shuxiang_reading_next/domain/entities/local_book.dart';
import 'package:shuxiang_reading_next/features/bookshelf/application/bookshelf_service.dart';
import 'package:shuxiang_reading_next/features/bookshelf/application/local_book_import_service.dart';
import 'package:shuxiang_reading_next/features/reader/application/local/local_book_index_service.dart';
import 'package:shuxiang_reading_next/features/reader/application/local/local_book_parser.dart';
import 'package:shuxiang_reading_next/features/reader/application/local/local_book_storage_service.dart';
import 'package:shuxiang_reading_next/features/reader/application/reading_record_service.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_system_settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocalBookImportService', () {
    late Directory tempDir;
    late AppDatabase database;
    late LocalBookRepositoryImpl repository;
    late SharedPreferences preferences;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      preferences = await SharedPreferences.getInstance();
      tempDir = await Directory.systemTemp.createTemp(
        'local_book_import_service_test',
      );
      database = AppDatabase(executor: NativeDatabase.memory());
      repository = LocalBookRepositoryImpl(database);
    });

    tearDown(() async {
      await database.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    LocalBookImportService buildService({BookshelfService? bookshelfService}) {
      final resolvedBookshelfService =
          bookshelfService ??
          BookshelfService(preferences: preferences, database: database);
      final storageService = LocalBookStorageService(
        supportDirectoryProvider: () async => tempDir,
      );
      return LocalBookImportService(
        localBookRepository: repository,
        bookshelfService: resolvedBookshelfService,
        readerSystemSettingsService: ReaderSystemSettingsService(
          preferences: preferences,
        ),
        localBookStorageService: storageService,
        logger: AppLogger.instance,
        localBookIndexService: LocalBookIndexService(
          localBookRepository: repository,
          parsers: const <LocalBookParser>[_FakeImportParser()],
          readerSystemSettingsService: ReaderSystemSettingsService(
            preferences: preferences,
          ),
          storageService: storageService,
          bookshelfService: resolvedBookshelfService,
          readingRecordService: ReadingRecordService(database: database),
        ),
        warmUpDelay: Duration.zero,
      );
    }

    test(
      'batch import sorts txt and smaller files before large files',
      () async {
        final smallTxt = File('${tempDir.path}/small.txt');
        await smallTxt.writeAsString('第一章\n小文件正文', flush: true);
        final largePdf = File('${tempDir.path}/large.pdf');
        await largePdf.writeAsBytes(
          List<int>.filled(256 * 1024, 1),
          flush: true,
        );
        final service = buildService();
        final startedLabels = <String>[];

        final summary = await service.importFromFiles(
          candidates: <LocalBookImportBatchCandidate>[
            LocalBookImportBatchCandidate(
              filePath: largePdf.path,
              displayName: 'large.pdf',
            ),
            LocalBookImportBatchCandidate(
              filePath: smallTxt.path,
              displayName: 'small.txt',
            ),
          ],
          waitForIndexing: true,
          onProgress: (progress) {
            final importProgress = progress.importProgress;
            if (importProgress?.stage == LocalBookImportStage.preparing) {
              startedLabels.add(importProgress!.displayName);
            }
          },
        );

        expect(summary.successCount, 2);
        expect(summary.failureCount, 0);
        expect(startedLabels, isNotEmpty);
        expect(startedLabels.first, 'small.txt');
      },
    );

    test(
      'precheck reports unsupported existing files without importing',
      () async {
        final file = File('${tempDir.path}/unsupported.xyz');
        await file.writeAsString('内容', flush: true);
        final service = buildService();

        final precheck = await service.inspectImportCandidate(
          filePath: file.path,
          displayName: 'unsupported.xyz',
        );

        expect(precheck.exists, isTrue);
        expect(precheck.canImport, isFalse);
        expect(precheck.isSupported, isFalse);
        expect(precheck.errorMessage, contains('暂不支持'));
      },
    );

    test(
      'precheck rejects missing and empty files with clear reasons',
      () async {
        final emptyFile = File('${tempDir.path}/empty.txt');
        await emptyFile.writeAsString('', flush: true);
        final service = buildService();

        final missing = await service.inspectImportCandidate(
          filePath: '${tempDir.path}/missing.txt',
          displayName: 'missing.txt',
        );
        final empty = await service.inspectImportCandidate(
          filePath: emptyFile.path,
          displayName: 'empty.txt',
        );

        expect(missing.canImport, isFalse);
        expect(missing.errorMessage, contains('不存在'));
        expect(empty.canImport, isFalse);
        expect(empty.isEmptyFile, isTrue);
        expect(empty.errorMessage, contains('为空'));
      },
    );

    test(
      'precheck can resolve format from mime type when label has no extension',
      () async {
        final file = File('${tempDir.path}/mime_payload.bin');
        await file.writeAsBytes(List<int>.filled(16, 1), flush: true);
        final service = buildService();

        final precheck = await service.inspectImportCandidate(
          filePath: file.path,
          displayName: 'mime_payload',
          mimeType: 'application/pdf',
        );

        expect(precheck.canImport, isTrue);
        expect(precheck.format, LocalBookFormat.pdf);
      },
    );

    test(
      'duplicate import replaces the same book and preserves shelf metadata',
      () async {
        final file = File('${tempDir.path}/duplicate.txt');
        await file.writeAsString('第一章\n原正文', flush: true);
        final bookshelfService = BookshelfService(
          preferences: preferences,
          database: database,
        );
        final service = buildService(bookshelfService: bookshelfService);

        final first = await service.importFromFile(
          filePath: file.path,
          displayName: 'duplicate.txt',
          waitForIndexing: true,
        );
        await bookshelfService.setBookTags(
          sourceId: LocalBookImportService.localBookSourceId,
          detailUrl: first.bookshelfBook.detailUrl,
          tags: const <String>['本地', '测试'],
        );
        await bookshelfService.setBookCategory(
          sourceId: LocalBookImportService.localBookSourceId,
          detailUrl: first.bookshelfBook.detailUrl,
          category: '本地图书',
        );
        await bookshelfService.setInReadingQueue(
          sourceId: LocalBookImportService.localBookSourceId,
          detailUrl: first.bookshelfBook.detailUrl,
          inReadingQueue: true,
        );

        await file.writeAsString('第一章\n新正文内容', flush: true);
        final second = await service.importFromFile(
          filePath: file.path,
          displayName: 'duplicate.txt',
          waitForIndexing: true,
        );

        expect(second.localBook.id, first.localBook.id);
        expect(await repository.getAllBooks(), hasLength(1));
        final shelfBooks = await bookshelfService.getAll();
        expect(shelfBooks, hasLength(1));
        expect(shelfBooks.single.category, '本地图书');
        expect(shelfBooks.single.inReadingQueue, isTrue);
        final tagMap = await bookshelfService.getTagMap();
        final tagKey =
            '${LocalBookImportService.localBookSourceId}::${first.bookshelfBook.detailUrl}';
        expect(tagMap[tagKey], containsAll(const <String>['本地', '测试']));
      },
    );

    test(
      'duplicate strategy can keep both books for future UI choices',
      () async {
        final file = File('${tempDir.path}/keep_both.txt');
        await file.writeAsString('第一章\n正文', flush: true);
        final service = buildService();

        final first = await service.importFromFile(
          filePath: file.path,
          displayName: 'keep_both.txt',
          waitForIndexing: true,
        );
        final second = await service.importFromFile(
          filePath: file.path,
          displayName: 'keep_both.txt',
          waitForIndexing: true,
          duplicateStrategy: LocalBookImportDuplicateStrategy.keepBoth,
        );

        expect(second.localBook.id, isNot(first.localBook.id));
        expect(await repository.getAllBooks(), hasLength(2));
      },
    );
  });
}

class _FakeImportParser implements LocalBookParser {
  const _FakeImportParser();

  @override
  Future<LocalParsedBook> parse(LocalBook book) async {
    return LocalParsedBook(
      title: book.title,
      chapters: const <LocalParsedChapter>[
        LocalParsedChapter(title: '第一章', content: '正文'),
      ],
    );
  }

  @override
  bool supports(LocalBookFormat format) => true;
}

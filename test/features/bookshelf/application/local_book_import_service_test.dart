import 'dart:async';
import 'dart:io';

import 'package:charset/charset.dart';
import 'package:drift/native.dart';
import 'package:shuxiang_reading_next/core/errors/app_exception.dart';
import 'package:shuxiang_reading_next/core/errors/error_codes.dart';
import 'package:shuxiang_reading_next/core/errors/error_stage.dart';
import 'package:shuxiang_reading_next/core/logging/app_logger.dart';
import 'package:shuxiang_reading_next/data/datasources/local/app_database.dart';
import 'package:shuxiang_reading_next/data/repositories/local_book_repository_impl.dart';
import 'package:shuxiang_reading_next/domain/entities/local_book.dart';
import 'package:shuxiang_reading_next/domain/entities/local_chapter.dart';
import 'package:shuxiang_reading_next/features/bookshelf/application/bookshelf_service.dart';
import 'package:shuxiang_reading_next/features/bookshelf/application/local_book_import_service.dart';
import 'package:shuxiang_reading_next/features/reader/application/local/local_book_index_service.dart';
import 'package:shuxiang_reading_next/features/reader/application/local/local_book_parser.dart';
import 'package:shuxiang_reading_next/features/reader/application/local/local_book_storage_service.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_system_settings_service.dart';
import 'package:shuxiang_reading_next/features/source/application/source_login_state_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocalBookImportService', () {
    late AppDatabase database;
    late Directory tempDir;
    late LocalBookStorageService storageService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      database = AppDatabase(executor: NativeDatabase.memory());
      tempDir = await Directory.systemTemp.createTemp('local_book_import_test');
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

    LocalBookImportService buildService({
      required SharedPreferences preferences,
      LocalBookIndexService? localBookIndexService,
    }) {
      return LocalBookImportService(
        localBookRepository: LocalBookRepositoryImpl(database),
        bookshelfService: BookshelfService(preferences: preferences),
        readerSystemSettingsService: ReaderSystemSettingsService(),
        localBookStorageService: storageService,
        logger: AppLogger.instance,
        sourceLoginStateService: SourceLoginStateService(),
        localBookIndexService: localBookIndexService,
      );
    }

    test('imports txt file and writes bookshelf/local book records', () async {
      final sourceFile = File('${tempDir.path}/demo.txt');
      const sourceText = '第一章\n内容';
      await sourceFile.writeAsString(sourceText);

      final prefs = await SharedPreferences.getInstance();
      final service = buildService(preferences: prefs);

      final result = await service.importFromFile(
        filePath: sourceFile.path,
        displayName: '演示书籍.txt',
      );

      expect(result.localBook.id, startsWith('local_'));
      expect(result.localBook.format.name, 'txt');
      expect(result.localBook.title, '演示书籍');
      final resolvedStoragePath = await storageService.resolveStoragePath(
        result.localBook.storagePath,
      );
      expect(File(resolvedStoragePath).existsSync(), isTrue);
      expect(
        File(resolvedStoragePath).readAsBytesSync(),
        sourceFile.readAsBytesSync(),
      );

      final stored = await database.getLocalBookById(result.localBook.id);
      expect(stored, isNotNull);
      expect(stored!.sourcePath, sourceFile.path);
      expect(stored.sourceFileSize, await sourceFile.length());
      expect(stored.sourceFileLastModifiedMs, isNotNull);
      expect(stored.storageFileLastModifiedMs, isNotNull);
      expect(stored.charset, 'utf-8');

      final bookshelf = await BookshelfService(preferences: prefs).getAll();
      expect(bookshelf, hasLength(1));
      expect(bookshelf.first.bookId, result.localBook.id);
      expect(
        bookshelf.first.sourceId,
        LocalBookImportService.localBookSourceId,
      );
      expect(bookshelf.first.detailUrl, 'local://book/${result.localBook.id}');
    });

    test('imports utf-16le txt and normalizes content to utf-8', () async {
      final sourceFile = File('${tempDir.path}/utf16le_bom.txt');
      const sourceText = '第1章 开始\n第一章内容。\n\n第2章 继续\n第二章内容。';
      await sourceFile.writeAsBytes(
        _encodeUtf16(sourceText, littleEndian: true, withBom: true),
        flush: true,
      );

      final prefs = await SharedPreferences.getInstance();
      final service = buildService(preferences: prefs);

      final result = await service.importFromFile(
        filePath: sourceFile.path,
        displayName: 'utf16le_bom.txt',
      );

      final resolvedStoragePath = await storageService.resolveStoragePath(
        result.localBook.storagePath,
      );
      final storageText = await File(resolvedStoragePath).readAsString();
      expect(storageText, contains('第1章 开始'));
      expect(storageText, contains('第二章内容'));
      expect(result.localBook.charset, 'utf-8');
    });

    test(
      'keeps large non-utf8 txt as raw bytes with detected charset',
      () async {
        final sourceFile = File('${tempDir.path}/large_utf16le_bom.txt');
        final buffer = StringBuffer();
        for (var index = 0; index < 70000; index += 1) {
          buffer.writeln('第${index + 1}段 大文件内容保留测试。');
        }
        final rawBytes = _encodeUtf16(
          buffer.toString(),
          littleEndian: true,
          withBom: true,
        );
        expect(rawBytes.length, greaterThan(1024 * 1024));
        await sourceFile.writeAsBytes(rawBytes, flush: true);

        final prefs = await SharedPreferences.getInstance();
        final service = buildService(preferences: prefs);

        final result = await service.importFromFile(
          filePath: sourceFile.path,
          displayName: 'large_utf16le_bom.txt',
        );

        final resolvedStoragePath = await storageService.resolveStoragePath(
          result.localBook.storagePath,
        );
        expect(await File(resolvedStoragePath).readAsBytes(), rawBytes);
        expect(result.localBook.charset, 'utf-16le');
      },
    );

    test(
      'detects gbk correctly when large txt head is ascii but body is chinese',
      () async {
        final gbk = Charset.getByName('gbk');
        expect(gbk, isNotNull);

        final sourceFile = File('${tempDir.path}/ascii_head_body_gbk.txt');
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

        final prefs = await SharedPreferences.getInstance();
        final service = buildService(preferences: prefs);

        final result = await service.importFromFile(
          filePath: sourceFile.path,
          displayName: 'ascii_head_body_gbk.txt',
        );

        expect(result.localBook.charset, anyOf('gbk', 'gb18030'));
        final resolvedStoragePath = await storageService.resolveStoragePath(
          result.localBook.storagePath,
        );
        expect(
          await File(resolvedStoragePath).readAsBytes(),
          sourceFile.readAsBytesSync(),
        );
      },
    );

    test('keeps large utf8 txt raw bytes', () async {
      final sourceFile = File('${tempDir.path}/large_utf8_raw.txt');
      final buffer = StringBuffer();
      for (var index = 0; index < 60000; index += 1) {
        buffer.writeln('第${index + 1}章 原始 UTF8 内容。');
      }
      final rawContent = buffer.toString();
      await sourceFile.writeAsString(rawContent, flush: true);

      final prefs = await SharedPreferences.getInstance();
      final service = buildService(preferences: prefs);

      final result = await service.importFromFile(
        filePath: sourceFile.path,
        displayName: 'large_utf8_raw.txt',
      );

      final resolvedStoragePath = await storageService.resolveStoragePath(
        result.localBook.storagePath,
      );
      expect(
        await File(resolvedStoragePath).readAsBytes(),
        sourceFile.readAsBytesSync(),
      );
      expect(result.localBook.charset, 'utf-8');
    });

    test('re-import by same source path keeps same local book id', () async {
      final sourceFile = File('${tempDir.path}/same.txt');
      await sourceFile.writeAsString('初始内容');

      final service = buildService(
        preferences: await SharedPreferences.getInstance(),
      );

      final first = await service.importFromFile(filePath: sourceFile.path);

      await sourceFile.writeAsString('覆盖内容');
      final second = await service.importFromFile(filePath: sourceFile.path);

      expect(second.localBook.id, first.localBook.id);
      expect(second.localBook.storagePath, first.localBook.storagePath);
      final resolvedStoragePath = await storageService.resolveStoragePath(
        second.localBook.storagePath,
      );
      expect(File(resolvedStoragePath).readAsStringSync(), '覆盖内容');
      expect(second.localBook.sourceFileSize, await sourceFile.length());
    });

    test('removes local book storage and records', () async {
      final sourceFile = File('${tempDir.path}/remove.txt');
      await sourceFile.writeAsString('待删除内容');

      final prefs = await SharedPreferences.getInstance();
      final service = buildService(preferences: prefs);

      final result = await service.importFromFile(filePath: sourceFile.path);
      final resolvedStoragePath = await storageService.resolveStoragePath(
        result.localBook.storagePath,
      );
      final storageFile = File(resolvedStoragePath);
      expect(storageFile.existsSync(), isTrue);

      await service.removeLocalBook(
        bookId: result.localBook.id,
        detailUrl: result.bookshelfBook.detailUrl,
      );

      expect(storageFile.existsSync(), isFalse);
      expect(await database.getLocalBookById(result.localBook.id), isNull);
      expect(await BookshelfService(preferences: prefs).getAll(), isEmpty);
    });

    test('throws validation for unsupported file extension', () async {
      final sourceFile = File('${tempDir.path}/invalid.docx');
      await sourceFile.writeAsString('docx');

      final service = buildService(
        preferences: await SharedPreferences.getInstance(),
      );

      expect(
        () => service.importFromFile(filePath: sourceFile.path),
        throwsA(
          isA<AppException>().having(
            (error) => error.briefMessage,
            'briefMessage',
            contains('仅支持导入 txt、epub、md、html、pdf、mobi、azw 或 azw3'),
          ),
        ),
      );
    });

    test('accepts pdf import when parser is provided', () async {
      final sourceFile = File('${tempDir.path}/sample.pdf');
      await sourceFile.writeAsBytes(const <int>[1, 2, 3], flush: true);

      final repository = LocalBookRepositoryImpl(database);
      final prefs = await SharedPreferences.getInstance();
      final indexService = LocalBookIndexService(
        localBookRepository: repository,
        parsers: const <LocalBookParser>[_FakePdfSuccessParser()],
        storageService: storageService,
      );
      final service = buildService(
        preferences: prefs,
        localBookIndexService: indexService,
      );

      final result = await service.importFromFile(
        filePath: sourceFile.path,
        waitForIndexing: true,
      );

      expect(result.localBook.format, LocalBookFormat.pdf);
      final stored = await database.getLocalBookById(result.localBook.id);
      expect(stored, isNotNull);
      expect(stored!.indexStatus, LocalBookIndexStatus.ready);
      final chapters = await database.getLocalChapters(result.localBook.id);
      expect(chapters, hasLength(2));
      expect(chapters.first.title, '第 1 页');
      expect(chapters.last.content, contains('第二页内容'));
    });

    test('imports markdown file and indexes chapters', () async {
      final sourceFile = File('${tempDir.path}/demo.md');
      await sourceFile.writeAsString('''
# 第一章

第一章内容。

## 第二章

第二章内容。
''');

      final prefs = await SharedPreferences.getInstance();
      final service = buildService(preferences: prefs);

      final result = await service.importFromFile(
        filePath: sourceFile.path,
        waitForIndexing: true,
      );

      expect(result.localBook.format, LocalBookFormat.md);
      final stored = await database.getLocalBookById(result.localBook.id);
      expect(stored, isNotNull);
      expect(stored!.indexStatus, LocalBookIndexStatus.ready);
      expect(stored.description, '第一章内容。');
      final chapters = await database.getLocalChapters(result.localBook.id);
      expect(chapters, hasLength(2));
      expect(chapters.first.content, contains('第一章内容'));
      expect(chapters.last.content, contains('第二章内容'));
    });

    test('accepts mobi import when parser is provided', () async {
      final sourceFile = File('${tempDir.path}/sample.mobi');
      await sourceFile.writeAsBytes(const <int>[1, 2, 3], flush: true);

      final repository = LocalBookRepositoryImpl(database);
      final prefs = await SharedPreferences.getInstance();
      final indexService = LocalBookIndexService(
        localBookRepository: repository,
        parsers: const <LocalBookParser>[_FakeKindleSuccessParser()],
        storageService: storageService,
      );
      final service = buildService(
        preferences: prefs,
        localBookIndexService: indexService,
      );

      final result = await service.importFromFile(
        filePath: sourceFile.path,
        waitForIndexing: true,
      );

      expect(result.localBook.format, LocalBookFormat.mobi);
      final stored = await database.getLocalBookById(result.localBook.id);
      expect(stored, isNotNull);
      expect(stored!.indexStatus, LocalBookIndexStatus.ready);
      final chapters = await database.getLocalChapters(result.localBook.id);
      expect(chapters, hasLength(1));
      expect(chapters.single.content, contains('Kindle 正文'));
    });

    test('accepts azw import when parser is provided', () async {
      final sourceFile = File('${tempDir.path}/sample.azw');
      await sourceFile.writeAsBytes(const <int>[1, 2, 3], flush: true);

      final repository = LocalBookRepositoryImpl(database);
      final prefs = await SharedPreferences.getInstance();
      final indexService = LocalBookIndexService(
        localBookRepository: repository,
        parsers: const <LocalBookParser>[_FakeKindleSuccessParser()],
        storageService: storageService,
      );
      final service = buildService(
        preferences: prefs,
        localBookIndexService: indexService,
      );

      final result = await service.importFromFile(
        filePath: sourceFile.path,
        waitForIndexing: true,
      );

      expect(result.localBook.format, LocalBookFormat.azw);
      final stored = await database.getLocalBookById(result.localBook.id);
      expect(stored, isNotNull);
      expect(stored!.indexStatus, LocalBookIndexStatus.ready);
      final chapters = await database.getLocalChapters(result.localBook.id);
      expect(chapters, hasLength(1));
      expect(chapters.single.content, contains('Kindle 正文'));
    });

    test('imports html file and materializes relative images', () async {
      final imageDir = Directory('${tempDir.path}/source_assets');
      await imageDir.create(recursive: true);
      final imageFile = File('${imageDir.path}/cover.png');
      await imageFile.writeAsBytes(const <int>[1, 2, 3, 4], flush: true);
      final sourceFile = File('${tempDir.path}/demo.html');
      await sourceFile.writeAsString('''
<html>
  <head>
    <title>HTML 示例</title>
    <meta name="author" content="HTML 作者" />
    <meta name="description" content="HTML 示例简介" />
  </head>
  <body>
    <h1>第一章</h1>
    <p>第一章内容。</p>
    <img src="source_assets/cover.png" />
  </body>
</html>
''');

      final prefs = await SharedPreferences.getInstance();
      final service = buildService(preferences: prefs);

      final result = await service.importFromFile(
        filePath: sourceFile.path,
        waitForIndexing: true,
      );

      expect(result.localBook.format, LocalBookFormat.html);
      final stored = await database.getLocalBookById(result.localBook.id);
      expect(stored, isNotNull);
      expect(stored!.author, 'HTML 作者');
      expect(stored.description, 'HTML 示例简介');
      expect(stored.coverPath, isNotNull);
      expect(File(stored.coverPath!).existsSync(), isTrue);
      final chapters = await database.getLocalChapters(result.localBook.id);
      expect(chapters, hasLength(1));
      expect(chapters.first.imageUrls, isNotEmpty);
      expect(Uri.parse(chapters.first.imageUrls.first).scheme, 'file');
    });

    test('uses persisted local txt split long chapter default', () async {
      final sourceFile = File('${tempDir.path}/system_split.txt');
      await sourceFile.writeAsString('第一章\n内容');

      final prefs = await SharedPreferences.getInstance();
      final systemSettingsService = ReaderSystemSettingsService(
        preferences: prefs,
      );
      await systemSettingsService.saveLocalTxtSplitLongChapterEnabled(false);

      final service = LocalBookImportService(
        localBookRepository: LocalBookRepositoryImpl(database),
        bookshelfService: BookshelfService(preferences: prefs),
        readerSystemSettingsService: systemSettingsService,
        localBookStorageService: storageService,
        logger: AppLogger.instance,
        sourceLoginStateService: SourceLoginStateService(),
      );

      final result = await service.importFromFile(filePath: sourceFile.path);
      expect(result.localBook.splitLongChapter, isFalse);

      final stored = await database.getLocalBookById(result.localBook.id);
      expect(stored, isNotNull);
      expect(stored!.splitLongChapter, isFalse);
    });

    test(
      'returns after persistence and starts warm up after a short delay',
      () async {
        final sourceFile = File('${tempDir.path}/async_import.txt');
        await sourceFile.writeAsString('第一章\n内容');

        final indexCompleter = Completer<List<LocalChapter>>();
        final fakeIndexService = _FakeLocalBookIndexService(
          localBookRepository: LocalBookRepositoryImpl(database),
          storageService: storageService,
          onEnsureIndexed: () => indexCompleter.future,
        );
        final service = LocalBookImportService(
          localBookRepository: LocalBookRepositoryImpl(database),
          bookshelfService: BookshelfService(
            preferences: await SharedPreferences.getInstance(),
          ),
          readerSystemSettingsService: ReaderSystemSettingsService(),
          localBookStorageService: storageService,
          logger: AppLogger.instance,
          sourceLoginStateService: SourceLoginStateService(),
          localBookIndexService: fakeIndexService,
          warmUpDelay: const Duration(milliseconds: 20),
        );

        final result = await service.importFromFile(
          filePath: sourceFile.path,
          waitForIndexing: false,
        );

        expect(result.localBook.id, startsWith('local_'));
        expect(fakeIndexService.ensureIndexedCallCount, 0);

        await Future<void>.delayed(const Duration(milliseconds: 40));
        expect(fakeIndexService.ensureIndexedCallCount, 1);

        indexCompleter.complete(const <LocalChapter>[]);
      },
    );

    test('ignores expected warm up failures without warning log', () async {
      final sourceFile = File('${tempDir.path}/warmup_ignore.txt');
      await sourceFile.writeAsString('第一章\n内容');

      final logger = _RecordingLogger();
      final fakeIndexService = _FakeLocalBookIndexService(
        localBookRepository: LocalBookRepositoryImpl(database),
        storageService: storageService,
        onEnsureIndexed:
            () => Future<List<LocalChapter>>.error(
              AppException(
                code: ErrorCode.validation,
                stage: ErrorStage.content,
                briefMessage: '本地书籍文件已失效，原文件也不可用，请重新导入。',
              ),
            ),
      );
      final service = LocalBookImportService(
        localBookRepository: LocalBookRepositoryImpl(database),
        bookshelfService: BookshelfService(
          preferences: await SharedPreferences.getInstance(),
        ),
        readerSystemSettingsService: ReaderSystemSettingsService(),
        localBookStorageService: storageService,
        logger: logger,
        sourceLoginStateService: SourceLoginStateService(),
        localBookIndexService: fakeIndexService,
        warmUpDelay: Duration.zero,
      );

      await service.importFromFile(
        filePath: sourceFile.path,
        waitForIndexing: false,
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(logger.warnLogs, isEmpty);
    });

    test('logs unexpected warm up failures', () async {
      final sourceFile = File('${tempDir.path}/warmup_warn.txt');
      await sourceFile.writeAsString('第一章\n内容');

      final logger = _RecordingLogger();
      final fakeIndexService = _FakeLocalBookIndexService(
        localBookRepository: LocalBookRepositoryImpl(database),
        storageService: storageService,
        onEnsureIndexed:
            () => Future<List<LocalChapter>>.error(
              AppException(
                code: ErrorCode.unknown,
                stage: ErrorStage.content,
                briefMessage: '模拟后台索引异常',
              ),
            ),
      );
      final service = LocalBookImportService(
        localBookRepository: LocalBookRepositoryImpl(database),
        bookshelfService: BookshelfService(
          preferences: await SharedPreferences.getInstance(),
        ),
        readerSystemSettingsService: ReaderSystemSettingsService(),
        localBookStorageService: storageService,
        logger: logger,
        sourceLoginStateService: SourceLoginStateService(),
        localBookIndexService: fakeIndexService,
        warmUpDelay: Duration.zero,
      );

      await service.importFromFile(
        filePath: sourceFile.path,
        waitForIndexing: false,
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(logger.warnLogs, hasLength(1));
      expect(logger.warnLogs.single.message, 'Warm up local book index failed');
    });
  });
}

class _FakeLocalBookIndexService extends LocalBookIndexService {
  _FakeLocalBookIndexService({
    required super.localBookRepository,
    required super.storageService,
    required Future<List<LocalChapter>> Function() onEnsureIndexed,
  }) : _onEnsureIndexed = onEnsureIndexed;

  final Future<List<LocalChapter>> Function() _onEnsureIndexed;
  int ensureIndexedCallCount = 0;

  @override
  Future<List<LocalChapter>> ensureIndexed({
    required String bookId,
    bool force = false,
  }) async {
    ensureIndexedCallCount += 1;
    return _onEnsureIndexed();
  }
}

class _FakePdfSuccessParser implements LocalBookParser {
  const _FakePdfSuccessParser();

  @override
  Future<LocalParsedBook> parse(LocalBook book) async {
    return const LocalParsedBook(
      chapters: <LocalParsedChapter>[
        LocalParsedChapter(title: '第 1 页', content: '第一页内容'),
        LocalParsedChapter(title: '第 2 页', content: '第二页内容'),
      ],
      title: 'PDF 标题',
    );
  }

  @override
  bool supports(LocalBookFormat format) => format == LocalBookFormat.pdf;
}

class _FakeKindleSuccessParser implements LocalBookParser {
  const _FakeKindleSuccessParser();

  @override
  Future<LocalParsedBook> parse(LocalBook book) async {
    return const LocalParsedBook(
      chapters: <LocalParsedChapter>[
        LocalParsedChapter(title: '第一章', content: 'Kindle 正文'),
      ],
      title: 'Kindle 标题',
      author: 'Kindle 作者',
    );
  }

  @override
  bool supports(LocalBookFormat format) =>
      format == LocalBookFormat.mobi ||
      format == LocalBookFormat.azw ||
      format == LocalBookFormat.azw3;
}

class _RecordingLogger implements AppLogger {
  final List<_LogEntry> warnLogs = <_LogEntry>[];

  @override
  void info(String message, {Map<String, Object?> context = const {}}) {}

  @override
  void warn(String message, {Map<String, Object?> context = const {}}) {
    warnLogs.add(_LogEntry(message: message, context: context));
  }

  @override
  void error(
    String message, {
    AppException? exception,
    Map<String, Object?> context = const {},
  }) {}
}

class _LogEntry {
  const _LogEntry({required this.message, required this.context});

  final String message;
  final Map<String, Object?> context;
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

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_appread/core/errors/app_exception.dart';
import 'package:flutter_appread/data/datasources/local/app_database.dart';
import 'package:flutter_appread/data/repositories/local_book_repository_impl.dart';
import 'package:flutter_appread/features/bookshelf/application/bookshelf_service.dart';
import 'package:flutter_appread/features/bookshelf/application/local_book_import_service.dart';
import 'package:flutter_appread/features/reader/application/reader_system_settings_service.dart';
import 'package:flutter_appread/features/reader/application/local/local_book_storage_service.dart';
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

    test('imports txt file and writes bookshelf/local book records', () async {
      final sourceFile = File('${tempDir.path}/demo.txt');
      await sourceFile.writeAsString('第一章\n内容');

      final prefs = await SharedPreferences.getInstance();
      final service = LocalBookImportService(
        localBookRepository: LocalBookRepositoryImpl(database),
        bookshelfService: BookshelfService(preferences: prefs),
        localBookStorageService: storageService,
      );

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
      final service = LocalBookImportService(
        localBookRepository: LocalBookRepositoryImpl(database),
        bookshelfService: BookshelfService(preferences: prefs),
        localBookStorageService: storageService,
      );

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

    test('re-import by same source path keeps same local book id', () async {
      final sourceFile = File('${tempDir.path}/same.txt');
      await sourceFile.writeAsString('初始内容');

      final service = LocalBookImportService(
        localBookRepository: LocalBookRepositoryImpl(database),
        bookshelfService: BookshelfService(
          preferences: await SharedPreferences.getInstance(),
        ),
        localBookStorageService: storageService,
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
      final service = LocalBookImportService(
        localBookRepository: LocalBookRepositoryImpl(database),
        bookshelfService: BookshelfService(preferences: prefs),
        localBookStorageService: storageService,
      );

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
      final sourceFile = File('${tempDir.path}/invalid.pdf');
      await sourceFile.writeAsString('pdf');

      final service = LocalBookImportService(
        localBookRepository: LocalBookRepositoryImpl(database),
        bookshelfService: BookshelfService(
          preferences: await SharedPreferences.getInstance(),
        ),
        localBookStorageService: storageService,
      );

      expect(
        () => service.importFromFile(filePath: sourceFile.path),
        throwsA(
          isA<AppException>().having(
            (error) => error.briefMessage,
            'briefMessage',
            contains('仅支持导入 txt 或 epub'),
          ),
        ),
      );
    });

    test(
      'uses system setting for local txt split long chapter default',
      () async {
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
        );

        final result = await service.importFromFile(filePath: sourceFile.path);
        expect(result.localBook.splitLongChapter, isFalse);

        final stored = await database.getLocalBookById(result.localBook.id);
        expect(stored, isNotNull);
        expect(stored!.splitLongChapter, isFalse);
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

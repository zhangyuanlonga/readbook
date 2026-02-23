import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_appread/core/errors/app_exception.dart';
import 'package:flutter_appread/data/datasources/local/app_database.dart';
import 'package:flutter_appread/data/repositories/local_book_repository_impl.dart';
import 'package:flutter_appread/features/bookshelf/application/bookshelf_service.dart';
import 'package:flutter_appread/features/bookshelf/application/local_book_import_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LocalBookImportService', () {
    late AppDatabase database;
    late Directory tempDir;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      database = AppDatabase(executor: NativeDatabase.memory());
      tempDir = await Directory.systemTemp.createTemp('local_book_import_test');
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
        supportDirectoryProvider: () async => tempDir,
      );

      final result = await service.importFromFile(
        filePath: sourceFile.path,
        displayName: '演示书籍.txt',
      );

      expect(result.localBook.id, startsWith('local_'));
      expect(result.localBook.format.name, 'txt');
      expect(result.localBook.title, '演示书籍');
      expect(File(result.localBook.storagePath).existsSync(), isTrue);

      final stored = await database.getLocalBookById(result.localBook.id);
      expect(stored, isNotNull);
      expect(stored!.sourcePath, sourceFile.path);

      final bookshelf = await BookshelfService(preferences: prefs).getAll();
      expect(bookshelf, hasLength(1));
      expect(bookshelf.first.bookId, result.localBook.id);
      expect(
        bookshelf.first.sourceId,
        LocalBookImportService.localBookSourceId,
      );
      expect(bookshelf.first.detailUrl, 'local://book/${result.localBook.id}');
    });

    test('re-import by same source path keeps same local book id', () async {
      final sourceFile = File('${tempDir.path}/same.txt');
      await sourceFile.writeAsString('初始内容');

      final service = LocalBookImportService(
        localBookRepository: LocalBookRepositoryImpl(database),
        bookshelfService: BookshelfService(
          preferences: await SharedPreferences.getInstance(),
        ),
        supportDirectoryProvider: () async => tempDir,
      );

      final first = await service.importFromFile(filePath: sourceFile.path);

      await sourceFile.writeAsString('覆盖内容');
      final second = await service.importFromFile(filePath: sourceFile.path);

      expect(second.localBook.id, first.localBook.id);
      expect(second.localBook.storagePath, first.localBook.storagePath);
      expect(File(second.localBook.storagePath).readAsStringSync(), '覆盖内容');
    });

    test('removes local book storage and records', () async {
      final sourceFile = File('${tempDir.path}/remove.txt');
      await sourceFile.writeAsString('待删除内容');

      final prefs = await SharedPreferences.getInstance();
      final service = LocalBookImportService(
        localBookRepository: LocalBookRepositoryImpl(database),
        bookshelfService: BookshelfService(preferences: prefs),
        supportDirectoryProvider: () async => tempDir,
      );

      final result = await service.importFromFile(filePath: sourceFile.path);
      final storageFile = File(result.localBook.storagePath);
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
        supportDirectoryProvider: () async => tempDir,
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
  });
}

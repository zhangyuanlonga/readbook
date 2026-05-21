// ignore_for_file: depend_on_referenced_packages

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/data/datasources/local/app_database.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  group('AppDatabase bookshelf migration', () {
    late Directory tempDir;
    late File dbFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'app_database_bookshelf_migration_test',
      );
      dbFile = File('${tempDir.path}/app.sqlite');
    });

    tearDown(() async {
      if (dbFile.existsSync()) {
        dbFile.deleteSync();
      }
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('upgrades v29 database and creates bookshelf tables', () async {
      await _seedCurrentSchema(dbFile);

      final sqliteDb = sqlite.sqlite3.open(dbFile.path);
      try {
        sqliteDb.execute('DROP TABLE IF EXISTS bookshelf_books;');
        sqliteDb.execute('DROP TABLE IF EXISTS bookshelf_tag_assignments;');
        sqliteDb.execute('DROP TABLE IF EXISTS bookshelf_tag_metadata;');
        sqliteDb.execute('DROP TABLE IF EXISTS bookshelf_category_metadata;');
        sqliteDb.execute('DROP TABLE IF EXISTS bookshelf_base_filter_orders;');
        sqliteDb.execute('DROP INDEX IF EXISTS idx_bookshelf_books_added_at;');
        sqliteDb.execute(
          'DROP INDEX IF EXISTS idx_bookshelf_tag_assignments_book;',
        );
        sqliteDb.execute('PRAGMA user_version = 29;');
      } finally {
        sqliteDb.close();
      }

      final database = AppDatabase(executor: NativeDatabase(dbFile));
      addTearDown(database.close);
      await database.customSelect('SELECT 1').get();

      Future<void> expectTable(String name) async {
        final rows =
            await database
                .customSelect(
                  "SELECT name FROM sqlite_master WHERE type = 'table' AND name = '$name'",
                )
                .get();
        expect(rows, hasLength(1));
      }

      await expectTable('bookshelf_books');
      await expectTable('bookshelf_tag_assignments');
      await expectTable('bookshelf_tag_metadata');
      await expectTable('bookshelf_category_metadata');
      await expectTable('bookshelf_base_filter_orders');

      final indexes =
          await database
              .customSelect('PRAGMA index_list(bookshelf_books)')
              .get();
      expect(
        indexes.any(
          (row) => row.data['name'] == 'idx_bookshelf_books_added_at',
        ),
        isTrue,
      );
    });
  });
}

Future<void> _seedCurrentSchema(File dbFile) async {
  final database = AppDatabase(executor: NativeDatabase(dbFile));
  await database.customSelect('SELECT 1').get();
  await database.close();
}

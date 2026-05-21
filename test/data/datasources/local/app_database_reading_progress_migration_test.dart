// ignore_for_file: depend_on_referenced_packages

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/data/datasources/local/app_database.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  group('AppDatabase reading progress migration', () {
    late Directory tempDir;
    late File dbFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'app_database_reading_progress_migration_test',
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

    test('upgrades v27 database and creates reading_progresses table', () async {
      await _seedCurrentSchema(dbFile);

      final sqliteDb = sqlite.sqlite3.open(dbFile.path);
      try {
        sqliteDb.execute('DROP TABLE IF EXISTS reading_progresses;');
        sqliteDb.execute('DROP INDEX IF EXISTS idx_reading_progresses_updated_at;');
        sqliteDb.execute('PRAGMA user_version = 27;');
      } finally {
        sqliteDb.close();
      }

      final database = AppDatabase(executor: NativeDatabase(dbFile));
      addTearDown(database.close);
      await database.customSelect('SELECT 1').get();

      final tables =
          await database
              .customSelect(
                "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'reading_progresses'",
              )
              .get();
      expect(tables, hasLength(1));

      final columns =
          await database
              .customSelect('PRAGMA table_info(reading_progresses)')
              .get();
      expect(columns.any((row) => row.data['name'] == 'book_id'), isTrue);
      expect(columns.any((row) => row.data['name'] == 'logical_position_json'), isTrue);
      expect(columns.any((row) => row.data['name'] == 'updated_at'), isTrue);

      final indexes =
          await database
              .customSelect('PRAGMA index_list(reading_progresses)')
              .get();
      expect(
        indexes.any(
          (row) => row.data['name'] == 'idx_reading_progresses_updated_at',
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

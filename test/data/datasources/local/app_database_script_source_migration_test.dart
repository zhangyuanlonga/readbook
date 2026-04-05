// ignore_for_file: depend_on_referenced_packages

import 'dart:io';

import 'package:drift/native.dart';
import 'package:shuxiang_reading_next/data/datasources/local/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  group('AppDatabase script source migration', () {
    late Directory tempDir;
    late File dbFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'app_database_script_source_migration_test',
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

    test(
      'migrates schema from v15 to v16 and creates script_sources table',
      () async {
        await _seedCurrentSchema(dbFile);

        final sqliteDb = sqlite.sqlite3.open(dbFile.path);
        try {
          sqliteDb.execute('DROP TABLE script_sources;');
          sqliteDb.execute('PRAGMA user_version = 15;');
        } finally {
          sqliteDb.close();
        }

        final database = AppDatabase(executor: NativeDatabase(dbFile));
        addTearDown(database.close);

        final columns =
            await database
                .customSelect('PRAGMA table_info(script_sources)')
                .get();

        expect(columns.any((row) => row.data['name'] == 'id'), isTrue);
        expect(columns.any((row) => row.data['name'] == 'name'), isTrue);
        expect(columns.any((row) => row.data['name'] == 'source_code'), isTrue);
        expect(columns.any((row) => row.data['name'] == 'enabled'), isTrue);
        expect(columns.any((row) => row.data['name'] == 'created_at'), isTrue);
        expect(columns.any((row) => row.data['name'] == 'updated_at'), isTrue);
      },
    );
  });
}

Future<void> _seedCurrentSchema(File dbFile) async {
  final database = AppDatabase(executor: NativeDatabase(dbFile));
  await database.customSelect('SELECT 1').get();
  await database.close();
}

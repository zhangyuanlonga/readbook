// ignore_for_file: depend_on_referenced_packages

import 'dart:io';

import 'package:drift/native.dart';
import 'package:shuxiang_reading_next/data/datasources/local/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  group('AppDatabase reading record migration', () {
    late Directory tempDir;
    late File dbFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'app_database_read_record_migration_test',
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

    test('migrates reading record tables from v11 to v12', () async {
      await _seedCurrentSchema(dbFile);

      final sqliteDb = sqlite.sqlite3.open(dbFile.path);
      try {
        sqliteDb.execute('DROP TABLE reading_records;');
        sqliteDb.execute('DROP TABLE reading_record_days;');
        sqliteDb.execute('DROP TABLE reading_record_sessions;');

        sqliteDb.execute('''
          CREATE TABLE reading_records (
            book_id TEXT NOT NULL PRIMARY KEY,
            source_id TEXT NOT NULL,
            detail_url TEXT NOT NULL,
            book_title TEXT NOT NULL,
            book_author TEXT,
            cover_url TEXT,
            last_chapter_id TEXT,
            last_chapter_title TEXT,
            last_chapter_index INTEGER,
            last_chapter_url TEXT,
            last_position_ratio REAL NOT NULL DEFAULT 0,
            total_read_millis INTEGER NOT NULL DEFAULT 0,
            last_read_at INTEGER NOT NULL
          );
        ''');
        sqliteDb.execute('''
          CREATE TABLE reading_record_days (
            book_id TEXT NOT NULL,
            date_key TEXT NOT NULL,
            book_title TEXT NOT NULL,
            book_author TEXT,
            cover_url TEXT,
            read_millis INTEGER NOT NULL DEFAULT 0,
            first_read_at INTEGER NOT NULL,
            last_read_at INTEGER NOT NULL,
            PRIMARY KEY (book_id, date_key)
          );
        ''');
        sqliteDb.execute('''
          CREATE TABLE reading_record_sessions (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            book_id TEXT NOT NULL,
            source_id TEXT NOT NULL,
            detail_url TEXT NOT NULL,
            book_title TEXT NOT NULL,
            book_author TEXT,
            cover_url TEXT,
            chapter_id TEXT,
            chapter_title TEXT,
            chapter_index INTEGER,
            chapter_url TEXT,
            start_at INTEGER NOT NULL,
            end_at INTEGER NOT NULL,
            duration_millis INTEGER NOT NULL DEFAULT 0,
            start_position_ratio REAL NOT NULL DEFAULT 0,
            end_position_ratio REAL NOT NULL DEFAULT 0
          );
        ''');

        sqliteDb.execute('''
          INSERT INTO reading_records (
            book_id,
            source_id,
            detail_url,
            book_title,
            book_author,
            last_position_ratio,
            total_read_millis,
            last_read_at
          ) VALUES (
            'book_legacy',
            'source_legacy',
            'https://example.com/books/legacy',
            '旧版记录',
            '作者甲',
            0.5,
            600000,
            1711000000000
          );
        ''');
        sqliteDb.execute('''
          INSERT INTO reading_record_days (
            book_id,
            date_key,
            book_title,
            book_author,
            read_millis,
            first_read_at,
            last_read_at
          ) VALUES (
            'book_legacy',
            '2026-03-21',
            '旧版记录',
            '作者甲',
            600000,
            1711000000000,
            1711000600000
          );
        ''');
        sqliteDb.execute('''
          INSERT INTO reading_record_sessions (
            book_id,
            source_id,
            detail_url,
            book_title,
            book_author,
            chapter_id,
            chapter_title,
            chapter_index,
            chapter_url,
            start_at,
            end_at,
            duration_millis,
            start_position_ratio,
            end_position_ratio
          ) VALUES (
            'book_legacy',
            'source_legacy',
            'https://example.com/books/legacy',
            '旧版记录',
            '作者甲',
            'chapter_1',
            '第一章',
            0,
            'https://example.com/books/legacy/1',
            1711000000000,
            1711000600000,
            600000,
            0.1,
            0.8
          );
        ''');
        sqliteDb.execute('PRAGMA user_version = 11;');
      } finally {
        sqliteDb.close();
      }

      final database = AppDatabase(executor: NativeDatabase(dbFile));
      addTearDown(database.close);

      final record = await database.getReadingRecordByBookId('book_legacy');
      expect(record, isNotNull);
      expect(record!.totalReadChars, 0);

      final day = await database.getReadingRecordDay(
        bookId: 'book_legacy',
        dateKey: '2026-03-21',
      );
      expect(day, isNotNull);
      expect(day!.readChars, 0);

      final sessions = await database.listReadingRecordSessionsByBookId(
        'book_legacy',
      );
      expect(sessions, hasLength(1));
      expect(sessions.first.readChars, 0);

      final recordColumns =
          await database
              .customSelect('PRAGMA table_info(reading_records)')
              .get();
      final dayColumns =
          await database
              .customSelect('PRAGMA table_info(reading_record_days)')
              .get();
      final sessionColumns =
          await database
              .customSelect('PRAGMA table_info(reading_record_sessions)')
              .get();

      expect(
        recordColumns.any((row) => row.data['name'] == 'total_read_chars'),
        isTrue,
      );
      expect(dayColumns.any((row) => row.data['name'] == 'read_chars'), isTrue);
      expect(
        sessionColumns.any((row) => row.data['name'] == 'read_chars'),
        isTrue,
      );
    });

    test(
      'upgrades v8 database without re-adding reading record columns',
      () async {
        await _seedCurrentSchema(dbFile);

        final sqliteDb = sqlite.sqlite3.open(dbFile.path);
        try {
          sqliteDb.execute('DROP TABLE reading_records;');
          sqliteDb.execute('DROP TABLE reading_record_days;');
          sqliteDb.execute('DROP TABLE reading_record_sessions;');
          sqliteDb.execute('PRAGMA user_version = 8;');
        } finally {
          sqliteDb.close();
        }

        final database = AppDatabase(executor: NativeDatabase(dbFile));
        addTearDown(database.close);

        final recordColumns =
            await database
                .customSelect('PRAGMA table_info(reading_records)')
                .get();
        final dayColumns =
            await database
                .customSelect('PRAGMA table_info(reading_record_days)')
                .get();
        final sessionColumns =
            await database
                .customSelect('PRAGMA table_info(reading_record_sessions)')
                .get();

        expect(
          recordColumns.any((row) => row.data['name'] == 'total_read_chars'),
          isTrue,
        );
        expect(
          dayColumns.any((row) => row.data['name'] == 'read_chars'),
          isTrue,
        );
        expect(
          sessionColumns.any((row) => row.data['name'] == 'read_chars'),
          isTrue,
        );
      },
    );

    test('upgrades v2 database without re-adding local book columns', () async {
      await _seedCurrentSchema(dbFile);

      final sqliteDb = sqlite.sqlite3.open(dbFile.path);
      try {
        sqliteDb.execute('DROP TABLE local_chapters;');
        sqliteDb.execute('DROP TABLE local_books;');
        sqliteDb.execute('DROP TABLE search_source_hits;');
        sqliteDb.execute('DROP TABLE bookmarks;');
        sqliteDb.execute('DROP TABLE reading_records;');
        sqliteDb.execute('DROP TABLE reading_record_days;');
        sqliteDb.execute('DROP TABLE reading_record_sessions;');
        sqliteDb.execute('PRAGMA user_version = 2;');
      } finally {
        sqliteDb.close();
      }

      final database = AppDatabase(executor: NativeDatabase(dbFile));
      addTearDown(database.close);

      final localBookColumns =
          await database.customSelect('PRAGMA table_info(local_books)').get();

      expect(
        localBookColumns.any((row) => row.data['name'] == 'txt_toc_rule_name'),
        isFalse,
      );
      expect(
        localBookColumns.any(
          (row) => row.data['name'] == 'txt_toc_rule_pattern',
        ),
        isFalse,
      );
      expect(
        localBookColumns.any((row) => row.data['name'] == 'split_long_chapter'),
        isTrue,
      );
      expect(
        localBookColumns.any((row) => row.data['name'] == 'charset'),
        isTrue,
      );
      expect(
        localBookColumns.any((row) => row.data['name'] == 'source_file_size'),
        isTrue,
      );
      expect(
        localBookColumns.any(
          (row) => row.data['name'] == 'source_file_last_modified_ms',
        ),
        isTrue,
      );
      expect(
        localBookColumns.any(
          (row) => row.data['name'] == 'storage_file_last_modified_ms',
        ),
        isTrue,
      );

      final localChapterColumns =
          await database
              .customSelect('PRAGMA table_info(local_chapters)')
              .get();
      expect(
        localChapterColumns.any((row) => row.data['name'] == 'image_urls_json'),
        isTrue,
      );
    });

    test('drops deprecated local txt toc columns from v14 to v15', () async {
      await _seedCurrentSchema(dbFile);

      final sqliteDb = sqlite.sqlite3.open(dbFile.path);
      try {
        sqliteDb.execute(
          'ALTER TABLE local_books ADD COLUMN txt_toc_rule_name TEXT;',
        );
        sqliteDb.execute(
          'ALTER TABLE local_books ADD COLUMN txt_toc_rule_pattern TEXT;',
        );
        sqliteDb.execute('''
          INSERT INTO local_books (
            id,
            title,
            format,
            storage_path,
            source_path,
            charset,
            file_size,
            author,
            cover_path,
            source_file_size,
            source_file_last_modified_ms,
            storage_file_last_modified_ms,
            index_status,
            chapter_count,
            last_error,
            txt_toc_rule_name,
            txt_toc_rule_pattern,
            split_long_chapter,
            created_at,
            updated_at
          ) VALUES (
            'local_v14_1',
            '旧版本地图书',
            'txt',
            '/tmp/local_v14_1.txt',
            '/tmp/source_v14_1.txt',
            'utf-8',
            1024,
            '作者甲',
            null,
            1024,
            1711000000000,
            1711000000000,
            'ready',
            12,
            null,
            'legacy',
            'legacy-pattern',
            1,
            1711000000000,
            1711000000000
          );
        ''');
        sqliteDb.execute('PRAGMA user_version = 14;');
      } finally {
        sqliteDb.close();
      }

      final database = AppDatabase(executor: NativeDatabase(dbFile));
      addTearDown(database.close);

      final localBookColumns =
          await database.customSelect('PRAGMA table_info(local_books)').get();
      expect(
        localBookColumns.any((row) => row.data['name'] == 'txt_toc_rule_name'),
        isFalse,
      );
      expect(
        localBookColumns.any(
          (row) => row.data['name'] == 'txt_toc_rule_pattern',
        ),
        isFalse,
      );

      final migrated = await database.getLocalBookById('local_v14_1');
      expect(migrated, isNotNull);
      expect(migrated!.title, '旧版本地图书');
      expect(migrated.chapterCount, 12);
      expect(migrated.splitLongChapter, isTrue);
      expect(migrated.charset, 'utf-8');
    });
  });
}

Future<void> _seedCurrentSchema(File dbFile) async {
  final seedDatabase = AppDatabase(executor: NativeDatabase(dbFile));
  await seedDatabase.customSelect('SELECT 1').get();
  await seedDatabase.close();
}

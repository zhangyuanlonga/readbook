import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../domain/entities/bookmark.dart';
import '../../../domain/entities/local_book.dart';
import '../../../domain/entities/local_chapter.dart';
import '../../../domain/entities/reader_replace_preference.dart';
import '../../../domain/entities/reader_replace_rule.dart';
import '../../../domain/entities/reading_record.dart';
import '../../../domain/entities/reading_record_day.dart';
import '../../../domain/entities/reading_record_session.dart';
import '../../../domain/entities/source_definition.dart';

part 'app_database.g.dart';

class Sources extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get baseUrl => text()();
  TextColumn get group => text().nullable()();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  TextColumn get comment => text().nullable()();
  TextColumn get headersJson => text().withDefault(const Constant('{}'))();
  TextColumn get rulesJson => text().withDefault(const Constant('{}'))();
  TextColumn get healthStatus =>
      text().withDefault(const Constant('unknown'))();
  DateTimeColumn get lastCheckedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get rawJson => text().withDefault(const Constant('{}'))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class ChapterCaches extends Table {
  TextColumn get cacheKey => text()();
  TextColumn get bookId => text()();
  TextColumn get sourceId => text()();
  IntColumn get chapterIndex => integer()();
  TextColumn get chapterTitle => text().nullable()();
  TextColumn get chapterUrl => text()();
  TextColumn get content => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  String get tableName => 'chapter_caches';

  @override
  Set<Column<Object>> get primaryKey => {cacheKey};
}

class StoredLocalBooks extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get format => text()();
  TextColumn get storagePath => text()();
  TextColumn get sourcePath => text().nullable()();
  TextColumn get charset => text().nullable()();
  IntColumn get fileSize => integer()();
  TextColumn get author => text().nullable()();
  TextColumn get coverPath => text().nullable()();
  IntColumn get sourceFileSize => integer().nullable()();
  IntColumn get sourceFileLastModifiedMs => integer().nullable()();
  IntColumn get storageFileLastModifiedMs => integer().nullable()();
  TextColumn get indexStatus => text().withDefault(const Constant('pending'))();
  IntColumn get chapterCount => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
  TextColumn get txtTocRuleName => text().nullable()();
  TextColumn get txtTocRulePattern => text().nullable()();
  BoolColumn get splitLongChapter =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  String get tableName => 'local_books';

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class StoredLocalChapters extends Table {
  TextColumn get id => text()();
  TextColumn get bookId => text()();
  IntColumn get chapterIndex => integer()();
  TextColumn get title => text()();
  TextColumn get content => text()();
  TextColumn get imageUrlsJson => text().withDefault(const Constant('[]'))();
  IntColumn get startOffset => integer().nullable()();
  IntColumn get endOffset => integer().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  String get tableName => 'local_chapters';

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {bookId, chapterIndex},
  ];
}

class StoredBookmarks extends Table {
  TextColumn get id => text()();
  TextColumn get bookId => text()();
  TextColumn get chapterId => text()();
  IntColumn get chapterIndex => integer()();
  IntColumn get startOffset => integer()();
  IntColumn get endOffset => integer()();
  TextColumn get snippet => text()();
  BoolColumn get isBold => boolean().withDefault(const Constant(false))();
  BoolColumn get isUnderline => boolean().withDefault(const Constant(false))();
  BoolColumn get isWavy => boolean().withDefault(const Constant(false))();
  TextColumn get color => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  String get tableName => 'bookmarks';

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class StoredReadingRecords extends Table {
  TextColumn get bookId => text()();
  TextColumn get sourceId => text()();
  TextColumn get detailUrl => text()();
  TextColumn get bookTitle => text()();
  TextColumn get bookAuthor => text().nullable()();
  TextColumn get coverUrl => text().nullable()();
  TextColumn get lastChapterId => text().nullable()();
  TextColumn get lastChapterTitle => text().nullable()();
  IntColumn get lastChapterIndex => integer().nullable()();
  TextColumn get lastChapterUrl => text().nullable()();
  RealColumn get lastPositionRatio => real().withDefault(const Constant(0))();
  IntColumn get totalReadMillis => integer().withDefault(const Constant(0))();
  IntColumn get totalReadChars => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastReadAt => dateTime()();

  @override
  String get tableName => 'reading_records';

  @override
  Set<Column<Object>> get primaryKey => {bookId};
}

class StoredReadingRecordDays extends Table {
  TextColumn get bookId => text()();
  TextColumn get dateKey => text()();
  TextColumn get bookTitle => text()();
  TextColumn get bookAuthor => text().nullable()();
  TextColumn get coverUrl => text().nullable()();
  IntColumn get readMillis => integer().withDefault(const Constant(0))();
  IntColumn get readChars => integer().withDefault(const Constant(0))();
  DateTimeColumn get firstReadAt => dateTime()();
  DateTimeColumn get lastReadAt => dateTime()();

  @override
  String get tableName => 'reading_record_days';

  @override
  Set<Column<Object>> get primaryKey => {bookId, dateKey};
}

class StoredReadingRecordSessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get bookId => text()();
  TextColumn get sourceId => text()();
  TextColumn get detailUrl => text()();
  TextColumn get bookTitle => text()();
  TextColumn get bookAuthor => text().nullable()();
  TextColumn get coverUrl => text().nullable()();
  TextColumn get chapterId => text().nullable()();
  TextColumn get chapterTitle => text().nullable()();
  IntColumn get chapterIndex => integer().nullable()();
  TextColumn get chapterUrl => text().nullable()();
  DateTimeColumn get startAt => dateTime()();
  DateTimeColumn get endAt => dateTime()();
  IntColumn get durationMillis => integer().withDefault(const Constant(0))();
  IntColumn get readChars => integer().withDefault(const Constant(0))();
  RealColumn get startPositionRatio => real().withDefault(const Constant(0))();
  RealColumn get endPositionRatio => real().withDefault(const Constant(0))();

  @override
  String get tableName => 'reading_record_sessions';
}

class SearchSourceHits extends Table {
  TextColumn get titleNorm => text()();
  TextColumn get authorNorm => text()();
  TextColumn get sourceId => text()();
  TextColumn get sourceName => text().withDefault(const Constant(''))();
  TextColumn get title => text().withDefault(const Constant(''))();
  TextColumn get author => text().nullable()();
  TextColumn get latestChapter => text().nullable()();
  IntColumn get latestChapterNo => integer().nullable()();
  IntColumn get hitCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastHitAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  String get tableName => 'search_source_hits';

  @override
  Set<Column<Object>> get primaryKey => {titleNorm, authorNorm, sourceId};
}

class StoredReaderReplaceRules extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withDefault(const Constant(''))();
  TextColumn get group => text().nullable()();
  TextColumn get pattern => text().withDefault(const Constant(''))();
  TextColumn get replacement => text().withDefault(const Constant(''))();
  TextColumn get scopeMode => text().withDefault(const Constant('all'))();
  TextColumn get scope => text().nullable()();
  TextColumn get excludeScope => text().nullable()();
  BoolColumn get scopeTitle => boolean().withDefault(const Constant(false))();
  BoolColumn get scopeContent => boolean().withDefault(const Constant(true))();
  BoolColumn get isEnabled => boolean().withDefault(const Constant(true))();
  BoolColumn get isRegex => boolean().withDefault(const Constant(true))();
  IntColumn get timeoutMs => integer().withDefault(const Constant(3000))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  String get tableName => 'reader_replace_rules';
}

class StoredReaderReplacePreferences extends Table {
  TextColumn get bookId => text()();
  TextColumn get sourceId => text()();
  TextColumn get detailUrl => text()();
  TextColumn get mode => text().withDefault(const Constant('inherit'))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  String get tableName => 'reader_replace_preferences';

  @override
  Set<Column<Object>> get primaryKey => {bookId, sourceId, detailUrl};
}

const String _readerReplaceRulesTableName = 'reader_replace_rules';
const String _readerReplaceRulesCreateSql = '''
CREATE TABLE IF NOT EXISTS reader_replace_rules (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL DEFAULT '',
  "group" TEXT,
  pattern TEXT NOT NULL DEFAULT '',
  replacement TEXT NOT NULL DEFAULT '',
  scope_mode TEXT NOT NULL DEFAULT 'all',
  scope TEXT,
  exclude_scope TEXT,
  scope_title INTEGER NOT NULL DEFAULT 0,
  scope_content INTEGER NOT NULL DEFAULT 1,
  is_enabled INTEGER NOT NULL DEFAULT 1,
  is_regex INTEGER NOT NULL DEFAULT 1,
  timeout_ms INTEGER NOT NULL DEFAULT 3000,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
)
''';
const String _readerReplacePreferencesTableName = 'reader_replace_preferences';
const String _readerReplacePreferencesCreateSql = '''
CREATE TABLE IF NOT EXISTS reader_replace_preferences (
  book_id TEXT NOT NULL,
  source_id TEXT NOT NULL,
  detail_url TEXT NOT NULL,
  mode TEXT NOT NULL DEFAULT 'inherit',
  updated_at TEXT NOT NULL,
  PRIMARY KEY (book_id, source_id, detail_url)
)
''';

class SourceListCountSummary {
  const SourceListCountSummary({
    required this.totalCount,
    required this.enabledCount,
    required this.novelCount,
    required this.mangaCount,
  });

  final int totalCount;
  final int enabledCount;
  final int novelCount;
  final int mangaCount;
}

class SourceListItem {
  const SourceListItem({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.group,
    required this.enabled,
    required this.comment,
    required this.sourceType,
    required this.lastCheckStatus,
    required this.lastCheckedAt,
  });

  final String id;
  final String name;
  final String baseUrl;
  final String? group;
  final bool enabled;
  final String? comment;
  final int sourceType;
  final SourceHealthStatus lastCheckStatus;
  final DateTime? lastCheckedAt;

  bool get isMangaSource => sourceType == 2;
}

class ChapterCacheBookSummary {
  const ChapterCacheBookSummary({
    required this.bookId,
    required this.sourceId,
    required this.cachedCount,
    required this.updatedAt,
  });

  final String bookId;
  final String sourceId;
  final int cachedCount;
  final DateTime updatedAt;
}

class SearchSourceHitUpsert {
  const SearchSourceHitUpsert({
    required this.titleNorm,
    required this.authorNorm,
    required this.sourceId,
    required this.sourceName,
    required this.title,
    this.author,
    this.latestChapter,
    this.latestChapterNo,
    this.hitIncrement = 1,
  });

  final String titleNorm;
  final String authorNorm;
  final String sourceId;
  final String sourceName;
  final String title;
  final String? author;
  final String? latestChapter;
  final int? latestChapterNo;
  final int hitIncrement;
}

@DriftDatabase(
  tables: [
    Sources,
    ChapterCaches,
    StoredLocalBooks,
    StoredLocalChapters,
    StoredBookmarks,
    StoredReadingRecords,
    StoredReadingRecordDays,
    StoredReadingRecordSessions,
    SearchSourceHits,
    StoredReaderReplacePreferences,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase({QueryExecutor? executor}) : super(executor ?? _openConnection());

  static final AppDatabase instance = AppDatabase();

  @override
  int get schemaVersion => 14;

  static const String _mangaSourceMatcherSql =
      '(raw_json LIKE \'%"sourceType":2,%\' OR '
      'raw_json LIKE \'%"sourceType":2}%\')';

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (migrator) async {
        await migrator.createAll();
        await customStatement(_readerReplaceRulesCreateSql);
        await customStatement(_readerReplacePreferencesCreateSql);
      },
      onUpgrade: (migrator, from, to) async {
        if (from < 2) {
          await migrator.createTable(chapterCaches);
        }
        if (from < 3) {
          await migrator.createTable(storedLocalBooks);
          await migrator.createTable(storedLocalChapters);
        }
        if (from < 4) {
          // rulesJson stores serialized SourceRuleSet; no table migration required.
        }
        if (from < 5) {
          await migrator.createTable(searchSourceHits);
        }
        if (from < 6) {
          await migrator.createTable(storedBookmarks);
        }
        if (from == 6) {
          await _addColumnIfMissing(
            migrator: migrator,
            tableName: storedBookmarks.tableName,
            columnName: 'is_bold',
            addColumn:
                () =>
                    migrator.addColumn(storedBookmarks, storedBookmarks.isBold),
          );
          await _addColumnIfMissing(
            migrator: migrator,
            tableName: storedBookmarks.tableName,
            columnName: 'is_underline',
            addColumn:
                () => migrator.addColumn(
                  storedBookmarks,
                  storedBookmarks.isUnderline,
                ),
          );
          await _addColumnIfMissing(
            migrator: migrator,
            tableName: storedBookmarks.tableName,
            columnName: 'is_wavy',
            addColumn:
                () =>
                    migrator.addColumn(storedBookmarks, storedBookmarks.isWavy),
          );
        }
        if (from < 8) {
          await _addColumnIfMissing(
            migrator: migrator,
            tableName: storedLocalBooks.tableName,
            columnName: 'txt_toc_rule_name',
            addColumn:
                () => migrator.addColumn(
                  storedLocalBooks,
                  storedLocalBooks.txtTocRuleName,
                ),
          );
          await _addColumnIfMissing(
            migrator: migrator,
            tableName: storedLocalBooks.tableName,
            columnName: 'txt_toc_rule_pattern',
            addColumn:
                () => migrator.addColumn(
                  storedLocalBooks,
                  storedLocalBooks.txtTocRulePattern,
                ),
          );
          await _addColumnIfMissing(
            migrator: migrator,
            tableName: storedLocalBooks.tableName,
            columnName: 'split_long_chapter',
            addColumn:
                () => migrator.addColumn(
                  storedLocalBooks,
                  storedLocalBooks.splitLongChapter,
                ),
          );
        }
        if (from < 9) {
          await migrator.createTable(storedReadingRecords);
          await migrator.createTable(storedReadingRecordDays);
          await migrator.createTable(storedReadingRecordSessions);
        }
        if (from < 10) {
          await customStatement(_readerReplaceRulesCreateSql);
        }
        if (from < 11) {
          await customStatement(_readerReplacePreferencesCreateSql);
        }
        if (from < 12) {
          await _addColumnIfMissing(
            migrator: migrator,
            tableName: storedReadingRecords.tableName,
            columnName: 'total_read_chars',
            addColumn:
                () => migrator.addColumn(
                  storedReadingRecords,
                  storedReadingRecords.totalReadChars,
                ),
          );
          await _addColumnIfMissing(
            migrator: migrator,
            tableName: storedReadingRecordDays.tableName,
            columnName: 'read_chars',
            addColumn:
                () => migrator.addColumn(
                  storedReadingRecordDays,
                  storedReadingRecordDays.readChars,
                ),
          );
          await _addColumnIfMissing(
            migrator: migrator,
            tableName: storedReadingRecordSessions.tableName,
            columnName: 'read_chars',
            addColumn:
                () => migrator.addColumn(
                  storedReadingRecordSessions,
                  storedReadingRecordSessions.readChars,
                ),
          );
        }
        if (from < 13) {
          await _addColumnIfMissing(
            migrator: migrator,
            tableName: storedLocalBooks.tableName,
            columnName: 'charset',
            addColumn:
                () => migrator.addColumn(
                  storedLocalBooks,
                  storedLocalBooks.charset,
                ),
          );
          await _addColumnIfMissing(
            migrator: migrator,
            tableName: storedLocalBooks.tableName,
            columnName: 'source_file_size',
            addColumn:
                () => migrator.addColumn(
                  storedLocalBooks,
                  storedLocalBooks.sourceFileSize,
                ),
          );
          await _addColumnIfMissing(
            migrator: migrator,
            tableName: storedLocalBooks.tableName,
            columnName: 'source_file_last_modified_ms',
            addColumn:
                () => migrator.addColumn(
                  storedLocalBooks,
                  storedLocalBooks.sourceFileLastModifiedMs,
                ),
          );
          await _addColumnIfMissing(
            migrator: migrator,
            tableName: storedLocalBooks.tableName,
            columnName: 'storage_file_last_modified_ms',
            addColumn:
                () => migrator.addColumn(
                  storedLocalBooks,
                  storedLocalBooks.storageFileLastModifiedMs,
                ),
          );
        }
        if (from < 14) {
          await _addColumnIfMissing(
            migrator: migrator,
            tableName: storedLocalChapters.tableName,
            columnName: 'image_urls_json',
            addColumn:
                () => migrator.addColumn(
                  storedLocalChapters,
                  storedLocalChapters.imageUrlsJson as GeneratedColumn<Object>,
                ),
          );
        }
      },
    );
  }

  Future<void> _addColumnIfMissing({
    required Migrator migrator,
    required String tableName,
    required String columnName,
    required Future<void> Function() addColumn,
  }) async {
    if (await _tableHasColumn(tableName, columnName)) {
      return;
    }
    await addColumn();
  }

  Future<bool> _tableHasColumn(String tableName, String columnName) async {
    final rows =
        await customSelect(
          'PRAGMA table_info(${_quoteIdentifier(tableName)})',
        ).get();
    return rows.any((row) => row.data['name'] == columnName);
  }

  String _quoteIdentifier(String identifier) {
    final escaped = identifier.replaceAll('"', '""');
    return '"$escaped"';
  }

  Future<List<SourceDefinition>> getAllSources() async {
    final rows =
        await (select(sources)..orderBy([
          (table) => OrderingTerm.asc(table.group),
          (table) => OrderingTerm.asc(table.name),
        ])).get();
    return rows.map(_mapRowToSource).toList();
  }

  Future<Map<String, int>> querySourceTypeMap() async {
    final rows =
        await customSelect(
          'SELECT id, CASE WHEN $_mangaSourceMatcherSql THEN 2 ELSE 0 END AS sourceType '
          'FROM sources',
          readsFrom: {sources},
        ).get();

    final result = <String, int>{};
    for (final row in rows) {
      final sourceId = (row.data['id'] ?? '').toString().trim();
      if (sourceId.isEmpty) {
        continue;
      }
      result[sourceId] = _decodeInt(row.data['sourceType']) ?? 0;
    }
    return result;
  }

  Stream<List<SourceDefinition>> watchAllSources() {
    final query = select(sources)..orderBy([
      (table) => OrderingTerm.asc(table.group),
      (table) => OrderingTerm.asc(table.name),
    ]);
    return query.watch().map(
      (rows) => rows.map(_mapRowToSource).toList(growable: false),
    );
  }

  Stream<List<SourceListItem>> watchSourceListItems() {
    final sql =
        'SELECT id, name, base_url AS baseUrl, "group" AS sourceGroup, '
        'enabled, comment, '
        'CASE WHEN $_mangaSourceMatcherSql THEN 2 ELSE 0 END AS sourceType, '
        'health_status AS healthStatus, last_checked_at AS lastCheckedAt '
        'FROM sources '
        'ORDER BY sourceGroup COLLATE NOCASE ASC, name COLLATE NOCASE ASC';

    return customSelect(sql, readsFrom: {sources}).watch().map(
      (rows) => rows.map(_mapSourceListItem).toList(growable: false),
    );
  }

  Future<List<SourceListItem>> querySourceListItems({
    required int limit,
    required int offset,
    String keyword = '',
    bool? enabledOnly,
    bool? isMangaSource,
    String? groupEquals,
    bool includeUngroupedOnly = false,
  }) async {
    final safeLimit = limit < 1 ? 1 : limit;
    final safeOffset = offset < 0 ? 0 : offset;
    final filter = _buildSourceListSqlFilter(
      keyword: keyword,
      enabledOnly: enabledOnly,
      isMangaSource: isMangaSource,
      groupEquals: groupEquals,
      includeUngroupedOnly: includeUngroupedOnly,
    );

    final rows =
        await customSelect(
          'SELECT id, name, base_url AS baseUrl, "group" AS sourceGroup, '
          'enabled, comment, '
          'CASE WHEN $_mangaSourceMatcherSql THEN 2 ELSE 0 END AS sourceType, '
          'health_status AS healthStatus, last_checked_at AS lastCheckedAt '
          'FROM sources '
          '${filter.whereClause} '
          'ORDER BY sourceGroup COLLATE NOCASE ASC, name COLLATE NOCASE ASC '
          'LIMIT ? OFFSET ?',
          variables: <Variable<Object>>[
            ...filter.variables,
            Variable<int>(safeLimit),
            Variable<int>(safeOffset),
          ],
          readsFrom: {sources},
        ).get();

    return rows.map(_mapSourceListItem).toList(growable: false);
  }

  Future<int> countSourceListItems({
    String keyword = '',
    bool? enabledOnly,
    bool? isMangaSource,
    String? groupEquals,
    bool includeUngroupedOnly = false,
  }) async {
    final filter = _buildSourceListSqlFilter(
      keyword: keyword,
      enabledOnly: enabledOnly,
      isMangaSource: isMangaSource,
      groupEquals: groupEquals,
      includeUngroupedOnly: includeUngroupedOnly,
    );

    final row =
        await customSelect(
          'SELECT COUNT(*) AS totalCount '
          'FROM sources '
          '${filter.whereClause}',
          variables: filter.variables,
          readsFrom: {sources},
        ).getSingle();

    final value = row.data['totalCount'];
    if (value is int) {
      return value;
    }
    if (value is BigInt) {
      return value.toInt();
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value.trim()) ?? 0;
    }
    return 0;
  }

  Future<SourceListCountSummary> summarizeSourceListItems({
    String keyword = '',
    bool? isMangaSource,
    String? groupEquals,
    bool includeUngroupedOnly = false,
  }) async {
    final filter = _buildSourceListSqlFilter(
      keyword: keyword,
      isMangaSource: isMangaSource,
      groupEquals: groupEquals,
      includeUngroupedOnly: includeUngroupedOnly,
    );

    final row =
        await customSelect(
          'SELECT COUNT(*) AS totalCount, '
          'SUM(CASE WHEN enabled = 1 THEN 1 ELSE 0 END) AS enabledCount, '
          'SUM(CASE WHEN $_mangaSourceMatcherSql THEN 1 ELSE 0 END) AS mangaCount '
          'FROM sources '
          '${filter.whereClause}',
          variables: filter.variables,
          readsFrom: {sources},
        ).getSingle();

    final totalCount = _decodeInt(row.data['totalCount']) ?? 0;
    final enabledCount = _decodeInt(row.data['enabledCount']) ?? 0;
    final mangaCount = _decodeInt(row.data['mangaCount']) ?? 0;
    final safeMangaCount = mangaCount.clamp(0, totalCount);
    final novelCount = (totalCount - safeMangaCount).clamp(0, totalCount);

    return SourceListCountSummary(
      totalCount: totalCount,
      enabledCount: enabledCount.clamp(0, totalCount),
      novelCount: novelCount,
      mangaCount: safeMangaCount,
    );
  }

  Future<SourceDefinition?> getSourceById(String sourceId) async {
    final normalized = sourceId.trim();
    if (normalized.isEmpty) {
      return null;
    }

    final row =
        await (select(sources)
          ..where((table) => table.id.equals(normalized))).getSingleOrNull();

    if (row == null) {
      return null;
    }

    return _mapRowToSource(row);
  }

  Future<void> upsertSources(List<SourceDefinition> items) async {
    if (items.isEmpty) {
      return;
    }

    final now = DateTime.now();

    await batch((batch) {
      for (final item in items) {
        batch.insert(
          sources,
          _toCompanion(item, now),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }

  Future<void> setSourceEnabled(String id, bool enabled) {
    return (update(sources)..where((table) => table.id.equals(id))).write(
      SourcesCompanion(
        enabled: Value(enabled),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> setSourceGroup(String id, String? group) {
    final normalized = group?.trim();
    return (update(sources)..where((table) => table.id.equals(id))).write(
      SourcesCompanion(
        group: Value(
          normalized == null || normalized.isEmpty ? null : normalized,
        ),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<List<String>> listSourceGroups() async {
    final query =
        await customSelect(
          'SELECT DISTINCT "group" FROM sources',
          readsFrom: {sources},
        ).get();
    final groups = <String>{};
    for (final row in query) {
      final value = row.data['group'] as String?;
      final normalized = value?.trim() ?? '';
      if (normalized.isNotEmpty) {
        groups.add(normalized);
      }
    }
    final sorted = groups.toList()..sort((a, b) => a.compareTo(b));
    return sorted;
  }

  Future<void> deleteSource(String id) {
    return (delete(sources)..where((table) => table.id.equals(id))).go();
  }

  Future<void> deleteSourcesByIds(List<String> ids) {
    if (ids.isEmpty) {
      return Future.value();
    }

    return (delete(sources)..where((table) => table.id.isIn(ids))).go();
  }

  Future<void> clearSources() => delete(sources).go();

  Future<ChapterCache?> getChapterCache(String cacheKey) {
    final normalizedKey = cacheKey.trim();
    if (normalizedKey.isEmpty) {
      return Future.value(null);
    }

    return (select(chapterCaches)..where(
      (table) => table.cacheKey.equals(normalizedKey),
    )).getSingleOrNull();
  }

  Future<void> upsertChapterCache({
    required String cacheKey,
    required String bookId,
    required String sourceId,
    required int chapterIndex,
    required String chapterUrl,
    required String content,
    String? chapterTitle,
  }) async {
    final normalizedKey = cacheKey.trim();
    final normalizedBookId = bookId.trim();
    final normalizedSourceId = sourceId.trim();
    final normalizedUrl = chapterUrl.trim();

    if (normalizedKey.isEmpty ||
        normalizedBookId.isEmpty ||
        normalizedSourceId.isEmpty ||
        normalizedUrl.isEmpty ||
        content.trim().isEmpty) {
      return;
    }

    final now = DateTime.now();
    final normalizedTitle = chapterTitle?.trim();

    await into(chapterCaches).insert(
      ChapterCachesCompanion(
        cacheKey: Value(normalizedKey),
        bookId: Value(normalizedBookId),
        sourceId: Value(normalizedSourceId),
        chapterIndex: Value(chapterIndex),
        chapterTitle: Value(
          normalizedTitle == null || normalizedTitle.isEmpty
              ? null
              : normalizedTitle,
        ),
        chapterUrl: Value(normalizedUrl),
        content: Value(content),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
      mode: InsertMode.insertOrReplace,
    );
  }

  Future<int> getCachedChapterCount(String bookId) async {
    final normalized = bookId.trim();
    if (normalized.isEmpty) {
      return 0;
    }

    final countExpression = chapterCaches.cacheKey.count();
    final query =
        selectOnly(chapterCaches)
          ..addColumns([countExpression])
          ..where(chapterCaches.bookId.equals(normalized));

    final row = await query.getSingle();
    return row.read(countExpression) ?? 0;
  }

  Stream<int> watchCachedChapterCount(String bookId) {
    final normalized = bookId.trim();
    if (normalized.isEmpty) {
      return const Stream<int>.empty();
    }

    final countExpression = chapterCaches.cacheKey.count();
    final query =
        selectOnly(chapterCaches)
          ..addColumns([countExpression])
          ..where(chapterCaches.bookId.equals(normalized));

    return query.watchSingle().map((row) => row.read(countExpression) ?? 0);
  }

  Future<Map<String, String>> getLatestCachedChapterTitles(
    List<String> bookIds,
  ) async {
    final normalizedIds = bookIds
        .map((bookId) => bookId.trim())
        .where((bookId) => bookId.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (normalizedIds.isEmpty) {
      return <String, String>{};
    }

    final rows =
        await (select(chapterCaches)
              ..where((table) => table.bookId.isIn(normalizedIds))
              ..orderBy([
                (table) => OrderingTerm.desc(table.chapterIndex),
                (table) => OrderingTerm.desc(table.updatedAt),
              ]))
            .get();

    final latestByBookId = <String, String>{};
    for (final row in rows) {
      if (latestByBookId.containsKey(row.bookId)) {
        continue;
      }

      final title = row.chapterTitle?.trim() ?? '';
      if (title.isEmpty) {
        continue;
      }

      latestByBookId[row.bookId] = title;
      if (latestByBookId.length >= normalizedIds.length) {
        break;
      }
    }

    return latestByBookId;
  }

  Future<Map<String, String>> getLatestCachedChapterTitlesByBookSource(
    List<MapEntry<String, String>> bookSourcePairs,
  ) async {
    final normalizedPairs = <MapEntry<String, String>>[];
    final requestPairKeys = <String>{};
    final requestBookIds = <String>{};
    final requestSourceIds = <String>{};

    for (final pair in bookSourcePairs) {
      final bookId = pair.key.trim();
      final sourceId = pair.value.trim();
      if (bookId.isEmpty || sourceId.isEmpty) {
        continue;
      }
      final pairKey = _bookSourcePairKey(bookId: bookId, sourceId: sourceId);
      if (!requestPairKeys.add(pairKey)) {
        continue;
      }
      normalizedPairs.add(MapEntry(bookId, sourceId));
      requestBookIds.add(bookId);
      requestSourceIds.add(sourceId);
    }

    if (normalizedPairs.isEmpty) {
      return <String, String>{};
    }

    final rows =
        await (select(chapterCaches)
              ..where(
                (table) =>
                    table.bookId.isIn(requestBookIds) &
                    table.sourceId.isIn(requestSourceIds),
              )
              ..orderBy([
                (table) => OrderingTerm.desc(table.chapterIndex),
                (table) => OrderingTerm.desc(table.updatedAt),
              ]))
            .get();

    final latestByPairKey = <String, String>{};
    for (final row in rows) {
      final pairKey = _bookSourcePairKey(
        bookId: row.bookId,
        sourceId: row.sourceId,
      );
      if (!requestPairKeys.contains(pairKey)) {
        continue;
      }
      if (latestByPairKey.containsKey(pairKey)) {
        continue;
      }

      final title = row.chapterTitle?.trim() ?? '';
      if (title.isEmpty) {
        continue;
      }

      latestByPairKey[pairKey] = title;
      if (latestByPairKey.length >= normalizedPairs.length) {
        break;
      }
    }

    return latestByPairKey;
  }

  String _bookSourcePairKey({
    required String bookId,
    required String sourceId,
  }) {
    return '${sourceId.trim()}\u0000${bookId.trim()}';
  }

  Future<Set<String>> getCachedChapterCacheKeysForBook(String bookId) async {
    final normalized = bookId.trim();
    if (normalized.isEmpty) {
      return <String>{};
    }

    final query =
        selectOnly(chapterCaches)
          ..addColumns([chapterCaches.cacheKey])
          ..where(chapterCaches.bookId.equals(normalized));

    final rows = await query.get();
    return rows
        .map((row) => row.read(chapterCaches.cacheKey))
        .whereType<String>()
        .toSet();
  }

  Future<void> upsertSearchSourceHits(List<SearchSourceHitUpsert> items) async {
    if (items.isEmpty) {
      return;
    }

    await transaction(() async {
      for (final item in items) {
        final normalizedTitleNorm = item.titleNorm.trim();
        final normalizedAuthorNorm = item.authorNorm.trim();
        final normalizedSourceId = item.sourceId.trim();
        final normalizedSourceName = item.sourceName.trim();
        final normalizedTitle = item.title.trim();
        final normalizedAuthor = _nullableString(item.author);
        final normalizedLatestChapter = _nullableString(item.latestChapter);
        final increment = item.hitIncrement <= 0 ? 1 : item.hitIncrement;

        if (normalizedTitleNorm.isEmpty || normalizedSourceId.isEmpty) {
          continue;
        }

        final now = DateTime.now();
        final existing =
            await (select(searchSourceHits)..where(
              (table) =>
                  table.titleNorm.equals(normalizedTitleNorm) &
                  table.authorNorm.equals(normalizedAuthorNorm) &
                  table.sourceId.equals(normalizedSourceId),
            )).getSingleOrNull();

        if (existing == null) {
          await into(searchSourceHits).insert(
            SearchSourceHitsCompanion(
              titleNorm: Value(normalizedTitleNorm),
              authorNorm: Value(normalizedAuthorNorm),
              sourceId: Value(normalizedSourceId),
              sourceName: Value(
                normalizedSourceName.isEmpty
                    ? normalizedSourceId
                    : normalizedSourceName,
              ),
              title: Value(
                normalizedTitle.isEmpty ? normalizedTitleNorm : normalizedTitle,
              ),
              author: Value(normalizedAuthor),
              latestChapter: Value(normalizedLatestChapter),
              latestChapterNo: Value(item.latestChapterNo),
              hitCount: Value(increment),
              lastHitAt: Value(now),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
          continue;
        }

        await (update(searchSourceHits)..where(
          (table) =>
              table.titleNorm.equals(normalizedTitleNorm) &
              table.authorNorm.equals(normalizedAuthorNorm) &
              table.sourceId.equals(normalizedSourceId),
        )).write(
          SearchSourceHitsCompanion(
            sourceName: Value(
              normalizedSourceName.isEmpty
                  ? existing.sourceName
                  : normalizedSourceName,
            ),
            title: Value(
              normalizedTitle.isEmpty ? existing.title : normalizedTitle,
            ),
            author: Value(normalizedAuthor),
            latestChapter: Value(normalizedLatestChapter),
            latestChapterNo: Value(item.latestChapterNo),
            hitCount: Value(existing.hitCount + increment),
            lastHitAt: Value(now),
            updatedAt: Value(now),
          ),
        );
      }
    });
  }

  Future<Map<String, int>> getSearchSourceHitCounts({
    required String titleNorm,
    required String authorNorm,
  }) async {
    final normalizedTitleNorm = titleNorm.trim();
    final normalizedAuthorNorm = authorNorm.trim();
    if (normalizedTitleNorm.isEmpty) {
      return <String, int>{};
    }

    final rows =
        await (select(searchSourceHits)..where(
          (table) =>
              table.titleNorm.equals(normalizedTitleNorm) &
              table.authorNorm.equals(normalizedAuthorNorm),
        )).get();

    final result = <String, int>{};
    for (final row in rows) {
      final sourceId = row.sourceId.trim();
      if (sourceId.isEmpty) {
        continue;
      }
      final count = row.hitCount < 0 ? 0 : row.hitCount;
      if (count > 0) {
        result[sourceId] = count;
      }
    }
    return result;
  }

  Future<void> clearSearchSourceHits() => delete(searchSourceHits).go();

  int _decodeCount(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is BigInt) {
      return value.toInt();
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value.trim()) ?? 0;
    }
    return 0;
  }

  DateTime _decodeDateTime(Object? value) {
    if (value is DateTime) {
      return value;
    }
    if (value is int) {
      return _decodeEpochDateTime(value);
    }
    if (value is num) {
      return _decodeEpochDateTime(value.toInt());
    }
    if (value is String) {
      final normalized = value.trim();
      final parsedDateTime = DateTime.tryParse(normalized);
      if (parsedDateTime != null) {
        return parsedDateTime;
      }
      final parsedEpoch = int.tryParse(normalized);
      if (parsedEpoch != null) {
        return _decodeEpochDateTime(parsedEpoch);
      }
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  Future<List<ChapterCacheBookSummary>> listCachedBooks() async {
    const sql =
        'SELECT book_id AS bookId, source_id AS sourceId, '
        'COUNT(*) AS cachedCount, MAX(updated_at) AS updatedAt '
        'FROM chapter_caches '
        'GROUP BY book_id, source_id '
        'ORDER BY updatedAt DESC';

    final rows = await customSelect(sql, readsFrom: {chapterCaches}).get();

    return rows
        .map(
          (row) => ChapterCacheBookSummary(
            bookId: (row.data['bookId'] ?? '').toString(),
            sourceId: (row.data['sourceId'] ?? '').toString(),
            cachedCount: _decodeCount(row.data['cachedCount']),
            updatedAt: _decodeDateTime(row.data['updatedAt']),
          ),
        )
        .where((item) => item.bookId.trim().isNotEmpty)
        .toList(growable: false);
  }

  Stream<List<ChapterCacheBookSummary>> watchCachedBooks() {
    const sql =
        'SELECT book_id AS bookId, source_id AS sourceId, '
        'COUNT(*) AS cachedCount, MAX(updated_at) AS updatedAt '
        'FROM chapter_caches '
        'GROUP BY book_id, source_id '
        'ORDER BY updatedAt DESC';

    return customSelect(sql, readsFrom: {chapterCaches}).watch().map(
      (rows) => rows
          .map(
            (row) => ChapterCacheBookSummary(
              bookId: (row.data['bookId'] ?? '').toString(),
              sourceId: (row.data['sourceId'] ?? '').toString(),
              cachedCount: _decodeCount(row.data['cachedCount']),
              updatedAt: _decodeDateTime(row.data['updatedAt']),
            ),
          )
          .where((item) => item.bookId.trim().isNotEmpty)
          .toList(growable: false),
    );
  }

  Future<void> deleteChapterCachesByBookId(String bookId) {
    final normalized = bookId.trim();
    if (normalized.isEmpty) {
      return Future.value();
    }

    return (delete(chapterCaches)
      ..where((table) => table.bookId.equals(normalized))).go();
  }

  Future<void> clearChapterCaches() => delete(chapterCaches).go();

  Future<List<ReaderReplaceRule>> getAllReaderReplaceRules() async {
    final rows =
        await customSelect(
          'SELECT * FROM $_readerReplaceRulesTableName '
          'ORDER BY sort_order ASC, id ASC',
        ).get();
    return rows.map(_mapQueryRowToReaderReplaceRule).toList(growable: false);
  }

  Stream<List<ReaderReplaceRule>> watchAllReaderReplaceRules() {
    return Stream.fromFuture(getAllReaderReplaceRules());
  }

  Future<ReaderReplaceRule?> getReaderReplaceRuleById(int id) async {
    if (id <= 0) {
      return null;
    }
    final row =
        await customSelect(
          'SELECT * FROM $_readerReplaceRulesTableName WHERE id = ? LIMIT 1',
          variables: [Variable<int>(id)],
        ).getSingleOrNull();
    if (row == null) {
      return null;
    }
    return _mapQueryRowToReaderReplaceRule(row);
  }

  Future<void> upsertReaderReplaceRule(ReaderReplaceRule rule) async {
    final normalizedName = rule.name.trim();
    final normalizedPattern = rule.pattern.trim();
    if (normalizedName.isEmpty || normalizedPattern.isEmpty) {
      return;
    }

    final now = DateTime.now();
    final sortOrder =
        rule.sortOrder > 0
            ? rule.sortOrder
            : await _nextReaderReplaceRuleOrder();

    if (rule.id > 0) {
      await customStatement(
        'UPDATE $_readerReplaceRulesTableName '
        'SET name = ?, "group" = ?, pattern = ?, replacement = ?, '
        'scope_mode = ?, scope = ?, exclude_scope = ?, scope_title = ?, '
        'scope_content = ?, is_enabled = ?, is_regex = ?, timeout_ms = ?, '
        'sort_order = ?, created_at = ?, updated_at = ? '
        'WHERE id = ?',
        [
          normalizedName,
          _nullableString(rule.group),
          normalizedPattern,
          rule.replacement,
          rule.scopeMode.name,
          _nullableString(rule.scope),
          _nullableString(rule.excludeScope),
          rule.scopeTitle ? 1 : 0,
          rule.scopeContent ? 1 : 0,
          rule.isEnabled ? 1 : 0,
          rule.isRegex ? 1 : 0,
          rule.safeTimeoutMs,
          sortOrder,
          rule.createdAt.toIso8601String(),
          now.toIso8601String(),
          rule.id,
        ],
      );
      return;
    }

    await customStatement(
      'INSERT INTO $_readerReplaceRulesTableName '
      '(name, "group", pattern, replacement, scope_mode, scope, exclude_scope, '
      'scope_title, scope_content, is_enabled, is_regex, timeout_ms, sort_order, created_at, updated_at) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        normalizedName,
        _nullableString(rule.group),
        normalizedPattern,
        rule.replacement,
        rule.scopeMode.name,
        _nullableString(rule.scope),
        _nullableString(rule.excludeScope),
        rule.scopeTitle ? 1 : 0,
        rule.scopeContent ? 1 : 0,
        rule.isEnabled ? 1 : 0,
        rule.isRegex ? 1 : 0,
        rule.safeTimeoutMs,
        sortOrder,
        now.toIso8601String(),
        now.toIso8601String(),
      ],
    );
  }

  Future<void> deleteReaderReplaceRuleById(int id) async {
    if (id <= 0) {
      return;
    }
    await customStatement(
      'DELETE FROM $_readerReplaceRulesTableName WHERE id = ?',
      [id],
    );
  }

  Future<ReaderReplacePreference?> getReaderReplacePreference({
    required String bookId,
    required String sourceId,
    required String detailUrl,
  }) async {
    final normalizedBookId = bookId.trim();
    final normalizedSourceId = sourceId.trim();
    final normalizedDetailUrl = detailUrl.trim();
    if (normalizedBookId.isEmpty ||
        normalizedSourceId.isEmpty ||
        normalizedDetailUrl.isEmpty) {
      return null;
    }

    final row =
        await customSelect(
          'SELECT * FROM $_readerReplacePreferencesTableName '
          'WHERE book_id = ? AND source_id = ? AND detail_url = ? LIMIT 1',
          variables: [
            Variable<String>(normalizedBookId),
            Variable<String>(normalizedSourceId),
            Variable<String>(normalizedDetailUrl),
          ],
        ).getSingleOrNull();

    if (row == null) {
      return null;
    }
    return _mapQueryRowToReaderReplacePreference(row);
  }

  Future<void> upsertReaderReplacePreference(
    ReaderReplacePreference preference,
  ) async {
    final normalizedBookId = preference.bookId.trim();
    final normalizedSourceId = preference.sourceId.trim();
    final normalizedDetailUrl = preference.detailUrl.trim();
    if (normalizedBookId.isEmpty ||
        normalizedSourceId.isEmpty ||
        normalizedDetailUrl.isEmpty) {
      return;
    }

    await customStatement(
      'INSERT OR REPLACE INTO $_readerReplacePreferencesTableName '
      '(book_id, source_id, detail_url, mode, updated_at) VALUES (?, ?, ?, ?, ?)',
      [
        normalizedBookId,
        normalizedSourceId,
        normalizedDetailUrl,
        preference.mode.name,
        preference.updatedAt.toIso8601String(),
      ],
    );
  }

  Future<int> getTotalCachedChapterCount() async {
    final countExpression = chapterCaches.cacheKey.count();
    final query = selectOnly(chapterCaches)..addColumns([countExpression]);

    final row = await query.getSingle();
    return row.read(countExpression) ?? 0;
  }

  Future<void> upsertLocalBook(LocalBook book) async {
    final normalizedId = book.id.trim();
    final normalizedTitle = book.title.trim();
    final normalizedStoragePath = book.storagePath.trim();

    if (normalizedId.isEmpty ||
        normalizedTitle.isEmpty ||
        normalizedStoragePath.isEmpty) {
      return;
    }

    await into(storedLocalBooks).insert(
      StoredLocalBooksCompanion(
        id: Value(normalizedId),
        title: Value(normalizedTitle),
        format: Value(book.format.name),
        storagePath: Value(normalizedStoragePath),
        sourcePath: Value(_nullableString(book.sourcePath)),
        charset: Value(_nullableString(book.charset)),
        fileSize: Value(book.fileSize < 0 ? 0 : book.fileSize),
        author: Value(_nullableString(book.author)),
        coverPath: Value(_nullableString(book.coverPath)),
        sourceFileSize: Value(book.sourceFileSize),
        sourceFileLastModifiedMs: Value(book.sourceFileLastModifiedMs),
        storageFileLastModifiedMs: Value(book.storageFileLastModifiedMs),
        indexStatus: Value(book.indexStatus.name),
        chapterCount: Value(book.chapterCount < 0 ? 0 : book.chapterCount),
        lastError: Value(_nullableString(book.lastError)),
        txtTocRuleName: Value(_nullableString(book.txtTocRuleName)),
        txtTocRulePattern: Value(_nullableString(book.txtTocRulePattern)),
        splitLongChapter: Value(book.splitLongChapter),
        createdAt: Value(book.createdAt),
        updatedAt: Value(book.updatedAt),
      ),
      mode: InsertMode.insertOrReplace,
    );
  }

  Future<LocalBook?> getLocalBookById(String bookId) async {
    final normalized = bookId.trim();
    if (normalized.isEmpty) {
      return null;
    }

    final row =
        await (select(storedLocalBooks)
          ..where((table) => table.id.equals(normalized))).getSingleOrNull();
    if (row == null) {
      return null;
    }

    return _mapRowToLocalBook(row);
  }

  Future<List<LocalBook>> getAllLocalBooks() async {
    final rows =
        await (select(storedLocalBooks)
          ..orderBy([(table) => OrderingTerm.desc(table.updatedAt)])).get();
    return rows.map(_mapRowToLocalBook).toList(growable: false);
  }

  Future<void> updateLocalBookIndexState({
    required String bookId,
    required LocalBookIndexStatus status,
    int? chapterCount,
    String? lastError,
    bool clearLastError = false,
  }) async {
    final normalizedId = bookId.trim();
    if (normalizedId.isEmpty) {
      return;
    }

    final normalizedChapterCount =
        chapterCount == null ? null : (chapterCount < 0 ? 0 : chapterCount);

    final lastErrorValue =
        clearLastError
            ? const Value<String?>(null)
            : lastError == null
            ? const Value<String?>.absent()
            : Value<String?>(_nullableString(lastError));

    await (update(storedLocalBooks)
      ..where((table) => table.id.equals(normalizedId))).write(
      StoredLocalBooksCompanion(
        indexStatus: Value(status.name),
        chapterCount: Value.absentIfNull(normalizedChapterCount),
        lastError: lastErrorValue,
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> replaceLocalChapters({
    required String bookId,
    required List<LocalChapter> chapters,
  }) async {
    final normalizedBookId = bookId.trim();
    if (normalizedBookId.isEmpty) {
      return;
    }

    await transaction(() async {
      await (delete(storedLocalChapters)
        ..where((table) => table.bookId.equals(normalizedBookId))).go();

      final sanitizedChapters = chapters
          .where((chapter) {
            final normalizedId = chapter.id.trim();
            final normalizedTitle = chapter.title.trim();
            final normalizedContent = chapter.content.trim();
            final hasImages = chapter.imageUrls.isNotEmpty;
            final hasExternalRange =
                chapter.startOffset != null &&
                chapter.endOffset != null &&
                chapter.endOffset! > chapter.startOffset!;
            return normalizedId.isNotEmpty &&
                normalizedTitle.isNotEmpty &&
                (normalizedContent.isNotEmpty || hasExternalRange || hasImages);
          })
          .toList(growable: false);

      if (sanitizedChapters.isNotEmpty) {
        await batch((batch) {
          for (final chapter in sanitizedChapters) {
            final normalizedId = chapter.id.trim();
            final normalizedTitle = chapter.title.trim();

            batch.insert(
              storedLocalChapters,
              StoredLocalChaptersCompanion(
                id: Value(normalizedId),
                bookId: Value(normalizedBookId),
                chapterIndex: Value(chapter.chapterIndex),
                title: Value(normalizedTitle),
                content: Value(chapter.content),
                imageUrlsJson: Value(jsonEncode(chapter.imageUrls)),
                startOffset: Value(chapter.startOffset),
                endOffset: Value(chapter.endOffset),
                createdAt: Value(chapter.createdAt),
                updatedAt: Value(chapter.updatedAt),
              ),
              mode: InsertMode.insertOrReplace,
            );
          }
        });
      }

      await (update(storedLocalBooks)
        ..where((table) => table.id.equals(normalizedBookId))).write(
        StoredLocalBooksCompanion(
          chapterCount: Value(sanitizedChapters.length),
          updatedAt: Value(DateTime.now()),
        ),
      );
    });
  }

  Future<List<LocalChapter>> getLocalChapters(String bookId) async {
    final normalizedBookId = bookId.trim();
    if (normalizedBookId.isEmpty) {
      return const <LocalChapter>[];
    }

    final rows =
        await (select(storedLocalChapters)
              ..where((table) => table.bookId.equals(normalizedBookId))
              ..orderBy([(table) => OrderingTerm.asc(table.chapterIndex)]))
            .get();

    return rows.map(_mapRowToLocalChapter).toList(growable: false);
  }

  Future<List<LocalChapter>> getLocalChapterMetas(String bookId) async {
    final normalizedBookId = bookId.trim();
    if (normalizedBookId.isEmpty) {
      return const <LocalChapter>[];
    }

    final query =
        selectOnly(storedLocalChapters)
          ..addColumns([
            storedLocalChapters.id,
            storedLocalChapters.bookId,
            storedLocalChapters.chapterIndex,
            storedLocalChapters.title,
            storedLocalChapters.imageUrlsJson,
            storedLocalChapters.startOffset,
            storedLocalChapters.endOffset,
            storedLocalChapters.createdAt,
            storedLocalChapters.updatedAt,
          ])
          ..where(storedLocalChapters.bookId.equals(normalizedBookId))
          ..orderBy([OrderingTerm.asc(storedLocalChapters.chapterIndex)]);

    final rows = await query.get();

    return rows
        .map(
          (row) => LocalChapter(
            id: row.read(storedLocalChapters.id)!,
            bookId: row.read(storedLocalChapters.bookId)!,
            chapterIndex: row.read(storedLocalChapters.chapterIndex)!,
            title: row.read(storedLocalChapters.title)!,
            content: '',
            imageUrls: _decodeStringList(
              row.read(storedLocalChapters.imageUrlsJson),
            ),
            createdAt: row.read(storedLocalChapters.createdAt)!,
            updatedAt: row.read(storedLocalChapters.updatedAt)!,
            startOffset: row.read(storedLocalChapters.startOffset),
            endOffset: row.read(storedLocalChapters.endOffset),
          ),
        )
        .where((chapter) => chapter.id.isNotEmpty)
        .toList(growable: false);
  }

  Future<LocalChapter?> getLocalChapterByIndex({
    required String bookId,
    required int chapterIndex,
  }) async {
    final normalizedBookId = bookId.trim();
    if (normalizedBookId.isEmpty) {
      return null;
    }

    final row =
        await (select(storedLocalChapters)
              ..where((table) => table.bookId.equals(normalizedBookId))
              ..where((table) => table.chapterIndex.equals(chapterIndex)))
            .getSingleOrNull();

    if (row == null) {
      return null;
    }

    return _mapRowToLocalChapter(row);
  }

  Future<LocalChapter?> getLocalChapterById(String chapterId) async {
    final normalizedId = chapterId.trim();
    if (normalizedId.isEmpty) {
      return null;
    }

    final row =
        await (select(storedLocalChapters)
          ..where((table) => table.id.equals(normalizedId))).getSingleOrNull();

    if (row == null) {
      return null;
    }

    return _mapRowToLocalChapter(row);
  }

  Future<void> deleteLocalBook(String bookId) async {
    final normalizedId = bookId.trim();
    if (normalizedId.isEmpty) {
      return;
    }

    await transaction(() async {
      await (delete(storedLocalChapters)
        ..where((table) => table.bookId.equals(normalizedId))).go();
      await (delete(storedLocalBooks)
        ..where((table) => table.id.equals(normalizedId))).go();
    });
  }

  Future<void> upsertBookmark(Bookmark bookmark) async {
    final normalizedId = bookmark.id.trim();
    final normalizedBookId = bookmark.bookId.trim();
    final normalizedChapterId = bookmark.chapterId.trim();
    final normalizedSnippet = bookmark.snippet.trim();

    if (normalizedId.isEmpty ||
        normalizedBookId.isEmpty ||
        normalizedChapterId.isEmpty ||
        normalizedSnippet.isEmpty) {
      return;
    }

    final safeChapterIndex =
        bookmark.chapterIndex < 0 ? 0 : bookmark.chapterIndex;
    final safeStartOffset = bookmark.startOffset < 0 ? 0 : bookmark.startOffset;
    final safeEndOffset =
        bookmark.endOffset < safeStartOffset
            ? safeStartOffset
            : bookmark.endOffset;

    await into(storedBookmarks).insert(
      StoredBookmarksCompanion(
        id: Value(normalizedId),
        bookId: Value(normalizedBookId),
        chapterId: Value(normalizedChapterId),
        chapterIndex: Value(safeChapterIndex),
        startOffset: Value(safeStartOffset),
        endOffset: Value(safeEndOffset),
        snippet: Value(normalizedSnippet),
        isBold: Value(bookmark.isBold),
        isUnderline: Value(bookmark.isUnderline),
        isWavy: Value(bookmark.isWavy),
        color: Value(_nullableString(bookmark.color)),
        createdAt: Value(bookmark.createdAt),
        updatedAt: Value(bookmark.updatedAt),
      ),
      mode: InsertMode.insertOrReplace,
    );
  }

  Future<int> _nextReaderReplaceRuleOrder() async {
    final row =
        await customSelect(
          'SELECT MAX(sort_order) AS currentMax FROM $_readerReplaceRulesTableName',
        ).getSingle();
    final currentMax = row.data['currentMax'];
    if (currentMax is int) {
      return currentMax + 1;
    }
    if (currentMax is num) {
      return currentMax.toInt() + 1;
    }
    return 1;
  }

  Future<List<Bookmark>> getBookmarksByBookId(String bookId) async {
    final normalizedBookId = bookId.trim();
    if (normalizedBookId.isEmpty) {
      return const <Bookmark>[];
    }

    final rows =
        await (select(storedBookmarks)
              ..where((table) => table.bookId.equals(normalizedBookId))
              ..orderBy([
                (table) => OrderingTerm.asc(table.chapterIndex),
                (table) => OrderingTerm.asc(table.startOffset),
                (table) => OrderingTerm.desc(table.createdAt),
              ]))
            .get();

    return rows.map(_mapRowToBookmark).toList(growable: false);
  }

  Future<List<Bookmark>> getAllBookmarks() async {
    final rows =
        await (select(storedBookmarks)..orderBy([
          (table) => OrderingTerm.desc(table.updatedAt),
          (table) => OrderingTerm.desc(table.createdAt),
        ])).get();
    return rows.map(_mapRowToBookmark).toList(growable: false);
  }

  Future<void> deleteBookmarkById(String bookmarkId) {
    final normalizedId = bookmarkId.trim();
    if (normalizedId.isEmpty) {
      return Future.value();
    }

    return (delete(storedBookmarks)
      ..where((table) => table.id.equals(normalizedId))).go();
  }

  Future<void> deleteBookmarksByBookId(String bookId) {
    final normalizedBookId = bookId.trim();
    if (normalizedBookId.isEmpty) {
      return Future.value();
    }

    return (delete(storedBookmarks)
      ..where((table) => table.bookId.equals(normalizedBookId))).go();
  }

  Future<void> upsertReadingRecord(ReadingRecord record) async {
    final normalizedBookId = record.bookId.trim();
    final normalizedSourceId = record.sourceId.trim();
    final normalizedDetailUrl = record.detailUrl.trim();
    final normalizedTitle = record.bookTitle.trim();
    if (normalizedBookId.isEmpty ||
        normalizedSourceId.isEmpty ||
        normalizedDetailUrl.isEmpty ||
        normalizedTitle.isEmpty) {
      return;
    }

    await into(storedReadingRecords).insert(
      StoredReadingRecordsCompanion(
        bookId: Value(normalizedBookId),
        sourceId: Value(normalizedSourceId),
        detailUrl: Value(normalizedDetailUrl),
        bookTitle: Value(normalizedTitle),
        bookAuthor: Value(_nullableString(record.bookAuthor)),
        coverUrl: Value(_nullableString(record.coverUrl)),
        lastChapterId: Value(_nullableString(record.lastChapterId)),
        lastChapterTitle: Value(_nullableString(record.lastChapterTitle)),
        lastChapterIndex: Value(record.lastChapterIndex),
        lastChapterUrl: Value(_nullableString(record.lastChapterUrl)),
        lastPositionRatio: Value(
          record.lastPositionRatio.clamp(0.0, 1.0).toDouble(),
        ),
        totalReadMillis: Value(
          record.totalReadMillis < 0 ? 0 : record.totalReadMillis,
        ),
        totalReadChars: Value(
          record.totalReadChars < 0 ? 0 : record.totalReadChars,
        ),
        lastReadAt: Value(record.lastReadAt),
      ),
      mode: InsertMode.insertOrReplace,
    );
  }

  Future<ReadingRecord?> getReadingRecordByBookId(String bookId) async {
    final normalizedBookId = bookId.trim();
    if (normalizedBookId.isEmpty) {
      return null;
    }

    final row =
        await (select(storedReadingRecords)..where(
          (table) => table.bookId.equals(normalizedBookId),
        )).getSingleOrNull();
    return row == null ? null : _mapRowToReadingRecord(row);
  }

  Future<List<ReadingRecord>> listLatestReadingRecords({
    String query = '',
  }) async {
    final normalizedQuery = query.trim().toLowerCase();
    final queryBuilder = select(storedReadingRecords)
      ..orderBy([(table) => OrderingTerm.desc(table.lastReadAt)]);
    if (normalizedQuery.isNotEmpty) {
      queryBuilder.where(
        (table) =>
            table.bookTitle.lower().like('%$normalizedQuery%') |
            table.bookAuthor.lower().like('%$normalizedQuery%'),
      );
    }

    final rows = await queryBuilder.get();
    return rows.map(_mapRowToReadingRecord).toList(growable: false);
  }

  Future<void> upsertReadingRecordDay(ReadingRecordDay day) async {
    final normalizedBookId = day.bookId.trim();
    final normalizedDateKey = day.dateKey.trim();
    final normalizedTitle = day.bookTitle.trim();
    if (normalizedBookId.isEmpty ||
        normalizedDateKey.isEmpty ||
        normalizedTitle.isEmpty) {
      return;
    }

    await into(storedReadingRecordDays).insert(
      StoredReadingRecordDaysCompanion(
        bookId: Value(normalizedBookId),
        dateKey: Value(normalizedDateKey),
        bookTitle: Value(normalizedTitle),
        bookAuthor: Value(_nullableString(day.bookAuthor)),
        coverUrl: Value(_nullableString(day.coverUrl)),
        readMillis: Value(day.readMillis < 0 ? 0 : day.readMillis),
        readChars: Value(day.readChars < 0 ? 0 : day.readChars),
        firstReadAt: Value(day.firstReadAt),
        lastReadAt: Value(day.lastReadAt),
      ),
      mode: InsertMode.insertOrReplace,
    );
  }

  Future<ReadingRecordDay?> getReadingRecordDay({
    required String bookId,
    required String dateKey,
  }) async {
    final normalizedBookId = bookId.trim();
    final normalizedDateKey = dateKey.trim();
    if (normalizedBookId.isEmpty || normalizedDateKey.isEmpty) {
      return null;
    }

    final row =
        await (select(storedReadingRecordDays)
              ..where((table) => table.bookId.equals(normalizedBookId))
              ..where((table) => table.dateKey.equals(normalizedDateKey)))
            .getSingleOrNull();
    return row == null ? null : _mapRowToReadingRecordDay(row);
  }

  Future<List<ReadingRecordDay>> listReadingRecordDaysByBookId(
    String bookId,
  ) async {
    final normalizedBookId = bookId.trim();
    if (normalizedBookId.isEmpty) {
      return const <ReadingRecordDay>[];
    }

    final rows =
        await (select(storedReadingRecordDays)
              ..where((table) => table.bookId.equals(normalizedBookId))
              ..orderBy([
                (table) => OrderingTerm.desc(table.dateKey),
                (table) => OrderingTerm.desc(table.lastReadAt),
              ]))
            .get();
    return rows.map(_mapRowToReadingRecordDay).toList(growable: false);
  }

  Future<void> insertReadingRecordSession(ReadingRecordSession session) async {
    await into(storedReadingRecordSessions).insert(
      StoredReadingRecordSessionsCompanion.insert(
        bookId: session.bookId.trim(),
        sourceId: session.sourceId.trim(),
        detailUrl: session.detailUrl.trim(),
        bookTitle: session.bookTitle.trim(),
        bookAuthor: Value(_nullableString(session.bookAuthor)),
        coverUrl: Value(_nullableString(session.coverUrl)),
        chapterId: Value(_nullableString(session.chapterId)),
        chapterTitle: Value(_nullableString(session.chapterTitle)),
        chapterIndex: Value(session.chapterIndex),
        chapterUrl: Value(_nullableString(session.chapterUrl)),
        startAt: session.startAt,
        endAt: session.endAt,
        durationMillis: Value(
          session.durationMillis < 0 ? 0 : session.durationMillis,
        ),
        readChars: Value(session.readChars < 0 ? 0 : session.readChars),
        startPositionRatio: Value(
          session.startPositionRatio.clamp(0.0, 1.0).toDouble(),
        ),
        endPositionRatio: Value(
          session.endPositionRatio.clamp(0.0, 1.0).toDouble(),
        ),
      ),
    );
  }

  Future<void> updateReadingRecordSession(ReadingRecordSession session) async {
    await into(storedReadingRecordSessions).insert(
      StoredReadingRecordSessionsCompanion(
        id: Value(session.id),
        bookId: Value(session.bookId.trim()),
        sourceId: Value(session.sourceId.trim()),
        detailUrl: Value(session.detailUrl.trim()),
        bookTitle: Value(session.bookTitle.trim()),
        bookAuthor: Value(_nullableString(session.bookAuthor)),
        coverUrl: Value(_nullableString(session.coverUrl)),
        chapterId: Value(_nullableString(session.chapterId)),
        chapterTitle: Value(_nullableString(session.chapterTitle)),
        chapterIndex: Value(session.chapterIndex),
        chapterUrl: Value(_nullableString(session.chapterUrl)),
        startAt: Value(session.startAt),
        endAt: Value(session.endAt),
        durationMillis: Value(
          session.durationMillis < 0 ? 0 : session.durationMillis,
        ),
        readChars: Value(session.readChars < 0 ? 0 : session.readChars),
        startPositionRatio: Value(
          session.startPositionRatio.clamp(0.0, 1.0).toDouble(),
        ),
        endPositionRatio: Value(
          session.endPositionRatio.clamp(0.0, 1.0).toDouble(),
        ),
      ),
      mode: InsertMode.insertOrReplace,
    );
  }

  Future<List<ReadingRecordSession>> listReadingRecordSessionsByBookId(
    String bookId,
  ) async {
    final normalizedBookId = bookId.trim();
    if (normalizedBookId.isEmpty) {
      return const <ReadingRecordSession>[];
    }

    final rows =
        await (select(storedReadingRecordSessions)
              ..where((table) => table.bookId.equals(normalizedBookId))
              ..orderBy([(table) => OrderingTerm.asc(table.startAt)]))
            .get();
    return rows.map(_mapRowToReadingRecordSession).toList(growable: false);
  }

  Future<List<ReadingRecordSession>> listReadingRecordSessionsByBookIdAndDate({
    required String bookId,
    required String dateKey,
  }) async {
    final normalizedBookId = bookId.trim();
    final normalizedDateKey = dateKey.trim();
    if (normalizedBookId.isEmpty || normalizedDateKey.isEmpty) {
      return const <ReadingRecordSession>[];
    }

    final startAt = DateTime.tryParse(normalizedDateKey);
    if (startAt == null) {
      return const <ReadingRecordSession>[];
    }
    final endAt = startAt.add(const Duration(days: 1));

    final rows =
        await (select(storedReadingRecordSessions)
              ..where((table) => table.bookId.equals(normalizedBookId))
              ..where((table) {
                return table.endAt.isBiggerOrEqualValue(startAt) &
                    table.endAt.isSmallerThanValue(endAt);
              })
              ..orderBy([(table) => OrderingTerm.asc(table.startAt)]))
            .get();
    return rows.map(_mapRowToReadingRecordSession).toList(growable: false);
  }

  Future<void> deleteReadingRecordSessionById(int sessionId) async {
    if (sessionId <= 0) {
      return;
    }

    await (delete(storedReadingRecordSessions)
      ..where((table) => table.id.equals(sessionId))).go();
  }

  Future<void> deleteReadingRecordSessionsByBookIdAndDate({
    required String bookId,
    required String dateKey,
  }) async {
    final normalizedBookId = bookId.trim();
    final normalizedDateKey = dateKey.trim();
    if (normalizedBookId.isEmpty || normalizedDateKey.isEmpty) {
      return;
    }

    final startAt = DateTime.tryParse(normalizedDateKey);
    if (startAt == null) {
      return;
    }
    final endAt = startAt.add(const Duration(days: 1));

    await (delete(storedReadingRecordSessions)..where((table) {
      return table.bookId.equals(normalizedBookId) &
          table.endAt.isBiggerOrEqualValue(startAt) &
          table.endAt.isSmallerThanValue(endAt);
    })).go();
  }

  Stream<List<ReadingRecord>> watchLatestReadingRecords({String query = ''}) {
    final normalizedQuery = query.trim().toLowerCase();
    final queryBuilder = select(storedReadingRecords)
      ..orderBy([(table) => OrderingTerm.desc(table.lastReadAt)]);
    if (normalizedQuery.isNotEmpty) {
      queryBuilder.where(
        (table) =>
            table.bookTitle.lower().like('%$normalizedQuery%') |
            table.bookAuthor.lower().like('%$normalizedQuery%'),
      );
    }
    return queryBuilder.watch().map(
      (rows) => rows.map(_mapRowToReadingRecord).toList(growable: false),
    );
  }

  Stream<List<ReadingRecordDay>> watchReadingRecordDays({String query = ''}) {
    final normalizedQuery = query.trim().toLowerCase();
    final queryBuilder = select(storedReadingRecordDays)..orderBy([
      (table) => OrderingTerm.desc(table.dateKey),
      (table) => OrderingTerm.desc(table.lastReadAt),
    ]);
    if (normalizedQuery.isNotEmpty) {
      queryBuilder.where(
        (table) =>
            table.bookTitle.lower().like('%$normalizedQuery%') |
            table.bookAuthor.lower().like('%$normalizedQuery%'),
      );
    }
    return queryBuilder.watch().map(
      (rows) => rows.map(_mapRowToReadingRecordDay).toList(growable: false),
    );
  }

  Stream<List<ReadingRecordSession>> watchReadingRecordSessions({
    String query = '',
  }) {
    final normalizedQuery = query.trim().toLowerCase();
    final queryBuilder = select(storedReadingRecordSessions)
      ..orderBy([(table) => OrderingTerm.desc(table.startAt)]);
    if (normalizedQuery.isNotEmpty) {
      queryBuilder.where(
        (table) =>
            table.bookTitle.lower().like('%$normalizedQuery%') |
            table.bookAuthor.lower().like('%$normalizedQuery%'),
      );
    }
    return queryBuilder.watch().map(
      (rows) => rows.map(_mapRowToReadingRecordSession).toList(growable: false),
    );
  }

  Stream<int> watchTotalReadingMillis() {
    final sumExpression = storedReadingRecords.totalReadMillis.sum();
    final query = selectOnly(storedReadingRecords)..addColumns([sumExpression]);
    return query.watchSingle().map((row) => row.read(sumExpression) ?? 0);
  }

  Future<void> deleteReadingRecordByBookId(String bookId) async {
    final normalizedBookId = bookId.trim();
    if (normalizedBookId.isEmpty) {
      return;
    }

    await (delete(storedReadingRecords)
      ..where((table) => table.bookId.equals(normalizedBookId))).go();
  }

  Future<void> deleteReadingRecordDaysByBookId(String bookId) async {
    final normalizedBookId = bookId.trim();
    if (normalizedBookId.isEmpty) {
      return;
    }

    await (delete(storedReadingRecordDays)
      ..where((table) => table.bookId.equals(normalizedBookId))).go();
  }

  Future<void> deleteReadingRecordsByBookId(String bookId) async {
    final normalizedBookId = bookId.trim();
    if (normalizedBookId.isEmpty) {
      return;
    }

    await transaction(() async {
      await (delete(storedReadingRecordSessions)
        ..where((table) => table.bookId.equals(normalizedBookId))).go();
      await (delete(storedReadingRecordDays)
        ..where((table) => table.bookId.equals(normalizedBookId))).go();
      await (delete(storedReadingRecords)
        ..where((table) => table.bookId.equals(normalizedBookId))).go();
    });
  }

  LocalBook _mapRowToLocalBook(StoredLocalBook row) {
    return LocalBook(
      id: row.id,
      title: row.title,
      format: LocalBookFormat.values.firstWhere(
        (item) => item.name == row.format,
        orElse: () => LocalBookFormat.txt,
      ),
      storagePath: row.storagePath,
      fileSize: row.fileSize,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      sourcePath: row.sourcePath,
      charset: row.charset,
      author: row.author,
      coverPath: row.coverPath,
      sourceFileSize: row.sourceFileSize,
      sourceFileLastModifiedMs: row.sourceFileLastModifiedMs,
      storageFileLastModifiedMs: row.storageFileLastModifiedMs,
      indexStatus: LocalBookIndexStatus.values.firstWhere(
        (item) => item.name == row.indexStatus,
        orElse: () => LocalBookIndexStatus.pending,
      ),
      chapterCount: row.chapterCount,
      lastError: row.lastError,
      txtTocRuleName: row.txtTocRuleName,
      txtTocRulePattern: row.txtTocRulePattern,
      splitLongChapter: row.splitLongChapter,
    );
  }

  LocalChapter _mapRowToLocalChapter(StoredLocalChapter row) {
    return LocalChapter(
      id: row.id,
      bookId: row.bookId,
      chapterIndex: row.chapterIndex,
      title: row.title,
      content: row.content,
      imageUrls: _decodeStringList(row.imageUrlsJson),
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      startOffset: row.startOffset,
      endOffset: row.endOffset,
    );
  }

  Bookmark _mapRowToBookmark(StoredBookmark row) {
    return Bookmark(
      id: row.id,
      bookId: row.bookId,
      chapterId: row.chapterId,
      chapterIndex: row.chapterIndex,
      startOffset: row.startOffset,
      endOffset: row.endOffset,
      snippet: row.snippet,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      isBold: row.isBold,
      isUnderline: row.isUnderline,
      isWavy: row.isWavy,
      color: row.color,
    );
  }

  ReadingRecord _mapRowToReadingRecord(StoredReadingRecord row) {
    return ReadingRecord(
      bookId: row.bookId,
      sourceId: row.sourceId,
      detailUrl: row.detailUrl,
      bookTitle: row.bookTitle,
      bookAuthor: row.bookAuthor,
      coverUrl: row.coverUrl,
      lastChapterId: row.lastChapterId,
      lastChapterTitle: row.lastChapterTitle,
      lastChapterIndex: row.lastChapterIndex,
      lastChapterUrl: row.lastChapterUrl,
      lastPositionRatio: row.lastPositionRatio,
      totalReadMillis: row.totalReadMillis,
      totalReadChars: row.totalReadChars,
      lastReadAt: row.lastReadAt,
    );
  }

  ReadingRecordDay _mapRowToReadingRecordDay(StoredReadingRecordDay row) {
    return ReadingRecordDay(
      bookId: row.bookId,
      dateKey: row.dateKey,
      bookTitle: row.bookTitle,
      bookAuthor: row.bookAuthor,
      coverUrl: row.coverUrl,
      readMillis: row.readMillis,
      readChars: row.readChars,
      firstReadAt: row.firstReadAt,
      lastReadAt: row.lastReadAt,
    );
  }

  ReadingRecordSession _mapRowToReadingRecordSession(
    StoredReadingRecordSession row,
  ) {
    return ReadingRecordSession(
      id: row.id,
      bookId: row.bookId,
      sourceId: row.sourceId,
      detailUrl: row.detailUrl,
      bookTitle: row.bookTitle,
      bookAuthor: row.bookAuthor,
      coverUrl: row.coverUrl,
      chapterId: row.chapterId,
      chapterTitle: row.chapterTitle,
      chapterIndex: row.chapterIndex,
      chapterUrl: row.chapterUrl,
      startAt: row.startAt,
      endAt: row.endAt,
      durationMillis: row.durationMillis,
      readChars: row.readChars,
      startPositionRatio: row.startPositionRatio,
      endPositionRatio: row.endPositionRatio,
    );
  }

  ReaderReplaceRule _mapQueryRowToReaderReplaceRule(QueryRow row) {
    final data = row.data;
    final scopeMode = ReaderReplaceRuleScopeMode.values.firstWhere(
      (item) => item.name == (data['scope_mode'] ?? '').toString(),
      orElse: () => ReaderReplaceRuleScopeMode.all,
    );

    return ReaderReplaceRule(
      id: _decodeInt(data['id']) ?? 0,
      name: (data['name'] ?? '').toString(),
      group: _nullableString(data['group']),
      pattern: (data['pattern'] ?? '').toString(),
      replacement: (data['replacement'] ?? '').toString(),
      scopeMode: scopeMode,
      scope: _nullableString(data['scope']),
      excludeScope: _nullableString(data['exclude_scope']),
      scopeTitle: _decodeBool(data['scope_title']),
      scopeContent: _decodeBool(data['scope_content']),
      isEnabled: _decodeBool(data['is_enabled']),
      isRegex: _decodeBool(data['is_regex']),
      timeoutMs: _decodeInt(data['timeout_ms']) ?? 3000,
      sortOrder: _decodeInt(data['sort_order']) ?? 0,
      createdAt: _decodeDateTime(data['created_at']),
      updatedAt: _decodeDateTime(data['updated_at']),
    );
  }

  ReaderReplacePreference _mapQueryRowToReaderReplacePreference(QueryRow row) {
    final data = row.data;
    final mode = ReaderReplaceRuleMode.values.firstWhere(
      (item) => item.name == (data['mode'] ?? '').toString(),
      orElse: () => ReaderReplaceRuleMode.inherit,
    );

    return ReaderReplacePreference(
      bookId: (data['book_id'] ?? '').toString(),
      sourceId: (data['source_id'] ?? '').toString(),
      detailUrl: (data['detail_url'] ?? '').toString(),
      mode: mode,
      updatedAt: _decodeDateTime(data['updated_at']),
    );
  }

  SourceDefinition _mapRowToSource(Source row) {
    final rules = _decodeMap(row.rulesJson);
    final headers = _decodeMap(
      row.headersJson,
    ).map((key, value) => MapEntry(key, value.toString()));
    final raw = _decodeMap(row.rawJson);
    final originalSource = _decodeNullableMap(raw['originalSource']);

    final status = SourceHealthStatus.values.firstWhere(
      (item) => item.name == row.healthStatus,
      orElse: () => SourceHealthStatus.unknown,
    );

    final sourceType =
        _decodeInt(raw['sourceType']) ??
        _decodeInt(originalSource?['bookSourceType']) ??
        0;

    final hasExploreEnabled = raw.containsKey('exploreEnabled');
    final exploreEnabled =
        hasExploreEnabled
            ? _decodeBool(raw['exploreEnabled'])
            : _decodeBool(originalSource?['enabledExplore']);

    final exploreUrl =
        _nullableString(raw['exploreUrl']) ??
        _nullableString(originalSource?['exploreUrl']) ??
        _nullableString(originalSource?['discoverUrl']);
    final jsCapability = SourceJsCapability.values.firstWhere(
      (item) => item.name == _nullableString(raw['jsCapability']),
      orElse: () => SourceJsCapability.full,
    );

    return SourceDefinition(
      id: row.id,
      name: row.name,
      baseUrl: row.baseUrl,
      group: row.group,
      enabled: row.enabled,
      sourceType: sourceType,
      comment: row.comment,
      headers: headers,
      rules: SourceRuleSet.fromJson(rules),
      lastCheckStatus: status,
      lastCheckedAt: row.lastCheckedAt,
      lastCheckMessage: _nullableString(raw['lastCheckMessage']),
      exploreEnabled: exploreEnabled,
      exploreUrl: exploreUrl,
      jsCapability: jsCapability,
      originalSource: originalSource,
    );
  }

  SourcesCompanion _toCompanion(SourceDefinition source, DateTime now) {
    final rulesJson = jsonEncode(source.rules.toJson());
    final headersJson = jsonEncode(source.headers);
    final rawJson = jsonEncode(source.toJson());

    return SourcesCompanion(
      id: Value(source.id),
      name: Value(source.name),
      baseUrl: Value(source.baseUrl),
      group: Value(source.group),
      enabled: Value(source.enabled),
      comment: Value(source.comment),
      headersJson: Value(headersJson),
      rulesJson: Value(rulesJson),
      healthStatus: Value(source.lastCheckStatus.name),
      lastCheckedAt: Value(source.lastCheckedAt),
      createdAt: Value(now),
      updatedAt: Value(now),
      rawJson: Value(rawJson),
    );
  }

  SourceListItem _mapSourceListItem(QueryRow row) {
    return SourceListItem(
      id: (row.data['id'] ?? '').toString(),
      name: (row.data['name'] ?? '').toString(),
      baseUrl: (row.data['baseUrl'] ?? '').toString(),
      group: _nullableString(row.data['sourceGroup']),
      enabled: _decodeBool(row.data['enabled']),
      comment: _nullableString(row.data['comment']),
      sourceType: _decodeInt(row.data['sourceType']) ?? 0,
      lastCheckStatus: _decodeSourceHealthStatus(
        row.data['healthStatus']?.toString(),
      ),
      lastCheckedAt: _decodeNullableDateTime(row.data['lastCheckedAt']),
    );
  }

  _SourceListSqlFilter _buildSourceListSqlFilter({
    required String keyword,
    bool? enabledOnly,
    bool? isMangaSource,
    String? groupEquals,
    bool includeUngroupedOnly = false,
  }) {
    final clauses = <String>[];
    final variables = <Variable<Object>>[];

    final normalizedKeyword = keyword.trim().toLowerCase();
    if (normalizedKeyword.isNotEmpty) {
      final pattern = '%$normalizedKeyword%';
      const keywordClause =
          "(LOWER(name) LIKE ? "
          "OR LOWER(base_url) LIKE ?)";
      clauses.add(keywordClause);
      for (var i = 0; i < 2; i++) {
        variables.add(Variable<String>(pattern));
      }
    }

    if (enabledOnly != null) {
      clauses.add('enabled = ?');
      variables.add(Variable<int>(enabledOnly ? 1 : 0));
    }

    if (isMangaSource != null) {
      clauses.add(
        isMangaSource
            ? _mangaSourceMatcherSql
            : 'NOT ($_mangaSourceMatcherSql)',
      );
    }

    if (groupEquals != null && groupEquals.trim().isNotEmpty) {
      clauses.add('"group" = ?');
      variables.add(Variable<String>(groupEquals.trim()));
    } else if (includeUngroupedOnly) {
      clauses.add('("group" IS NULL OR TRIM("group") = \'\')');
    }

    final whereClause = clauses.isEmpty ? '' : 'WHERE ${clauses.join(' AND ')}';
    return _SourceListSqlFilter(whereClause: whereClause, variables: variables);
  }

  int? _decodeInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value.trim());
    }
    return null;
  }

  bool _decodeBool(Object? value) {
    if (value is bool) {
      return value;
    }
    if (value is int) {
      return value != 0;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized == '1' || normalized == 'true';
    }
    return false;
  }

  DateTime? _decodeNullableDateTime(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is DateTime) {
      return value;
    }
    if (value is int) {
      return _decodeEpochDateTime(value);
    }
    if (value is num) {
      return _decodeEpochDateTime(value.toInt());
    }
    if (value is String) {
      final normalized = value.trim();
      if (normalized.isEmpty) {
        return null;
      }
      final parsedDateTime = DateTime.tryParse(normalized);
      if (parsedDateTime != null) {
        return parsedDateTime;
      }
      final parsedEpoch = int.tryParse(normalized);
      if (parsedEpoch != null) {
        return _decodeEpochDateTime(parsedEpoch);
      }
    }
    return null;
  }

  DateTime _decodeEpochDateTime(int epoch) {
    final absEpoch = epoch.abs();
    if (absEpoch >= 1000000000000000) {
      return DateTime.fromMicrosecondsSinceEpoch(epoch);
    }
    if (absEpoch >= 1000000000000) {
      return DateTime.fromMillisecondsSinceEpoch(epoch);
    }
    if (absEpoch >= 1000000000) {
      return DateTime.fromMillisecondsSinceEpoch(epoch * 1000);
    }
    return DateTime.fromMillisecondsSinceEpoch(epoch);
  }

  SourceHealthStatus _decodeSourceHealthStatus(String? rawStatus) {
    final normalized = rawStatus?.trim();
    return SourceHealthStatus.values.firstWhere(
      (item) => item.name == normalized,
      orElse: () => SourceHealthStatus.unknown,
    );
  }

  Map<String, dynamic>? _decodeNullableMap(Object? value) {
    if (value is! Map) {
      return null;
    }

    return value.map((key, item) => MapEntry(key.toString(), item));
  }

  String? _nullableString(Object? value) {
    if (value == null) {
      return null;
    }
    final text = value.toString().trim();
    if (text.isEmpty) {
      return null;
    }
    return text;
  }

  Map<String, dynamic> _decodeMap(String source) {
    try {
      final decoded = jsonDecode(source);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
      }
      return const {};
    } on FormatException {
      return const {};
    }
  }

  List<String> _decodeStringList(String? raw) {
    final normalized = raw?.trim() ?? '';
    if (normalized.isEmpty) {
      return const <String>[];
    }
    try {
      final decoded = jsonDecode(normalized);
      if (decoded is! List) {
        return const <String>[];
      }
      return decoded
          .map((item) => item?.toString().trim() ?? '')
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const <String>[];
    }
  }
}

QueryExecutor _openConnection() {
  return LazyDatabase(() async {
    final isFlutterTest = Platform.environment.containsKey('FLUTTER_TEST');

    final baseDir =
        isFlutterTest
            ? Directory.systemTemp
            : await getApplicationSupportDirectory();

    final databaseDir = Directory(p.join(baseDir.path, 'flutter_appread'));
    if (!await databaseDir.exists()) {
      await databaseDir.create(recursive: true);
    }

    final file = File(p.join(databaseDir.path, 'appread_sources.db'));
    return NativeDatabase.createInBackground(file);
  });
}

class _SourceListSqlFilter {
  const _SourceListSqlFilter({
    required this.whereClause,
    required this.variables,
  });

  final String whereClause;
  final List<Variable<Object>> variables;
}

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../domain/entities/local_book.dart';
import '../../../domain/entities/local_chapter.dart';
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
  IntColumn get fileSize => integer()();
  TextColumn get author => text().nullable()();
  TextColumn get coverPath => text().nullable()();
  TextColumn get indexStatus => text().withDefault(const Constant('pending'))();
  IntColumn get chapterCount => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
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
    SearchSourceHits,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase({QueryExecutor? executor}) : super(executor ?? _openConnection());

  static final AppDatabase instance = AppDatabase();

  @override
  int get schemaVersion => 5;

  static const String _mangaSourceMatcherSql =
      '(raw_json LIKE \'%"sourceType":2,%\' OR '
      'raw_json LIKE \'%"sourceType":2}%\')';

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (migrator) async {
        await migrator.createAll();
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
      },
    );
  }

  Future<List<SourceDefinition>> getAllSources() async {
    final rows =
        await (select(sources)..orderBy([
          (table) => OrderingTerm.asc(table.group),
          (table) => OrderingTerm.asc(table.name),
        ])).get();
    return rows.map(_mapRowToSource).toList();
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
  }) async {
    final safeLimit = limit < 1 ? 1 : limit;
    final safeOffset = offset < 0 ? 0 : offset;
    final filter = _buildSourceListSqlFilter(
      keyword: keyword,
      enabledOnly: enabledOnly,
      isMangaSource: isMangaSource,
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
  }) async {
    final filter = _buildSourceListSqlFilter(
      keyword: keyword,
      enabledOnly: enabledOnly,
      isMangaSource: isMangaSource,
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
  }) async {
    final filter = _buildSourceListSqlFilter(
      keyword: keyword,
      isMangaSource: isMangaSource,
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
        fileSize: Value(book.fileSize < 0 ? 0 : book.fileSize),
        author: Value(_nullableString(book.author)),
        coverPath: Value(_nullableString(book.coverPath)),
        indexStatus: Value(book.indexStatus.name),
        chapterCount: Value(book.chapterCount < 0 ? 0 : book.chapterCount),
        lastError: Value(_nullableString(book.lastError)),
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

      if (chapters.isNotEmpty) {
        await batch((batch) {
          for (final chapter in chapters) {
            final normalizedId = chapter.id.trim();
            final normalizedTitle = chapter.title.trim();
            final normalizedContent = chapter.content.trim();
            if (normalizedId.isEmpty ||
                normalizedTitle.isEmpty ||
                normalizedContent.isEmpty) {
              continue;
            }

            batch.insert(
              storedLocalChapters,
              StoredLocalChaptersCompanion(
                id: Value(normalizedId),
                bookId: Value(normalizedBookId),
                chapterIndex: Value(chapter.chapterIndex),
                title: Value(normalizedTitle),
                content: Value(chapter.content),
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
          chapterCount: Value(chapters.length),
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
      author: row.author,
      coverPath: row.coverPath,
      indexStatus: LocalBookIndexStatus.values.firstWhere(
        (item) => item.name == row.indexStatus,
        orElse: () => LocalBookIndexStatus.pending,
      ),
      chapterCount: row.chapterCount,
      lastError: row.lastError,
    );
  }

  LocalChapter _mapRowToLocalChapter(StoredLocalChapter row) {
    return LocalChapter(
      id: row.id,
      bookId: row.bookId,
      chapterIndex: row.chapterIndex,
      title: row.title,
      content: row.content,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      startOffset: row.startOffset,
      endOffset: row.endOffset,
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

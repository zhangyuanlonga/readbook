import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../domain/entities/bookmark.dart';
import '../../../domain/entities/book_identity.dart';
import '../../../domain/entities/book_metadata_override.dart';
import '../../../domain/entities/bookshelf_book.dart';
import '../../../domain/entities/chapter.dart';
import '../../../domain/entities/local_book.dart';
import '../../../domain/entities/local_chapter.dart';
import '../../../domain/entities/reader_document.dart';
import '../../../domain/entities/reader_logical_position.dart';
import '../../../domain/entities/reader_toc_snapshot.dart';
import '../../../domain/entities/reading_book_status.dart';
import '../../../domain/entities/reading_progress.dart';
import '../../../domain/entities/reading_record.dart';
import '../../../domain/entities/reading_record_day.dart';
import '../../../domain/entities/reading_record_session.dart';
import '../../../domain/entities/source_health.dart';
import 'app_database_connection.dart';

part 'app_database.g.dart';

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
  TextColumn get description => text().nullable()();
  TextColumn get coverPath => text().nullable()();
  IntColumn get sourceFileSize => integer().nullable()();
  IntColumn get sourceFileLastModifiedMs => integer().nullable()();
  IntColumn get storageFileLastModifiedMs => integer().nullable()();
  TextColumn get indexStatus => text().withDefault(const Constant('pending'))();
  IntColumn get chapterCount => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
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
  TextColumn get documentJson => text().nullable()();
  TextColumn get sourceRef => text().nullable()();
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
  TextColumn get note => text().nullable()();
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

class StoredBookMetadataOverrides extends Table {
  TextColumn get targetKey => text()();
  TextColumn get bookId => text().nullable()();
  TextColumn get sourceId => text().nullable()();
  TextColumn get detailUrl => text().nullable()();
  TextColumn get title => text().nullable()();
  TextColumn get author => text().nullable()();
  TextColumn get intro => text().nullable()();
  TextColumn get coverPath => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  String get tableName => 'book_metadata_overrides';

  @override
  Set<Column<Object>> get primaryKey => {targetKey};
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

class StoredReadingBookStatuses extends Table {
  TextColumn get bookId => text()();
  TextColumn get sourceId => text()();
  TextColumn get detailUrl => text()();
  TextColumn get bookTitle => text()();
  TextColumn get statusOverride => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  String get tableName => 'reading_book_statuses';

  @override
  Set<Column<Object>> get primaryKey => {bookId};
}

class StoredReadingProgresses extends Table {
  TextColumn get bookId => text()();
  TextColumn get sourceId => text()();
  TextColumn get detailUrl => text()();
  TextColumn get chapterId => text()();
  TextColumn get chapterUrl => text()();
  TextColumn get chapterTitle => text()();
  IntColumn get chapterIndex => integer()();
  RealColumn get chapterPositionRatio =>
      real().withDefault(const Constant(0))();
  TextColumn get logicalPositionJson => text().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  String get tableName => 'reading_progresses';

  @override
  Set<Column<Object>> get primaryKey => {bookId};
}

class StoredTocSnapshots extends Table {
  TextColumn get storageKey => text()();
  TextColumn get bookId => text()();
  TextColumn get sourceId => text()();
  TextColumn get detailUrl => text()();
  TextColumn get title => text()();
  TextColumn get author => text().nullable()();
  TextColumn get coverUrl => text().nullable()();
  TextColumn get chaptersJson => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  String get tableName => 'toc_snapshots';

  @override
  Set<Column<Object>> get primaryKey => {storageKey};
}

class StoredRemoteAccessSnapshots extends Table {
  TextColumn get userId => text()();
  BoolColumn get serverSourceGatewayEnabled =>
      boolean().named('show_source_entry').withDefault(const Constant(false))();
  BoolColumn get hasMembership =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get hasThemeCustom =>
      boolean().withDefault(const Constant(false))();
  IntColumn get serverSourceGatewayLimit =>
      integer().named('source_import_limit').withDefault(const Constant(10))();
  DateTimeColumn get cachedAt => dateTime()();
  DateTimeColumn get vipExpireAt => dateTime().nullable()();
  TextColumn get membershipPlanType => text().nullable()();

  @override
  String get tableName => 'remote_access_snapshots';

  @override
  Set<Column<Object>> get primaryKey => {userId};
}

class StoredSourceHealthSnapshots extends Table {
  TextColumn get sourceId => text()();
  TextColumn get payloadJson => text()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  String get tableName => 'source_health_snapshots';

  @override
  Set<Column<Object>> get primaryKey => {sourceId};
}

class StoredBookshelfBooks extends Table {
  TextColumn get sourceId => text()();
  TextColumn get detailUrl => text()();
  TextColumn get bookId => text()();
  TextColumn get title => text()();
  TextColumn get author => text().nullable()();
  TextColumn get category => text().nullable()();
  TextColumn get coverUrl => text().nullable()();
  TextColumn get latestChapter => text().nullable()();
  BoolColumn get inReadingQueue =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get addedAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  String get tableName => 'bookshelf_books';

  @override
  Set<Column<Object>> get primaryKey => {sourceId, detailUrl};
}

class StoredBookshelfTagAssignments extends Table {
  TextColumn get sourceId => text()();
  TextColumn get detailUrl => text()();
  TextColumn get tagName => text()();
  IntColumn get position => integer().withDefault(const Constant(0))();

  @override
  String get tableName => 'bookshelf_tag_assignments';

  @override
  Set<Column<Object>> get primaryKey => {sourceId, detailUrl, tagName};
}

class StoredBookshelfTagMetadata extends Table {
  TextColumn get name => text()();
  IntColumn get colorValue => integer()();
  IntColumn get position => integer().withDefault(const Constant(0))();

  @override
  String get tableName => 'bookshelf_tag_metadata';

  @override
  Set<Column<Object>> get primaryKey => {name};
}

class StoredBookshelfCategoryMetadata extends Table {
  TextColumn get name => text()();
  IntColumn get colorValue => integer()();
  IntColumn get position => integer().withDefault(const Constant(0))();

  @override
  String get tableName => 'bookshelf_category_metadata';

  @override
  Set<Column<Object>> get primaryKey => {name};
}

class StoredBookshelfBaseFilterOrders extends Table {
  TextColumn get filterKey => text()();
  IntColumn get position => integer().withDefault(const Constant(0))();

  @override
  String get tableName => 'bookshelf_base_filter_orders';

  @override
  Set<Column<Object>> get primaryKey => {filterKey};
}

class BookshelfTaxonomySnapshotItem {
  const BookshelfTaxonomySnapshotItem({
    required this.name,
    required this.colorValue,
  });

  final String name;
  final int colorValue;
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

class StoredSyncProfiles extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get driverType => text()();
  TextColumn get endpointUrl => text()();
  TextColumn get basePath => text()();
  TextColumn get username => text()();
  TextColumn get secretRef => text().nullable()();
  TextColumn get enabledScopesJson =>
      text().withDefault(const Constant('[]'))();
  TextColumn get scopeConfigJson => text().nullable()();
  BoolColumn get isAutoSyncEnabled =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastSyncAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  String get tableName => 'sync_profiles';

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class StoredSyncScopeStates extends Table {
  TextColumn get profileId => text()();
  TextColumn get scope => text()();
  TextColumn get lastBaseSnapshotJson => text().nullable()();
  TextColumn get lastRemoteRevision => text().nullable()();
  TextColumn get lastRemoteHash => text().nullable()();
  TextColumn get lastLocalHash => text().nullable()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  String get tableName => 'sync_scope_states';

  @override
  Set<Column<Object>> get primaryKey => {profileId, scope};
}

class StoredSyncJobs extends Table {
  TextColumn get id => text()();
  TextColumn get profileId => text()();
  TextColumn get triggerKind => text()();
  TextColumn get direction =>
      text().withDefault(const Constant('bidirectional'))();
  TextColumn get status => text()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();
  TextColumn get summaryJson => text().nullable()();
  TextColumn get errorMessage => text().nullable()();

  @override
  String get tableName => 'sync_jobs';

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class StoredSyncConflicts extends Table {
  TextColumn get id => text()();
  TextColumn get profileId => text()();
  TextColumn get scope => text()();
  TextColumn get recordKey => text()();
  TextColumn get basePayloadJson => text().nullable()();
  TextColumn get localPayloadJson => text().nullable()();
  TextColumn get remotePayloadJson => text().nullable()();
  TextColumn get resolution =>
      text().withDefault(const Constant('unresolved'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get resolvedAt => dateTime().nullable()();

  @override
  String get tableName => 'sync_conflicts';

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class ChapterCacheBookSummary {
  const ChapterCacheBookSummary({
    required this.bookId,
    required this.sourceId,
    required this.cachedCount,
    required this.estimatedBytes,
    required this.updatedAt,
  });

  final String bookId;
  final String sourceId;
  final int cachedCount;
  final int estimatedBytes;
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

class AppDatabaseMaintenanceReport {
  const AppDatabaseMaintenanceReport({
    required this.orphanedLocalReadingProgresses,
    required this.orphanedLocalReadingRecords,
    required this.orphanedLocalReadingRecordSessions,
    required this.orphanedLocalReadingBookStatuses,
    required this.orphanedLocalTocSnapshots,
    required this.orphanedLocalMetadataOverrides,
    required this.staleSearchSourceHits,
  });

  final int orphanedLocalReadingProgresses;
  final int orphanedLocalReadingRecords;
  final int orphanedLocalReadingRecordSessions;
  final int orphanedLocalReadingBookStatuses;
  final int orphanedLocalTocSnapshots;
  final int orphanedLocalMetadataOverrides;
  final int staleSearchSourceHits;

  int get totalDeleted =>
      orphanedLocalReadingProgresses +
      orphanedLocalReadingRecords +
      orphanedLocalReadingRecordSessions +
      orphanedLocalReadingBookStatuses +
      orphanedLocalTocSnapshots +
      orphanedLocalMetadataOverrides +
      staleSearchSourceHits;
}

@DriftDatabase(
  tables: [
    ChapterCaches,
    StoredLocalBooks,
    StoredLocalChapters,
    StoredBookmarks,
    StoredBookMetadataOverrides,
    StoredReadingRecords,
    StoredReadingRecordDays,
    StoredReadingRecordSessions,
    StoredReadingBookStatuses,
    StoredReadingProgresses,
    StoredTocSnapshots,
    StoredRemoteAccessSnapshots,
    StoredSourceHealthSnapshots,
    StoredBookshelfBooks,
    StoredBookshelfTagAssignments,
    StoredBookshelfTagMetadata,
    StoredBookshelfCategoryMetadata,
    StoredBookshelfBaseFilterOrders,
    SearchSourceHits,
    StoredSyncProfiles,
    StoredSyncScopeStates,
    StoredSyncJobs,
    StoredSyncConflicts,
  ],
)
class AppDatabase extends _$AppDatabase {
  static const int _localChapterInsertBatchSize = 64;
  static const int _localChapterInsertYieldEveryChunks = 2;
  static const String _localChapterBodiesTableName = 'local_chapter_bodies';

  AppDatabase({QueryExecutor? executor})
    : super(executor ?? openAppDatabaseConnection());

  static AppDatabase? _sharedInstance;

  static AppDatabase get instance => _sharedInstance ??= AppDatabase();

  static Future<void> resetSharedInstance() async {
    final instance = _sharedInstance;
    _sharedInstance = null;
    if (instance == null) {
      return;
    }
    await instance.close();
  }

  @override
  int get schemaVersion => 34;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (migrator) async {
        await migrator.createAll();
        await _createLocalChapterBodiesTable();
      },
      onUpgrade: (migrator, from, to) async {
        if (from < 2) {
          await migrator.createTable(chapterCaches);
        }
        if (from < 3) {
          await migrator.createTable(storedLocalBooks);
          await migrator.createTable(storedLocalChapters);
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
        if (from < 21) {
          await migrator.createTable(storedReadingBookStatuses);
        }
        if (from < 28) {
          await migrator.createTable(storedReadingProgresses);
        }
        if (from < 29) {
          await migrator.createTable(storedRemoteAccessSnapshots);
          await migrator.createTable(storedSourceHealthSnapshots);
        }
        if (from < 30) {
          await migrator.createTable(storedBookshelfBooks);
          await migrator.createTable(storedBookshelfTagAssignments);
          await migrator.createTable(storedBookshelfTagMetadata);
          await migrator.createTable(storedBookshelfCategoryMetadata);
          await migrator.createTable(storedBookshelfBaseFilterOrders);
        }
        if (from < 22) {
          await _addColumnIfMissing(
            migrator: migrator,
            tableName: storedLocalBooks.tableName,
            columnName: 'description',
            addColumn:
                () => migrator.addColumn(
                  storedLocalBooks,
                  storedLocalBooks.description,
                ),
          );
        }
        if (from < 23) {
          await migrator.createTable(storedBookMetadataOverrides);
        }
        if (from < 24) {
          await _addColumnIfMissing(
            migrator: migrator,
            tableName: storedBookmarks.tableName,
            columnName: 'note',
            addColumn:
                () => migrator.addColumn(storedBookmarks, storedBookmarks.note),
          );
        }
        if (from < 25) {
          await migrator.createTable(storedSyncProfiles);
          await migrator.createTable(storedSyncScopeStates);
          await migrator.createTable(storedSyncJobs);
          await migrator.createTable(storedSyncConflicts);
        }
        if (from < 26) {
          await _ensurePerformanceIndexes();
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
        if (from < 15) {
          await _removeDeprecatedLocalBookColumns(migrator);
        }
        if (from < 17) {
          await _addColumnIfMissing(
            migrator: migrator,
            tableName: storedLocalChapters.tableName,
            columnName: 'source_ref',
            addColumn:
                () => migrator.addColumn(
                  storedLocalChapters,
                  storedLocalChapters.sourceRef,
                ),
          );
        }
        if (from < 18) {
          await _addColumnIfMissing(
            migrator: migrator,
            tableName: storedLocalChapters.tableName,
            columnName: 'document_json',
            addColumn:
                () => migrator.addColumn(
                  storedLocalChapters,
                  storedLocalChapters.documentJson,
                ),
          );
        }
        if (from < 31) {
          await _createLocalChapterBodiesTable();
          await _migrateLegacyLocalChapterBodies();
        }
        if (from < 32) {
          await migrator.createTable(storedTocSnapshots);
        }
        if (from < 33) {
          await _addColumnIfMissing(
            migrator: migrator,
            tableName: storedRemoteAccessSnapshots.tableName,
            columnName: 'vip_expire_at',
            addColumn:
                () => migrator.addColumn(
                  storedRemoteAccessSnapshots,
                  storedRemoteAccessSnapshots.vipExpireAt,
                ),
          );
          await _addColumnIfMissing(
            migrator: migrator,
            tableName: storedRemoteAccessSnapshots.tableName,
            columnName: 'membership_plan_type',
            addColumn:
                () => migrator.addColumn(
                  storedRemoteAccessSnapshots,
                  storedRemoteAccessSnapshots.membershipPlanType,
                ),
          );
        }
        if (from < 34) {
          await _addColumnIfMissing(
            migrator: migrator,
            tableName: storedBookshelfBooks.tableName,
            columnName: 'in_reading_queue',
            addColumn:
                () => migrator.addColumn(
                  storedBookshelfBooks,
                  storedBookshelfBooks.inReadingQueue,
                ),
          );
        }
      },
      beforeOpen: (_) async {
        await _ensureLocalChapterBodiesTable();
        await _ensurePerformanceIndexes();
      },
    );
  }

  Future<void> _ensurePerformanceIndexes() async {
    const statements = <String>[
      'CREATE INDEX IF NOT EXISTS idx_local_chapter_bodies_book_id '
          'ON local_chapter_bodies(book_id)',
      'CREATE INDEX IF NOT EXISTS idx_local_chapter_bodies_updated_at '
          'ON local_chapter_bodies(updated_at)',
      'CREATE INDEX IF NOT EXISTS idx_chapter_caches_book_id '
          'ON chapter_caches(book_id)',
      'CREATE INDEX IF NOT EXISTS idx_chapter_caches_book_source_chapter '
          'ON chapter_caches(book_id, source_id, chapter_index)',
      'CREATE INDEX IF NOT EXISTS idx_chapter_caches_updated_at '
          'ON chapter_caches(updated_at)',
      'CREATE INDEX IF NOT EXISTS idx_local_chapters_book_chapter '
          'ON local_chapters(book_id, chapter_index)',
      'CREATE INDEX IF NOT EXISTS idx_bookmarks_book_chapter_start '
          'ON bookmarks(book_id, chapter_index, start_offset)',
      'CREATE INDEX IF NOT EXISTS idx_reading_progresses_updated_at '
          'ON reading_progresses(updated_at)',
      'CREATE INDEX IF NOT EXISTS idx_source_health_snapshots_updated_at '
          'ON source_health_snapshots(updated_at)',
      'CREATE INDEX IF NOT EXISTS idx_bookshelf_books_added_at '
          'ON bookshelf_books(added_at)',
      'CREATE INDEX IF NOT EXISTS idx_bookshelf_tag_assignments_book '
          'ON bookshelf_tag_assignments(source_id, detail_url, position)',
    ];
    for (final statement in statements) {
      await customStatement(statement);
    }
  }

  Future<void> _createLocalChapterBodiesTable() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS ${_quoteIdentifier(_localChapterBodiesTableName)} (
        chapter_id TEXT NOT NULL PRIMARY KEY,
        book_id TEXT NOT NULL,
        content TEXT NOT NULL DEFAULT '',
        image_urls_json TEXT NOT NULL DEFAULT '[]',
        document_json TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _ensureLocalChapterBodiesTable() async {
    if (await _tableExists(_localChapterBodiesTableName)) {
      return;
    }
    await _createLocalChapterBodiesTable();
  }

  Future<void> _migrateLegacyLocalChapterBodies() async {
    final hasTable = await _tableExists(storedLocalChapters.tableName);
    if (!hasTable) {
      return;
    }
    final hasContentColumn = await _tableHasColumn(
      storedLocalChapters.tableName,
      'content',
    );
    if (!hasContentColumn) {
      return;
    }
    final now = DateTime.now().toIso8601String();
    await customStatement('''
      INSERT OR REPLACE INTO ${_quoteIdentifier(_localChapterBodiesTableName)} (
        chapter_id,
        book_id,
        content,
        image_urls_json,
        document_json,
        created_at,
        updated_at
      )
      SELECT
        id,
        book_id,
        COALESCE(content, ''),
        COALESCE(image_urls_json, '[]'),
        document_json,
        COALESCE(created_at, '$now'),
        COALESCE(updated_at, '$now')
      FROM ${_quoteIdentifier(storedLocalChapters.tableName)}
      WHERE TRIM(COALESCE(content, '')) != ''
         OR TRIM(COALESCE(image_urls_json, '[]')) != '[]'
         OR document_json IS NOT NULL
    ''');
  }

  Future<bool> _tableExists(String tableName) async {
    final rows =
        await customSelect(
          'SELECT name FROM sqlite_master WHERE type = ? AND name = ? LIMIT 1',
          variables: <Variable<Object>>[
            const Variable<String>('table'),
            Variable<String>(tableName),
          ],
        ).get();
    return rows.isNotEmpty;
  }

  Future<void> _removeDeprecatedLocalBookColumns(Migrator migrator) async {
    const tableName = 'local_books';
    if (!await _tableHasColumn(tableName, 'txt_toc_rule_name') &&
        !await _tableHasColumn(tableName, 'txt_toc_rule_pattern')) {
      return;
    }

    await customStatement(
      'ALTER TABLE ${_quoteIdentifier(tableName)} '
      'RENAME TO ${_quoteIdentifier('${tableName}_migration_v14_backup')}',
    );
    await migrator.createTable(storedLocalBooks);
    await customStatement('''
      INSERT INTO ${_quoteIdentifier(tableName)} (
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
        split_long_chapter,
        created_at,
        updated_at
      )
      SELECT
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
        split_long_chapter,
        created_at,
        updated_at
      FROM ${_quoteIdentifier('${tableName}_migration_v14_backup')}
    ''');
    await customStatement(
      'DROP TABLE ${_quoteIdentifier('${tableName}_migration_v14_backup')}',
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

  Future<List<StoredSyncProfile>> getAllSyncProfiles() {
    return (select(storedSyncProfiles)
      ..orderBy([(table) => OrderingTerm.asc(table.name)])).get();
  }

  Stream<List<StoredSyncProfile>> watchAllSyncProfiles() {
    final query = select(storedSyncProfiles)
      ..orderBy([(table) => OrderingTerm.asc(table.name)]);
    return query.watch();
  }

  Future<StoredSyncProfile?> getSyncProfileById(String id) {
    final normalized = id.trim();
    if (normalized.isEmpty) {
      return Future<StoredSyncProfile?>.value(null);
    }
    return (select(storedSyncProfiles)
      ..where((table) => table.id.equals(normalized))).getSingleOrNull();
  }

  Future<void> upsertSyncProfile(StoredSyncProfilesCompanion companion) {
    return into(storedSyncProfiles).insertOnConflictUpdate(companion);
  }

  Future<void> deleteSyncProfile(String id) {
    final normalized = id.trim();
    if (normalized.isEmpty) {
      return Future<void>.value();
    }
    return (delete(storedSyncProfiles)
      ..where((table) => table.id.equals(normalized))).go();
  }

  Future<List<StoredSyncScopeState>> listSyncScopeStatesByProfileId(
    String profileId,
  ) {
    final normalized = profileId.trim();
    if (normalized.isEmpty) {
      return Future<List<StoredSyncScopeState>>.value(
        const <StoredSyncScopeState>[],
      );
    }
    return (select(storedSyncScopeStates)
          ..where((table) => table.profileId.equals(normalized))
          ..orderBy([(table) => OrderingTerm.asc(table.scope)]))
        .get();
  }

  Future<StoredSyncScopeState?> getSyncScopeState({
    required String profileId,
    required String scope,
  }) {
    final normalizedProfileId = profileId.trim();
    final normalizedScope = scope.trim();
    if (normalizedProfileId.isEmpty || normalizedScope.isEmpty) {
      return Future<StoredSyncScopeState?>.value(null);
    }
    return (select(storedSyncScopeStates)
          ..where((table) => table.profileId.equals(normalizedProfileId))
          ..where((table) => table.scope.equals(normalizedScope)))
        .getSingleOrNull();
  }

  Future<void> upsertSyncScopeState(StoredSyncScopeStatesCompanion companion) {
    return into(storedSyncScopeStates).insertOnConflictUpdate(companion);
  }

  Future<List<StoredSyncJob>> listSyncJobs({String? profileId}) {
    final normalizedProfileId = profileId?.trim() ?? '';
    final query = select(storedSyncJobs)
      ..orderBy([(table) => OrderingTerm.desc(table.startedAt)]);
    if (normalizedProfileId.isNotEmpty) {
      query.where((table) => table.profileId.equals(normalizedProfileId));
    }
    return query.get();
  }

  Stream<List<StoredSyncJob>> watchSyncJobs({String? profileId}) {
    final normalizedProfileId = profileId?.trim() ?? '';
    final query = select(storedSyncJobs)
      ..orderBy([(table) => OrderingTerm.desc(table.startedAt)]);
    if (normalizedProfileId.isNotEmpty) {
      query.where((table) => table.profileId.equals(normalizedProfileId));
    }
    return query.watch();
  }

  Future<void> upsertSyncJob(StoredSyncJobsCompanion companion) {
    return into(storedSyncJobs).insertOnConflictUpdate(companion);
  }

  Future<List<StoredSyncConflict>> listSyncConflicts({String? profileId}) {
    final normalizedProfileId = profileId?.trim() ?? '';
    final query = select(storedSyncConflicts)
      ..orderBy([(table) => OrderingTerm.desc(table.createdAt)]);
    if (normalizedProfileId.isNotEmpty) {
      query.where((table) => table.profileId.equals(normalizedProfileId));
    }
    return query.get();
  }

  Stream<List<StoredSyncConflict>> watchSyncConflicts({String? profileId}) {
    final normalizedProfileId = profileId?.trim() ?? '';
    final query = select(storedSyncConflicts)
      ..orderBy([(table) => OrderingTerm.desc(table.createdAt)]);
    if (normalizedProfileId.isNotEmpty) {
      query.where((table) => table.profileId.equals(normalizedProfileId));
    }
    return query.watch();
  }

  Future<void> upsertSyncConflict(StoredSyncConflictsCompanion companion) {
    return into(storedSyncConflicts).insertOnConflictUpdate(companion);
  }

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

  Future<Map<String, int>> getCachedChapterCountsByBookSource(
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
      return <String, int>{};
    }

    final rows =
        await (select(chapterCaches)..where(
          (table) =>
              table.bookId.isIn(requestBookIds) &
              table.sourceId.isIn(requestSourceIds),
        )).get();

    final countsByPairKey = <String, int>{};
    for (final row in rows) {
      final pairKey = _bookSourcePairKey(
        bookId: row.bookId,
        sourceId: row.sourceId,
      );
      if (!requestPairKeys.contains(pairKey)) {
        continue;
      }
      countsByPairKey[pairKey] = (countsByPairKey[pairKey] ?? 0) + 1;
    }

    return countsByPairKey;
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

  Future<int> countSearchSourceHits() async {
    const sql = 'SELECT COUNT(*) AS totalCount FROM search_source_hits';
    final row =
        await customSelect(sql, readsFrom: {searchSourceHits}).getSingle();
    return _decodeCount(row.data['totalCount']);
  }

  Future<int> estimateChapterCachesBytes() async {
    const sql =
        'SELECT COALESCE(SUM('
        'LENGTH(cache_key) + LENGTH(book_id) + LENGTH(source_id) + '
        'COALESCE(LENGTH(chapter_title), 0) + LENGTH(chapter_url) + LENGTH(content)'
        '), 0) AS totalBytes '
        'FROM chapter_caches';
    final row = await customSelect(sql, readsFrom: {chapterCaches}).getSingle();
    return _decodeCount(row.data['totalBytes']);
  }

  Future<int> estimateSearchSourceHitsBytes() async {
    const sql =
        'SELECT COALESCE(SUM('
        'LENGTH(title_norm) + LENGTH(author_norm) + LENGTH(source_id) + '
        'LENGTH(source_name) + LENGTH(title) + COALESCE(LENGTH(author), 0) + '
        'COALESCE(LENGTH(latest_chapter), 0)'
        '), 0) AS totalBytes '
        'FROM search_source_hits';
    final row =
        await customSelect(sql, readsFrom: {searchSourceHits}).getSingle();
    return _decodeCount(row.data['totalBytes']);
  }

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
        'COUNT(*) AS cachedCount, '
        'COALESCE(SUM(LENGTH(cache_key) + LENGTH(book_id) + '
        'LENGTH(source_id) + COALESCE(LENGTH(chapter_title), 0) + '
        'LENGTH(chapter_url) + LENGTH(content)), 0) AS estimatedBytes, '
        'MAX(updated_at) AS updatedAt '
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
            estimatedBytes: _decodeCount(row.data['estimatedBytes']),
            updatedAt: _decodeDateTime(row.data['updatedAt']),
          ),
        )
        .where((item) => item.bookId.trim().isNotEmpty)
        .toList(growable: false);
  }

  Future<int> countChapterCaches() async {
    const sql = 'SELECT COUNT(*) AS totalCount FROM chapter_caches';
    final row = await customSelect(sql, readsFrom: {chapterCaches}).getSingle();
    return _decodeCount(row.data['totalCount']);
  }

  Future<int> pruneOldestChapterCaches({required int maxEntries}) async {
    final normalizedMaxEntries = maxEntries < 0 ? 0 : maxEntries;
    final totalCount = await countChapterCaches();
    final overflowCount = totalCount - normalizedMaxEntries;
    if (overflowCount <= 0) {
      return 0;
    }

    await customStatement(
      'DELETE FROM chapter_caches '
      'WHERE cache_key IN ('
      'SELECT cache_key FROM chapter_caches '
      'ORDER BY updated_at ASC '
      'LIMIT ?'
      ')',
      <Object>[overflowCount],
    );
    return overflowCount;
  }

  Future<int> pruneChapterCachesByBudget({
    required int maxEntries,
    required int maxBytes,
    Duration? stalePeriod,
  }) async {
    var deletedCount = 0;
    if (stalePeriod != null && stalePeriod > Duration.zero) {
      final cutoff = DateTime.now().subtract(stalePeriod);
      deletedCount +=
          await (delete(
            chapterCaches,
          )..where((table) => table.updatedAt.isSmallerThanValue(cutoff))).go();
    }

    final normalizedMaxEntries = maxEntries < 0 ? 0 : maxEntries;
    final totalCount = await countChapterCaches();
    final overflowCount = totalCount - normalizedMaxEntries;
    if (overflowCount > 0) {
      await customStatement(
        'DELETE FROM chapter_caches '
        'WHERE cache_key IN ('
        'SELECT cache_key FROM chapter_caches '
        'ORDER BY updated_at ASC '
        'LIMIT ?'
        ')',
        <Object>[overflowCount],
      );
      deletedCount += overflowCount;
    }

    final normalizedMaxBytes = maxBytes < 0 ? 0 : maxBytes;
    var totalBytes = await estimateChapterCachesBytes();
    if (totalBytes <= normalizedMaxBytes) {
      return deletedCount;
    }

    final rows =
        await customSelect(
          'SELECT cache_key AS cacheKey, '
          'LENGTH(cache_key) + LENGTH(book_id) + LENGTH(source_id) + '
          'COALESCE(LENGTH(chapter_title), 0) + LENGTH(chapter_url) + '
          'LENGTH(content) AS estimatedBytes '
          'FROM chapter_caches '
          'ORDER BY updated_at ASC',
          readsFrom: {chapterCaches},
        ).get();
    final keysToDelete = <String>[];
    for (final row in rows) {
      if (totalBytes <= normalizedMaxBytes) {
        break;
      }
      final cacheKey = (row.data['cacheKey'] ?? '').toString();
      if (cacheKey.trim().isEmpty) {
        continue;
      }
      keysToDelete.add(cacheKey);
      totalBytes -= _decodeCount(row.data['estimatedBytes']);
    }
    if (keysToDelete.isEmpty) {
      return deletedCount;
    }

    await batch((batch) {
      batch.deleteWhere(
        chapterCaches,
        (table) => table.cacheKey.isIn(keysToDelete),
      );
    });
    return deletedCount + keysToDelete.length;
  }

  Stream<List<ChapterCacheBookSummary>> watchCachedBooks() {
    const sql =
        'SELECT book_id AS bookId, source_id AS sourceId, '
        'COUNT(*) AS cachedCount, '
        'COALESCE(SUM(LENGTH(cache_key) + LENGTH(book_id) + '
        'LENGTH(source_id) + COALESCE(LENGTH(chapter_title), 0) + '
        'LENGTH(chapter_url) + LENGTH(content)), 0) AS estimatedBytes, '
        'MAX(updated_at) AS updatedAt '
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
              estimatedBytes: _decodeCount(row.data['estimatedBytes']),
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
        charset: Value(_nullableString(book.charset)),
        fileSize: Value(book.fileSize < 0 ? 0 : book.fileSize),
        author: Value(_nullableString(book.author)),
        description: Value(_nullableString(book.description)),
        coverPath: Value(_nullableString(book.coverPath)),
        sourceFileSize: Value(book.sourceFileSize),
        sourceFileLastModifiedMs: Value(book.sourceFileLastModifiedMs),
        storageFileLastModifiedMs: Value(book.storageFileLastModifiedMs),
        indexStatus: Value(book.indexStatus.name),
        chapterCount: Value(book.chapterCount < 0 ? 0 : book.chapterCount),
        lastError: Value(_nullableString(book.lastError)),
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

  Future<LocalBook?> getLocalBookBySourcePath(String sourcePath) async {
    final normalized = sourcePath.trim();
    if (normalized.isEmpty) {
      return null;
    }

    final row =
        await (select(storedLocalBooks)
              ..where((table) => table.sourcePath.equals(normalized))
              ..limit(1))
            .getSingleOrNull();
    if (row == null) {
      return null;
    }
    return _mapRowToLocalBook(row);
  }

  Future<LocalBook?> findLocalBookByImportFingerprint({
    required LocalBookFormat format,
    required String title,
    required int sourceFileSize,
  }) async {
    final normalizedTitle = _normalizeImportFingerprintText(title);
    if (normalizedTitle.isEmpty || sourceFileSize < 0) {
      return null;
    }

    final rows =
        await (select(storedLocalBooks)
              ..where(
                (table) =>
                    table.format.equals(format.name) &
                    table.sourceFileSize.equals(sourceFileSize),
              )
              ..orderBy([(table) => OrderingTerm.desc(table.updatedAt)]))
            .get();
    for (final row in rows) {
      if (_normalizeImportFingerprintText(row.title) == normalizedTitle) {
        return _mapRowToLocalBook(row);
      }
    }
    return null;
  }

  Future<List<LocalBook>> getAllLocalBooks() async {
    final rows =
        await (select(storedLocalBooks)
          ..orderBy([(table) => OrderingTerm.desc(table.updatedAt)])).get();
    return rows.map(_mapRowToLocalBook).toList(growable: false);
  }

  Stream<List<LocalBook>> watchAllLocalBooks() {
    final query = select(storedLocalBooks)
      ..orderBy([(table) => OrderingTerm.desc(table.updatedAt)]);
    return query.watch().map(
      (rows) => rows.map(_mapRowToLocalBook).toList(growable: false),
    );
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
      await _deleteLocalChapterBodiesByBookId(normalizedBookId);

      final sanitizedChapters = chapters
          .where((chapter) {
            final normalizedId = chapter.id.trim();
            final normalizedTitle = chapter.title.trim();
            final hasSourceRef =
                (chapter.sourceRef?.trim().isNotEmpty ?? false);
            final hasExternalRange =
                chapter.startOffset != null &&
                chapter.endOffset != null &&
                chapter.endOffset! > chapter.startOffset!;
            return normalizedId.isNotEmpty &&
                normalizedTitle.isNotEmpty &&
                (hasExternalRange ||
                    hasSourceRef ||
                    chapter.hasReadablePayload);
          })
          .toList(growable: false);

      if (sanitizedChapters.isNotEmpty) {
        var chunkIndex = 0;
        for (
          var start = 0;
          start < sanitizedChapters.length;
          start += _localChapterInsertBatchSize
        ) {
          final end =
              (start + _localChapterInsertBatchSize)
                  .clamp(0, sanitizedChapters.length)
                  .toInt();
          final chunk = sanitizedChapters.sublist(start, end);
          await batch((batch) {
            for (final chapter in chunk) {
              final normalizedId = chapter.id.trim();
              final normalizedTitle = chapter.title.trim();

              batch.insert(
                storedLocalChapters,
                StoredLocalChaptersCompanion(
                  id: Value(normalizedId),
                  bookId: Value(normalizedBookId),
                  chapterIndex: Value(chapter.chapterIndex),
                  title: Value(normalizedTitle),
                  content: const Value(''),
                  imageUrlsJson: const Value('[]'),
                  documentJson: const Value(null),
                  sourceRef: Value(chapter.sourceRef),
                  startOffset: Value(chapter.startOffset),
                  endOffset: Value(chapter.endOffset),
                  createdAt: Value(chapter.createdAt),
                  updatedAt: Value(chapter.updatedAt),
                ),
                mode: InsertMode.insertOrReplace,
              );
            }
          });
          chunkIndex += 1;
          if (chunkIndex % _localChapterInsertYieldEveryChunks == 0 &&
              end < sanitizedChapters.length) {
            await Future<void>.delayed(Duration.zero);
          }
        }

        final chaptersWithBodies = sanitizedChapters
            .where((chapter) => chapter.hasReadablePayload)
            .toList(growable: false);
        if (chaptersWithBodies.isNotEmpty) {
          await _replaceLocalChapterBodies(
            bookId: normalizedBookId,
            chapters: chaptersWithBodies,
          );
        }
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

    final chapters = rows.map(_mapRowToLocalChapter).toList(growable: false);
    final hydrated = <LocalChapter>[];
    for (final chapter in chapters) {
      hydrated.add(await _hydrateLocalChapterBody(chapter));
    }
    return hydrated;
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
            storedLocalChapters.documentJson,
            storedLocalChapters.sourceRef,
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
            document: _decodeReaderDocument(
              row.read(storedLocalChapters.documentJson),
            ),
            sourceRef: row.read(storedLocalChapters.sourceRef),
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

    return _hydrateLocalChapterBody(_mapRowToLocalChapter(row));
  }

  Future<LocalChapter?> getLocalChapterContentByIndex({
    required String bookId,
    required int chapterIndex,
  }) async {
    final normalizedBookId = bookId.trim();
    if (normalizedBookId.isEmpty) {
      return null;
    }

    final query =
        selectOnly(storedLocalChapters)
          ..addColumns([
            storedLocalChapters.id,
            storedLocalChapters.bookId,
            storedLocalChapters.chapterIndex,
            storedLocalChapters.title,
            storedLocalChapters.content,
            storedLocalChapters.imageUrlsJson,
            storedLocalChapters.sourceRef,
            storedLocalChapters.createdAt,
            storedLocalChapters.updatedAt,
            storedLocalChapters.startOffset,
            storedLocalChapters.endOffset,
          ])
          ..where(storedLocalChapters.bookId.equals(normalizedBookId))
          ..where(storedLocalChapters.chapterIndex.equals(chapterIndex))
          ..limit(1);

    final row = await query.getSingleOrNull();
    if (row == null) {
      return null;
    }

    final chapter = LocalChapter(
      id: row.read(storedLocalChapters.id)!,
      bookId: row.read(storedLocalChapters.bookId)!,
      chapterIndex: row.read(storedLocalChapters.chapterIndex)!,
      title: row.read(storedLocalChapters.title)!,
      content: '',
      imageUrls: const <String>[],
      sourceRef: row.read(storedLocalChapters.sourceRef),
      createdAt: row.read(storedLocalChapters.createdAt)!,
      updatedAt: row.read(storedLocalChapters.updatedAt)!,
      startOffset: row.read(storedLocalChapters.startOffset),
      endOffset: row.read(storedLocalChapters.endOffset),
    );
    return _hydrateLocalChapterBody(chapter, includeDocument: false);
  }

  Future<LocalChapter?> getLocalChapterMetaByIndex({
    required String bookId,
    required int chapterIndex,
  }) async {
    final normalizedBookId = bookId.trim();
    if (normalizedBookId.isEmpty) {
      return null;
    }

    final query =
        selectOnly(storedLocalChapters)
          ..addColumns([
            storedLocalChapters.id,
            storedLocalChapters.bookId,
            storedLocalChapters.chapterIndex,
            storedLocalChapters.title,
            storedLocalChapters.sourceRef,
            storedLocalChapters.startOffset,
            storedLocalChapters.endOffset,
            storedLocalChapters.createdAt,
            storedLocalChapters.updatedAt,
          ])
          ..where(storedLocalChapters.bookId.equals(normalizedBookId))
          ..where(storedLocalChapters.chapterIndex.equals(chapterIndex))
          ..limit(1);

    final row = await query.getSingleOrNull();
    if (row == null) {
      return null;
    }

    return LocalChapter(
      id: row.read(storedLocalChapters.id)!,
      bookId: row.read(storedLocalChapters.bookId)!,
      chapterIndex: row.read(storedLocalChapters.chapterIndex)!,
      title: row.read(storedLocalChapters.title)!,
      content: '',
      sourceRef: row.read(storedLocalChapters.sourceRef),
      createdAt: row.read(storedLocalChapters.createdAt)!,
      updatedAt: row.read(storedLocalChapters.updatedAt)!,
      startOffset: row.read(storedLocalChapters.startOffset),
      endOffset: row.read(storedLocalChapters.endOffset),
    );
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

    return _hydrateLocalChapterBody(_mapRowToLocalChapter(row));
  }

  Future<LocalChapter?> getLocalChapterMetaById(String chapterId) async {
    final normalizedId = chapterId.trim();
    if (normalizedId.isEmpty) {
      return null;
    }

    final query =
        selectOnly(storedLocalChapters)
          ..addColumns([
            storedLocalChapters.id,
            storedLocalChapters.bookId,
            storedLocalChapters.chapterIndex,
            storedLocalChapters.title,
            storedLocalChapters.sourceRef,
            storedLocalChapters.startOffset,
            storedLocalChapters.endOffset,
            storedLocalChapters.createdAt,
            storedLocalChapters.updatedAt,
          ])
          ..where(storedLocalChapters.id.equals(normalizedId))
          ..limit(1);

    final row = await query.getSingleOrNull();
    if (row == null) {
      return null;
    }

    return LocalChapter(
      id: row.read(storedLocalChapters.id)!,
      bookId: row.read(storedLocalChapters.bookId)!,
      chapterIndex: row.read(storedLocalChapters.chapterIndex)!,
      title: row.read(storedLocalChapters.title)!,
      content: '',
      sourceRef: row.read(storedLocalChapters.sourceRef),
      createdAt: row.read(storedLocalChapters.createdAt)!,
      updatedAt: row.read(storedLocalChapters.updatedAt)!,
      startOffset: row.read(storedLocalChapters.startOffset),
      endOffset: row.read(storedLocalChapters.endOffset),
    );
  }

  Future<LocalChapter?> getLocalChapterContentById(String chapterId) async {
    final normalizedId = chapterId.trim();
    if (normalizedId.isEmpty) {
      return null;
    }

    final query =
        selectOnly(storedLocalChapters)
          ..addColumns([
            storedLocalChapters.id,
            storedLocalChapters.bookId,
            storedLocalChapters.chapterIndex,
            storedLocalChapters.title,
            storedLocalChapters.content,
            storedLocalChapters.imageUrlsJson,
            storedLocalChapters.sourceRef,
            storedLocalChapters.createdAt,
            storedLocalChapters.updatedAt,
            storedLocalChapters.startOffset,
            storedLocalChapters.endOffset,
          ])
          ..where(storedLocalChapters.id.equals(normalizedId))
          ..limit(1);

    final row = await query.getSingleOrNull();
    if (row == null) {
      return null;
    }

    final chapter = LocalChapter(
      id: row.read(storedLocalChapters.id)!,
      bookId: row.read(storedLocalChapters.bookId)!,
      chapterIndex: row.read(storedLocalChapters.chapterIndex)!,
      title: row.read(storedLocalChapters.title)!,
      content: '',
      imageUrls: const <String>[],
      sourceRef: row.read(storedLocalChapters.sourceRef),
      createdAt: row.read(storedLocalChapters.createdAt)!,
      updatedAt: row.read(storedLocalChapters.updatedAt)!,
      startOffset: row.read(storedLocalChapters.startOffset),
      endOffset: row.read(storedLocalChapters.endOffset),
    );
    return _hydrateLocalChapterBody(chapter, includeDocument: false);
  }

  Future<void> updateLocalChapterContent({
    required String chapterId,
    required String content,
    List<String> imageUrls = const <String>[],
    ReaderDocument? document,
  }) async {
    final normalizedChapterId = chapterId.trim();
    if (normalizedChapterId.isEmpty) {
      return;
    }
    final meta = await getLocalChapterMetaById(normalizedChapterId);
    if (meta == null) {
      return;
    }
    await _upsertLocalChapterBody(
      chapter: meta.copyWith(
        content: content,
        imageUrls: imageUrls,
        document: document,
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> deleteLocalBook(String bookId) async {
    final normalizedId = bookId.trim();
    if (normalizedId.isEmpty) {
      return;
    }

    await transaction(() async {
      await (delete(storedBookmarks)
        ..where((table) => table.bookId.equals(normalizedId))).go();
      await (delete(storedReadingProgresses)
        ..where((table) => table.bookId.equals(normalizedId))).go();
      await (delete(storedReadingRecords)
        ..where((table) => table.bookId.equals(normalizedId))).go();
      await (delete(storedReadingRecordDays)
        ..where((table) => table.bookId.equals(normalizedId))).go();
      await (delete(storedReadingRecordSessions)
        ..where((table) => table.bookId.equals(normalizedId))).go();
      await (delete(storedReadingBookStatuses)
        ..where((table) => table.bookId.equals(normalizedId))).go();
      await (delete(storedTocSnapshots)
        ..where((table) => table.bookId.equals(normalizedId))).go();
      await deleteBookMetadataOverrideByLocalBookId(normalizedId);
      await _deleteLocalChapterBodiesByBookId(normalizedId);
      await (delete(storedLocalChapters)
        ..where((table) => table.bookId.equals(normalizedId))).go();
      await (delete(storedLocalBooks)
        ..where((table) => table.id.equals(normalizedId))).go();
    });
  }

  Future<ReaderTocSnapshot?> getTocSnapshot(String storageKey) async {
    final normalizedKey = storageKey.trim();
    if (normalizedKey.isEmpty) {
      return null;
    }
    final row =
        await (select(storedTocSnapshots)..where(
          (table) => table.storageKey.equals(normalizedKey),
        )).getSingleOrNull();
    if (row == null) {
      return null;
    }
    try {
      final decoded = jsonDecode(row.chaptersJson);
      final chapters =
          decoded is List
              ? decoded
                  .whereType<Map>()
                  .map(
                    (item) => Chapter.fromJson(
                      item.map((key, value) => MapEntry(key.toString(), value)),
                    ),
                  )
                  .toList(growable: false)
              : const <Chapter>[];
      return ReaderTocSnapshot(
        bookId: row.bookId,
        sourceId: row.sourceId,
        detailUrl: row.detailUrl,
        title: row.title,
        author: row.author,
        coverUrl: row.coverUrl,
        chapters: chapters,
        updatedAt: row.updatedAt,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> upsertTocSnapshot(ReaderTocSnapshot snapshot) async {
    final storageKey =
        '${snapshot.sourceId.trim()}|${snapshot.detailUrl.trim()}';
    if (storageKey.trim().isEmpty) {
      return;
    }
    await into(storedTocSnapshots).insert(
      StoredTocSnapshotsCompanion(
        storageKey: Value(storageKey),
        bookId: Value(snapshot.bookId.trim()),
        sourceId: Value(snapshot.sourceId.trim()),
        detailUrl: Value(snapshot.detailUrl.trim()),
        title: Value(snapshot.title.trim()),
        author: Value(_nullableString(snapshot.author)),
        coverUrl: Value(_nullableString(snapshot.coverUrl)),
        chaptersJson: Value(
          jsonEncode(snapshot.chapters.map((item) => item.toJson()).toList()),
        ),
        updatedAt: Value(snapshot.updatedAt),
      ),
      mode: InsertMode.insertOrReplace,
    );
  }

  Future<void> _replaceLocalChapterBodies({
    required String bookId,
    required List<LocalChapter> chapters,
  }) async {
    await _deleteLocalChapterBodiesByBookId(bookId);
    for (final chapter in chapters) {
      await _upsertLocalChapterBody(chapter: chapter);
    }
  }

  Future<void> _upsertLocalChapterBody({required LocalChapter chapter}) async {
    final normalizedChapterId = chapter.id.trim();
    final normalizedBookId = chapter.bookId.trim();
    if (normalizedChapterId.isEmpty || normalizedBookId.isEmpty) {
      return;
    }
    await customStatement(
      '''
      INSERT OR REPLACE INTO ${_quoteIdentifier(_localChapterBodiesTableName)} (
        chapter_id,
        book_id,
        content,
        image_urls_json,
        document_json,
        created_at,
        updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?)
      ''',
      <Object?>[
        normalizedChapterId,
        normalizedBookId,
        chapter.content,
        jsonEncode(chapter.imageUrls),
        chapter.document == null
            ? null
            : jsonEncode(chapter.document!.toJson()),
        chapter.createdAt.toIso8601String(),
        chapter.updatedAt.toIso8601String(),
      ],
    );
  }

  Future<void> _deleteLocalChapterBodiesByBookId(String bookId) async {
    final normalizedBookId = bookId.trim();
    if (normalizedBookId.isEmpty) {
      return;
    }
    await customStatement(
      'DELETE FROM ${_quoteIdentifier(_localChapterBodiesTableName)} WHERE book_id = ?',
      <Object>[normalizedBookId],
    );
  }

  Future<LocalChapter> _hydrateLocalChapterBody(
    LocalChapter chapter, {
    bool includeDocument = true,
  }) async {
    final rows =
        await customSelect(
          '''
      SELECT content, image_urls_json, document_json, created_at, updated_at
      FROM ${_quoteIdentifier(_localChapterBodiesTableName)}
      WHERE chapter_id = ?
      LIMIT 1
      ''',
          variables: <Variable<Object>>[Variable<String>(chapter.id)],
        ).get();
    if (rows.isEmpty) {
      return chapter;
    }
    final row = rows.first.data;
    return chapter.copyWith(
      content: (row['content'] ?? '').toString(),
      imageUrls: _decodeStringList(row['image_urls_json']?.toString()),
      document:
          includeDocument
              ? _decodeReaderDocument(row['document_json']?.toString())
              : null,
      clearDocument: !includeDocument,
      createdAt: _decodeDateTime(row['created_at']),
      updatedAt: _decodeDateTime(row['updated_at']),
    );
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
        note: Value(_nullableString(bookmark.note)),
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

  Future<void> upsertBookMetadataOverride(
    BookMetadataOverride metadataOverride,
  ) async {
    final normalizedTargetKey = metadataOverride.targetKey.trim();
    if (normalizedTargetKey.isEmpty) {
      return;
    }

    final now = DateTime.now();
    await into(storedBookMetadataOverrides).insert(
      StoredBookMetadataOverridesCompanion(
        targetKey: Value(normalizedTargetKey),
        bookId: Value(_nullableString(metadataOverride.bookId)),
        sourceId: Value(_nullableString(metadataOverride.sourceId)),
        detailUrl: Value(_nullableString(metadataOverride.detailUrl)),
        title: Value(_nullableString(metadataOverride.title)),
        author: Value(_nullableString(metadataOverride.author)),
        intro: Value(_nullableString(metadataOverride.intro)),
        coverPath: Value(_nullableString(metadataOverride.coverPath)),
        createdAt: Value(metadataOverride.createdAt),
        updatedAt: Value(
          metadataOverride.updatedAt == metadataOverride.createdAt
              ? now
              : metadataOverride.updatedAt,
        ),
      ),
      mode: InsertMode.insertOrReplace,
    );
  }

  Future<BookMetadataOverride?> getBookMetadataOverrideByTargetKey(
    String targetKey,
  ) async {
    final normalizedTargetKey = targetKey.trim();
    if (normalizedTargetKey.isEmpty) {
      return null;
    }

    final row =
        await (select(storedBookMetadataOverrides)..where(
          (table) => table.targetKey.equals(normalizedTargetKey),
        )).getSingleOrNull();
    if (row == null) {
      return null;
    }
    return _mapRowToBookMetadataOverride(row);
  }

  Future<BookMetadataOverride?> getBookMetadataOverrideByLocalBookId(
    String bookId,
  ) async {
    final normalizedBookId = bookId.trim();
    if (normalizedBookId.isEmpty) {
      return null;
    }
    return getBookMetadataOverrideByTargetKey(
      BookMetadataOverride.localTargetKey(normalizedBookId),
    );
  }

  Future<BookMetadataOverride?> getBookMetadataOverrideByRemoteBook({
    required String sourceId,
    required String detailUrl,
  }) async {
    final normalizedSourceId = sourceId.trim();
    final normalizedDetailUrl = detailUrl.trim();
    if (normalizedSourceId.isEmpty || normalizedDetailUrl.isEmpty) {
      return null;
    }
    return getBookMetadataOverrideByTargetKey(
      BookMetadataOverride.remoteTargetKey(
        sourceId: normalizedSourceId,
        detailUrl: normalizedDetailUrl,
      ),
    );
  }

  Future<List<BookMetadataOverride>> getAllBookMetadataOverrides() async {
    final rows =
        await (select(storedBookMetadataOverrides)
          ..orderBy([(table) => OrderingTerm.desc(table.updatedAt)])).get();
    return rows.map(_mapRowToBookMetadataOverride).toList(growable: false);
  }

  Stream<List<BookMetadataOverride>> watchBookMetadataOverrides() {
    final query = select(storedBookMetadataOverrides)
      ..orderBy([(table) => OrderingTerm.desc(table.updatedAt)]);
    return query.watch().map(
      (rows) => rows.map(_mapRowToBookMetadataOverride).toList(growable: false),
    );
  }

  Future<void> deleteBookMetadataOverrideByTargetKey(String targetKey) {
    final normalizedTargetKey = targetKey.trim();
    if (normalizedTargetKey.isEmpty) {
      return Future<void>.value();
    }
    return (delete(storedBookMetadataOverrides)
      ..where((table) => table.targetKey.equals(normalizedTargetKey))).go();
  }

  Future<void> deleteBookMetadataOverrideByLocalBookId(String bookId) {
    final normalizedBookId = bookId.trim();
    if (normalizedBookId.isEmpty) {
      return Future<void>.value();
    }
    return deleteBookMetadataOverrideByTargetKey(
      BookMetadataOverride.localTargetKey(normalizedBookId),
    );
  }

  Future<void> deleteBookMetadataOverrideByRemoteBook({
    required String sourceId,
    required String detailUrl,
  }) {
    final normalizedSourceId = sourceId.trim();
    final normalizedDetailUrl = detailUrl.trim();
    if (normalizedSourceId.isEmpty || normalizedDetailUrl.isEmpty) {
      return Future<void>.value();
    }
    return deleteBookMetadataOverrideByTargetKey(
      BookMetadataOverride.remoteTargetKey(
        sourceId: normalizedSourceId,
        detailUrl: normalizedDetailUrl,
      ),
    );
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

  Future<List<ReadingRecordSession>> listAllReadingRecordSessions() async {
    final rows =
        await (select(storedReadingRecordSessions)
          ..orderBy([(table) => OrderingTerm.asc(table.startAt)])).get();
    return rows.map(_mapRowToReadingRecordSession).toList(growable: false);
  }

  Future<List<ReadingRecordDay>> listAllReadingRecordDays() async {
    final rows =
        await (select(storedReadingRecordDays)..orderBy([
          (table) => OrderingTerm.desc(table.dateKey),
          (table) => OrderingTerm.desc(table.lastReadAt),
        ])).get();
    return rows.map(_mapRowToReadingRecordDay).toList(growable: false);
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

  Stream<List<ReadingBookStatusEntry>> watchReadingBookStatuses() {
    final query = select(storedReadingBookStatuses)
      ..orderBy([(table) => OrderingTerm.desc(table.updatedAt)]);
    return query.watch().map(
      (rows) => rows
          .map<ReadingBookStatusEntry>(_mapRowToReadingBookStatus)
          .toList(growable: false),
    );
  }

  Future<List<ReadingBookStatusEntry>> listReadingBookStatuses() async {
    final rows =
        await (select(storedReadingBookStatuses)
          ..orderBy([(table) => OrderingTerm.desc(table.updatedAt)])).get();
    return rows
        .map<ReadingBookStatusEntry>(_mapRowToReadingBookStatus)
        .toList(growable: false);
  }

  Future<void> upsertReadingBookStatus(ReadingBookStatusEntry status) async {
    final normalizedBookId = status.bookId.trim();
    final normalizedSourceId = status.sourceId.trim();
    final normalizedDetailUrl = status.detailUrl.trim();
    final normalizedTitle = status.bookTitle.trim();
    if (normalizedBookId.isEmpty ||
        normalizedSourceId.isEmpty ||
        normalizedDetailUrl.isEmpty ||
        normalizedTitle.isEmpty) {
      return;
    }

    await into(storedReadingBookStatuses).insert(
      StoredReadingBookStatusesCompanion(
        bookId: Value(normalizedBookId),
        sourceId: Value(normalizedSourceId),
        detailUrl: Value(normalizedDetailUrl),
        bookTitle: Value(normalizedTitle),
        statusOverride: Value(status.override.name),
        updatedAt: Value(status.updatedAt),
      ),
      mode: InsertMode.insertOrReplace,
    );
  }

  Future<void> deleteReadingBookStatus(String bookId) async {
    final normalizedBookId = bookId.trim();
    if (normalizedBookId.isEmpty) {
      return;
    }

    await (delete(storedReadingBookStatuses)
      ..where((table) => table.bookId.equals(normalizedBookId))).go();
  }

  Future<ReadingProgress?> getReadingProgressByBookId(String bookId) async {
    final normalizedBookId = bookId.trim();
    if (normalizedBookId.isEmpty) {
      return null;
    }

    final row =
        await (select(storedReadingProgresses)
              ..where((table) => table.bookId.equals(normalizedBookId))
              ..limit(1))
            .getSingleOrNull();
    if (row == null) {
      return null;
    }
    return _mapRowToReadingProgress(row);
  }

  Future<List<ReadingProgress>> listReadingProgresses() async {
    final rows =
        await (select(storedReadingProgresses)
          ..orderBy([(table) => OrderingTerm.desc(table.updatedAt)])).get();
    return rows
        .map<ReadingProgress>(_mapRowToReadingProgress)
        .toList(growable: false);
  }

  Future<void> upsertReadingProgress(ReadingProgress progress) async {
    final normalizedBookId = progress.bookId.trim();
    final normalizedSourceId = progress.sourceId.trim();
    final normalizedDetailUrl = progress.detailUrl.trim();
    final normalizedChapterId = progress.chapterId.trim();
    final normalizedChapterUrl = progress.chapterUrl.trim();
    final normalizedChapterTitle = progress.chapterTitle.trim();
    if (normalizedBookId.isEmpty ||
        normalizedSourceId.isEmpty ||
        normalizedDetailUrl.isEmpty ||
        normalizedChapterId.isEmpty ||
        normalizedChapterUrl.isEmpty ||
        normalizedChapterTitle.isEmpty) {
      return;
    }

    await into(storedReadingProgresses).insert(
      StoredReadingProgressesCompanion(
        bookId: Value(normalizedBookId),
        sourceId: Value(normalizedSourceId),
        detailUrl: Value(normalizedDetailUrl),
        chapterId: Value(normalizedChapterId),
        chapterUrl: Value(normalizedChapterUrl),
        chapterTitle: Value(normalizedChapterTitle),
        chapterIndex: Value(progress.chapterIndex),
        chapterPositionRatio: Value(progress.chapterPositionRatio),
        logicalPositionJson: Value(
          progress.logicalPosition == null
              ? null
              : jsonEncode(progress.logicalPosition!.toJson()),
        ),
        updatedAt: Value(progress.updatedAt),
      ),
      mode: InsertMode.insertOrReplace,
    );
  }

  Future<void> deleteReadingProgress(String bookId) async {
    final normalizedBookId = bookId.trim();
    if (normalizedBookId.isEmpty) {
      return;
    }

    await (delete(storedReadingProgresses)
      ..where((table) => table.bookId.equals(normalizedBookId))).go();
  }

  Future<Map<String, SourceHealthSnapshot>> listSourceHealthSnapshots() async {
    final rows = await select(storedSourceHealthSnapshots).get();
    final result = <String, SourceHealthSnapshot>{};
    for (final row in rows) {
      final snapshot = _mapRowToSourceHealthSnapshot(row);
      if (snapshot == null) {
        continue;
      }
      result[snapshot.sourceId.trim()] = snapshot;
    }
    return result;
  }

  Future<void> replaceSourceHealthSnapshots(
    Map<String, SourceHealthSnapshot> snapshots,
  ) async {
    await transaction(() async {
      await delete(storedSourceHealthSnapshots).go();
      if (snapshots.isEmpty) {
        return;
      }
      await batch((batch) {
        for (final entry in snapshots.entries) {
          final sourceId = entry.key.trim();
          if (sourceId.isEmpty) {
            continue;
          }
          batch.insert(
            storedSourceHealthSnapshots,
            StoredSourceHealthSnapshotsCompanion(
              sourceId: Value(sourceId),
              payloadJson: Value(jsonEncode(entry.value.toJson())),
              updatedAt: Value(DateTime.now().toUtc()),
            ),
            mode: InsertMode.insertOrReplace,
          );
        }
      });
    });
  }

  Future<StoredRemoteAccessSnapshot?> getRemoteAccessSnapshot(String userId) {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      return Future<StoredRemoteAccessSnapshot?>.value(null);
    }
    return (select(storedRemoteAccessSnapshots)
          ..where((table) => table.userId.equals(normalizedUserId))
          ..limit(1))
        .getSingleOrNull();
  }

  Future<void> upsertRemoteAccessSnapshot({
    required String userId,
    required bool serverSourceGatewayEnabled,
    required bool hasMembership,
    required bool hasThemeCustom,
    required int serverSourceGatewayLimit,
    required DateTime cachedAt,
    DateTime? vipExpireAt,
    String? membershipPlanType,
  }) async {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      return;
    }
    await into(storedRemoteAccessSnapshots).insert(
      StoredRemoteAccessSnapshotsCompanion(
        userId: Value(normalizedUserId),
        serverSourceGatewayEnabled: Value(serverSourceGatewayEnabled),
        hasMembership: Value(hasMembership),
        hasThemeCustom: Value(hasThemeCustom),
        serverSourceGatewayLimit: Value(serverSourceGatewayLimit),
        cachedAt: Value(cachedAt),
        vipExpireAt: Value(vipExpireAt),
        membershipPlanType: Value(membershipPlanType),
      ),
      mode: InsertMode.insertOrReplace,
    );
  }

  Future<void> deleteRemoteAccessSnapshot(String userId) async {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      return;
    }
    await (delete(storedRemoteAccessSnapshots)
      ..where((table) => table.userId.equals(normalizedUserId))).go();
  }

  Future<List<StoredBookshelfBook>> listBookshelfBooks() {
    return (select(storedBookshelfBooks)
      ..orderBy([(table) => OrderingTerm.desc(table.addedAt)])).get();
  }

  Future<List<StoredBookshelfTagAssignment>> listBookshelfTagAssignments() {
    return (select(storedBookshelfTagAssignments)..orderBy([
      (table) => OrderingTerm.asc(table.sourceId),
      (table) => OrderingTerm.asc(table.detailUrl),
      (table) => OrderingTerm.asc(table.position),
    ])).get();
  }

  Future<List<StoredBookshelfTagMetadataData>> listBookshelfTagMetadata() {
    return (select(storedBookshelfTagMetadata)
      ..orderBy([(table) => OrderingTerm.asc(table.position)])).get();
  }

  Future<List<StoredBookshelfCategoryMetadataData>>
  listBookshelfCategoryMetadata() {
    return (select(storedBookshelfCategoryMetadata)
      ..orderBy([(table) => OrderingTerm.asc(table.position)])).get();
  }

  Future<List<StoredBookshelfBaseFilterOrder>> listBookshelfBaseFilterOrders() {
    return (select(storedBookshelfBaseFilterOrders)
      ..orderBy([(table) => OrderingTerm.asc(table.position)])).get();
  }

  Future<void> replaceBookshelfSnapshot({
    required List<BookshelfBook> books,
    required Map<String, List<String>> tagMap,
    required List<BookshelfTaxonomySnapshotItem> tagItems,
    required List<BookshelfTaxonomySnapshotItem> categoryItems,
    required List<String> baseFilterOrder,
  }) async {
    await transaction(() async {
      await delete(storedBookshelfBooks).go();
      await delete(storedBookshelfTagAssignments).go();
      await delete(storedBookshelfTagMetadata).go();
      await delete(storedBookshelfCategoryMetadata).go();
      await delete(storedBookshelfBaseFilterOrders).go();

      if (books.isNotEmpty) {
        await batch((batch) {
          batch.insertAll(
            storedBookshelfBooks,
            books
                .map(
                  (book) => StoredBookshelfBooksCompanion.insert(
                    sourceId: book.sourceId.trim(),
                    detailUrl: book.detailUrl.trim(),
                    bookId: book.bookId.trim(),
                    title: book.title.trim(),
                    author: Value(_nullableBookshelfString(book.author)),
                    category: Value(_nullableBookshelfString(book.category)),
                    coverUrl: Value(_nullableBookshelfString(book.coverUrl)),
                    latestChapter: Value(
                      _nullableBookshelfString(book.latestChapter),
                    ),
                    inReadingQueue: Value(book.inReadingQueue),
                    addedAt: book.addedAt,
                    updatedAt: Value(DateTime.now().toUtc()),
                  ),
                )
                .toList(growable: false),
          );
        });
      }

      final tagAssignments = <StoredBookshelfTagAssignmentsCompanion>[];
      for (final entry in tagMap.entries) {
        final split = _splitBookshelfEntryKey(entry.key);
        if (split == null) {
          continue;
        }
        for (var index = 0; index < entry.value.length; index += 1) {
          final tagName = entry.value[index].trim();
          if (tagName.isEmpty) {
            continue;
          }
          tagAssignments.add(
            StoredBookshelfTagAssignmentsCompanion.insert(
              sourceId: split.$1,
              detailUrl: split.$2,
              tagName: tagName,
              position: Value(index),
            ),
          );
        }
      }
      if (tagAssignments.isNotEmpty) {
        await batch((batch) {
          batch.insertAll(storedBookshelfTagAssignments, tagAssignments);
        });
      }

      if (tagItems.isNotEmpty) {
        await batch((batch) {
          batch.insertAll(
            storedBookshelfTagMetadata,
            tagItems
                .asMap()
                .entries
                .map(
                  (entry) => StoredBookshelfTagMetadataCompanion.insert(
                    name: entry.value.name.trim(),
                    colorValue: entry.value.colorValue,
                    position: Value(entry.key),
                  ),
                )
                .toList(growable: false),
          );
        });
      }

      if (categoryItems.isNotEmpty) {
        await batch((batch) {
          batch.insertAll(
            storedBookshelfCategoryMetadata,
            categoryItems
                .asMap()
                .entries
                .map(
                  (entry) => StoredBookshelfCategoryMetadataCompanion.insert(
                    name: entry.value.name.trim(),
                    colorValue: entry.value.colorValue,
                    position: Value(entry.key),
                  ),
                )
                .toList(growable: false),
          );
        });
      }

      if (baseFilterOrder.isNotEmpty) {
        await batch((batch) {
          batch.insertAll(
            storedBookshelfBaseFilterOrders,
            baseFilterOrder
                .asMap()
                .entries
                .map(
                  (entry) => StoredBookshelfBaseFilterOrdersCompanion.insert(
                    filterKey: entry.value.trim(),
                    position: Value(entry.key),
                  ),
                )
                .toList(growable: false),
          );
        });
      }
    });
  }

  String? _nullableBookshelfString(String? value) {
    final normalized = value?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }

  (String, String)? _splitBookshelfEntryKey(String rawKey) {
    final separator = rawKey.indexOf('::');
    if (separator <= 0 || separator >= rawKey.length - 2) {
      return null;
    }
    final sourceId = rawKey.substring(0, separator).trim();
    final detailUrl = rawKey.substring(separator + 2).trim();
    if (sourceId.isEmpty || detailUrl.isEmpty) {
      return null;
    }
    return (sourceId, detailUrl);
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

  Future<AppDatabaseMaintenanceReport> runStorageMaintenance({
    DateTime? now,
    Duration staleSearchSourceHitRetention = const Duration(days: 90),
  }) async {
    return transaction(() async {
      final localBookIds = await _listAllLocalBookIds();
      final orphanedLocalReadingProgresses = await _deleteLocalSourceOrphans(
        tableName: storedReadingProgresses.tableName,
        sourceIdColumn: 'source_id',
        bookIdColumn: 'book_id',
        retainedBookIds: localBookIds,
      );
      final orphanedLocalReadingRecords = await _deleteLocalSourceOrphans(
        tableName: storedReadingRecords.tableName,
        sourceIdColumn: 'source_id',
        bookIdColumn: 'book_id',
        retainedBookIds: localBookIds,
      );
      final orphanedLocalReadingRecordSessions =
          await _deleteLocalSourceOrphans(
            tableName: storedReadingRecordSessions.tableName,
            sourceIdColumn: 'source_id',
            bookIdColumn: 'book_id',
            retainedBookIds: localBookIds,
          );
      final orphanedLocalReadingBookStatuses = await _deleteLocalSourceOrphans(
        tableName: storedReadingBookStatuses.tableName,
        sourceIdColumn: 'source_id',
        bookIdColumn: 'book_id',
        retainedBookIds: localBookIds,
      );
      final orphanedLocalTocSnapshots = await _deleteLocalSourceOrphans(
        tableName: storedTocSnapshots.tableName,
        sourceIdColumn: 'source_id',
        bookIdColumn: 'book_id',
        retainedBookIds: localBookIds,
      );
      final orphanedLocalMetadataOverrides =
          await _deleteLocalMetadataOverrides(localBookIds);
      final staleSearchSourceHits = await _deleteStaleSearchSourceHits(
        cutoff: (now ?? DateTime.now()).subtract(staleSearchSourceHitRetention),
      );
      return AppDatabaseMaintenanceReport(
        orphanedLocalReadingProgresses: orphanedLocalReadingProgresses,
        orphanedLocalReadingRecords: orphanedLocalReadingRecords,
        orphanedLocalReadingRecordSessions: orphanedLocalReadingRecordSessions,
        orphanedLocalReadingBookStatuses: orphanedLocalReadingBookStatuses,
        orphanedLocalTocSnapshots: orphanedLocalTocSnapshots,
        orphanedLocalMetadataOverrides: orphanedLocalMetadataOverrides,
        staleSearchSourceHits: staleSearchSourceHits,
      );
    });
  }

  Future<List<String>> _listAllLocalBookIds() async {
    final rows =
        await (select(storedLocalBooks)
          ..orderBy([(table) => OrderingTerm.asc(table.id)])).get();
    return rows
        .map((row) => row.id.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
  }

  Future<int> _deleteLocalMetadataOverrides(
    List<String> retainedBookIds,
  ) async {
    if (retainedBookIds.isEmpty) {
      return (delete(storedBookMetadataOverrides)
        ..where((table) => table.bookId.isNotNull())).go();
    }
    return (delete(storedBookMetadataOverrides)..where(
      (table) =>
          table.bookId.isNotNull() & table.bookId.isNotIn(retainedBookIds),
    )).go();
  }

  Future<int> _deleteLocalSourceOrphans({
    required String tableName,
    required String sourceIdColumn,
    required String bookIdColumn,
    required List<String> retainedBookIds,
  }) async {
    const localSourceId = BookIdentityScheme.localSourceId;
    if (retainedBookIds.isEmpty) {
      await customStatement(
        'DELETE FROM ${_quoteIdentifier(tableName)} '
        'WHERE ${_quoteIdentifier(sourceIdColumn)} = ?',
        <Object>[localSourceId],
      );
      return _rowsChanged();
    }

    final placeholders = List<String>.filled(
      retainedBookIds.length,
      '?',
    ).join(', ');
    await customStatement(
      'DELETE FROM ${_quoteIdentifier(tableName)} '
      'WHERE ${_quoteIdentifier(sourceIdColumn)} = ? '
      'AND ${_quoteIdentifier(bookIdColumn)} NOT IN ($placeholders)',
      <Object>[localSourceId, ...retainedBookIds],
    );
    return _rowsChanged();
  }

  Future<int> _deleteStaleSearchSourceHits({required DateTime cutoff}) async {
    await customStatement(
      'DELETE FROM ${_quoteIdentifier(searchSourceHits.tableName)} '
      'WHERE updated_at < ?',
      <Object>[cutoff.toUtc().millisecondsSinceEpoch],
    );
    return _rowsChanged();
  }

  Future<int> _rowsChanged() async {
    final row = await customSelect('SELECT changes() AS count').getSingle();
    return _decodeCount(row.data['count']);
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
      description: row.description,
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
      document: _decodeReaderDocument(row.documentJson),
      sourceRef: row.sourceRef,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      startOffset: row.startOffset,
      endOffset: row.endOffset,
    );
  }

  ReaderDocument? _decodeReaderDocument(String? raw) {
    final normalized = raw?.trim() ?? '';
    if (normalized.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(normalized);
      if (decoded is! Map) {
        return null;
      }
      return ReaderDocument.fromJson(
        decoded.map((key, value) => MapEntry(key.toString(), value)),
      );
    } catch (_) {
      return null;
    }
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
      note: _nullableString(row.note),
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      isBold: row.isBold,
      isUnderline: row.isUnderline,
      isWavy: row.isWavy,
      color: row.color,
    );
  }

  BookMetadataOverride _mapRowToBookMetadataOverride(
    StoredBookMetadataOverride row,
  ) {
    return BookMetadataOverride(
      targetKey: row.targetKey,
      bookId: _nullableString(row.bookId),
      sourceId: _nullableString(row.sourceId),
      detailUrl: _nullableString(row.detailUrl),
      title: _nullableString(row.title),
      author: _nullableString(row.author),
      intro: _nullableString(row.intro),
      coverPath: _nullableString(row.coverPath),
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
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

  ReadingBookStatusEntry _mapRowToReadingBookStatus(
    StoredReadingBookStatuse row,
  ) {
    return ReadingBookStatusEntry(
      bookId: row.bookId,
      sourceId: row.sourceId,
      detailUrl: row.detailUrl,
      bookTitle: row.bookTitle,
      override: ReadingBookStatusOverride.values.firstWhere(
        (item) => item.name == row.statusOverride,
        orElse: () => ReadingBookStatusOverride.reading,
      ),
      updatedAt: row.updatedAt,
    );
  }

  ReadingProgress _mapRowToReadingProgress(StoredReadingProgressesData row) {
    ReaderLogicalPosition? logicalPosition;
    final rawLogicalPosition = row.logicalPositionJson?.trim();
    if (rawLogicalPosition != null && rawLogicalPosition.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawLogicalPosition);
        if (decoded is Map) {
          logicalPosition = ReaderLogicalPosition.fromJson(
            decoded.map((key, value) => MapEntry(key.toString(), value)),
          );
        }
      } catch (_) {
        logicalPosition = null;
      }
    }

    return ReadingProgress(
      bookId: row.bookId,
      sourceId: row.sourceId,
      detailUrl: row.detailUrl,
      chapterId: row.chapterId,
      chapterUrl: row.chapterUrl,
      chapterTitle: row.chapterTitle,
      chapterIndex: row.chapterIndex,
      updatedAt: row.updatedAt,
      chapterPositionRatio: row.chapterPositionRatio.clamp(0.0, 1.0),
      logicalPosition: logicalPosition,
    );
  }

  SourceHealthSnapshot? _mapRowToSourceHealthSnapshot(
    StoredSourceHealthSnapshot row,
  ) {
    final raw = row.payloadJson.trim();
    if (raw.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      return SourceHealthSnapshot.fromJson(decoded);
    } catch (_) {
      return null;
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

  String _normalizeImportFingerprintText(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), '').toLowerCase();
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
}

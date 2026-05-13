import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/cache/cover_image_disk_cache.dart';
import '../../../core/storage/managed_asset_store.dart';
import '../../../domain/entities/book_identity.dart';
import '../../../domain/entities/book_metadata_override.dart';
import '../../../domain/entities/local_book.dart';
import '../../../domain/entities/managed_asset.dart';
import '../../../domain/repositories/book_metadata_override_repository.dart';
import '../../../domain/repositories/local_book_repository.dart';
import '../../bookshelf/application/bookshelf_service.dart';
import '../../book/application/book_metadata_presentation_resolver.dart';
import '../../reader/application/chapter_cache_service.dart';
import '../../reader/application/local/local_book_storage_service.dart';
import '../../reader/application/reader_pagination_cache_service.dart';
import '../../reader/application/reading_record_service.dart';
import '../../../data/datasources/local/app_database.dart';
import '../../source/application/source_login_state_service.dart';

class StorageManagementSnapshot {
  const StorageManagementSnapshot({
    required this.cachedBookCount,
    required this.cachedChapterCount,
    required this.chapterCachesBytes,
    required this.paginationLayoutCount,
    required this.paginationLayoutsBytes,
    required this.coverCacheCount,
    required this.coverCachesBytes,
    required this.searchSourceHitCount,
    required this.searchSourceHitsBytes,
    required this.legacyResidualCount,
    required this.legacyResidualBytes,
    required this.themeAssetBytes,
    required this.localImportedBookCount,
    required this.localImportedBookBytes,
    required this.otherDataBytes,
  });

  final int cachedBookCount;
  final int cachedChapterCount;
  final int chapterCachesBytes;
  final int paginationLayoutCount;
  final int paginationLayoutsBytes;
  final int coverCacheCount;
  final int coverCachesBytes;
  final int searchSourceHitCount;
  final int searchSourceHitsBytes;
  final int legacyResidualCount;
  final int legacyResidualBytes;
  final int themeAssetBytes;
  final int localImportedBookCount;
  final int localImportedBookBytes;
  final int otherDataBytes;
}

class StorageDetailEntry {
  const StorageDetailEntry({
    required this.title,
    required this.bytes,
    this.subtitle,
    this.trailingLabel,
  });

  final String title;
  final int bytes;
  final String? subtitle;
  final String? trailingLabel;
}

class CachedBookPresentation {
  const CachedBookPresentation({
    this.bookId,
    this.sourceId,
    this.detailUrl,
    this.title,
    this.author,
    this.coverUrl,
    required this.inBookshelf,
  });

  final String? bookId;
  final String? sourceId;
  final String? detailUrl;
  final String? title;
  final String? author;
  final String? coverUrl;
  final bool inBookshelf;
}

class CachedBookSummary {
  const CachedBookSummary({
    required this.bookId,
    required this.cachedCount,
    required this.estimatedBytes,
    required this.updatedAt,
  });

  final String bookId;
  final int cachedCount;
  final int estimatedBytes;
  final DateTime updatedAt;
}

enum ThemeDataBucket {
  appBackground,
  readerBackground,
  coverGallery,
  launchImageGallery,
  bottomNavIcon,
  readerFont,
}

enum StorageSnapshotBucket {
  chapterCaches,
  paginationCaches,
  coverCaches,
  searchSourceHits,
  legacyResidual,
  themeAssets,
  localImportedBooks,
  otherAppData,
}

const Set<StorageSnapshotBucket> allStorageSnapshotBuckets =
    <StorageSnapshotBucket>{
      StorageSnapshotBucket.chapterCaches,
      StorageSnapshotBucket.paginationCaches,
      StorageSnapshotBucket.coverCaches,
      StorageSnapshotBucket.searchSourceHits,
      StorageSnapshotBucket.legacyResidual,
      StorageSnapshotBucket.themeAssets,
      StorageSnapshotBucket.localImportedBooks,
      StorageSnapshotBucket.otherAppData,
    };

class CacheManagementService {
  CacheManagementService({
    AppDatabase? database,
    BookshelfService? bookshelfService,
    ReadingRecordService? readingRecordService,
    LocalBookRepository? localBookRepository,
    LocalBookStorageService? localBookStorageService,
    BookMetadataOverrideRepository? bookMetadataOverrideRepository,
    ChapterCacheService? chapterCacheService,
    ReaderPaginationCacheService? paginationCacheService,
    SourceLoginStateService? sourceLoginStateService,
    ManagedAssetStore? assetStore,
    BookDisplayStateResolver resolver = const BookDisplayStateResolver(),
    CoverImageDiskCache? coverImageDiskCache,
  }) : _database = database ?? AppDatabase.instance,
       _bookshelfService = bookshelfService ?? BookshelfService(),
       _readingRecordService =
           readingRecordService ??
           ReadingRecordService(database: database ?? AppDatabase.instance),
       _localBookRepository = localBookRepository,
       _localBookStorageService =
           localBookStorageService ?? LocalBookStorageService(),
       _bookMetadataOverrideRepository = bookMetadataOverrideRepository,
       _chapterCacheService =
           chapterCacheService ??
           ChapterCacheService(database: database ?? AppDatabase.instance),
       _paginationCacheService =
           paginationCacheService ?? ReaderPaginationCacheService(),
       _sourceLoginStateService =
           sourceLoginStateService ?? SourceLoginStateService(),
       _assetStore = assetStore ?? ManagedAssetStore(),
       _resolver = resolver,
       _coverImageDiskCache =
           coverImageDiskCache ?? CoverImageDiskCache.instance;

  final AppDatabase _database;
  final BookshelfService _bookshelfService;
  final ReadingRecordService _readingRecordService;
  final LocalBookRepository? _localBookRepository;
  final LocalBookStorageService _localBookStorageService;
  final BookMetadataOverrideRepository? _bookMetadataOverrideRepository;
  final ChapterCacheService _chapterCacheService;
  final ReaderPaginationCacheService _paginationCacheService;
  final SourceLoginStateService _sourceLoginStateService;
  final ManagedAssetStore _assetStore;
  final BookDisplayStateResolver _resolver;
  final CoverImageDiskCache _coverImageDiskCache;

  Future<StorageManagementSnapshot> loadStorageSnapshot({
    Set<StorageSnapshotBucket>? buckets,
  }) async {
    final resolvedBuckets = buckets ?? allStorageSnapshotBuckets;
    final includeChapter = resolvedBuckets.contains(
      StorageSnapshotBucket.chapterCaches,
    );
    final includePagination = resolvedBuckets.contains(
      StorageSnapshotBucket.paginationCaches,
    );
    final includeCover = resolvedBuckets.contains(
      StorageSnapshotBucket.coverCaches,
    );
    final includeSearch = resolvedBuckets.contains(
      StorageSnapshotBucket.searchSourceHits,
    );
    final includeLegacy = resolvedBuckets.contains(
      StorageSnapshotBucket.legacyResidual,
    );
    final includeTheme = resolvedBuckets.contains(
      StorageSnapshotBucket.themeAssets,
    );
    final includeLocalBooks = resolvedBuckets.contains(
      StorageSnapshotBucket.localImportedBooks,
    );
    final includeOther = resolvedBuckets.contains(
      StorageSnapshotBucket.otherAppData,
    );

    final cachedBooks =
        includeChapter
            ? await _chapterCacheService.watchCachedBooks().first
            : null;
    final cachedChapterCount =
        cachedBooks?.fold<int>(0, (sum, item) => sum + item.cachedCount) ?? 0;
    final chapterCachesBytes =
        includeChapter ? await _database.estimateChapterCachesBytes() : 0;
    final paginationLayoutCount =
        includePagination
            ? await _paginationCacheService.countPersistedChapterLayouts()
            : 0;
    final paginationLayoutsBytes =
        includePagination
            ? await _directorySize(await _paginationCacheDirectory())
            : 0;
    final coverCacheCount =
        includeCover ? await _coverImageDiskCache.countAll() : 0;
    final coverCachesBytes =
        includeCover ? await _directorySize(await _coverCacheDirectory()) : 0;
    final searchSourceHitCount =
        includeSearch ? await _database.countSearchSourceHits() : 0;
    final searchSourceHitsBytes =
        includeSearch ? await _database.estimateSearchSourceHitsBytes() : 0;
    final legacyResidualTargets =
        includeLegacy
            ? await _resolveLegacyResidualTargets()
            : const <FileSystemEntity>[];
    final legacyResidualBytes =
        includeLegacy ? await _entitiesSize(legacyResidualTargets) : 0;
    final themeAssetBytes =
        includeTheme ? await _calculateThemeAssetBytes() : 0;
    final localImportedBookCount =
        includeLocalBooks
            ? await (_localBookRepository?.getAllBooks().then(
                  (items) => items.length,
                ) ??
                Future<int>.value(0))
            : 0;
    final localImportedBookBytes =
        includeLocalBooks
            ? await _directorySize(
              await _localBookStorageService.resolveStorageDirectory(),
            )
            : 0;
    final otherDataBytes = includeOther ? await _calculateOtherDataBytes() : 0;

    return StorageManagementSnapshot(
      cachedBookCount: cachedBooks?.length ?? 0,
      cachedChapterCount: cachedChapterCount,
      chapterCachesBytes: chapterCachesBytes,
      paginationLayoutCount: paginationLayoutCount,
      paginationLayoutsBytes: paginationLayoutsBytes,
      coverCacheCount: coverCacheCount,
      coverCachesBytes: coverCachesBytes,
      searchSourceHitCount: searchSourceHitCount,
      searchSourceHitsBytes: searchSourceHitsBytes,
      legacyResidualCount: legacyResidualTargets.length,
      legacyResidualBytes: legacyResidualBytes,
      themeAssetBytes: themeAssetBytes,
      localImportedBookCount: localImportedBookCount,
      localImportedBookBytes: localImportedBookBytes,
      otherDataBytes: otherDataBytes,
    );
  }

  Future<Map<String, CachedBookPresentation>>
  buildBookPresentationIndex() async {
    final items = await _bookshelfService.getAll();
    final records = await _readingRecordService.listLatestRecords();
    final localBooks =
        await (_localBookRepository?.getAllBooks() ??
            Future<List<LocalBook>>.value(const <LocalBook>[]));
    final metadataOverrides =
        await (_bookMetadataOverrideRepository?.getAll() ??
            Future<List<BookMetadataOverride>>.value(
              const <BookMetadataOverride>[],
            ));
    final localBooksById = <String, LocalBook>{
      for (final book in localBooks) book.id.trim(): book,
    };
    final metadataOverridesByTargetKey = <String, BookMetadataOverride>{
      for (final item in metadataOverrides) item.targetKey: item,
    };
    final result = <String, CachedBookPresentation>{};

    for (final record in records) {
      final bookId = record.bookId.trim();
      if (bookId.isEmpty) {
        continue;
      }
      final presentation = _resolver.resolveReadingRecord(
        record: record,
        localBook:
            isLocalBookSourceId(record.sourceId)
                ? localBooksById[bookId]
                : null,
        metadataOverride:
            metadataOverridesByTargetKey[(isLocalBookSourceId(record.sourceId))
                ? BookMetadataOverride.localTargetKey(bookId)
                : BookMetadataOverride.remoteTargetKey(
                  sourceId: record.sourceId,
                  detailUrl: record.detailUrl,
                )],
      );
      result[bookId] = CachedBookPresentation(
        bookId: record.bookId,
        sourceId: record.sourceId,
        detailUrl: record.detailUrl,
        title:
            presentation.displayTitle.trim().isEmpty
                ? null
                : presentation.displayTitle.trim(),
        author: presentation.displayAuthor?.trim(),
        coverUrl: presentation.displayCover?.trim(),
        inBookshelf: false,
      );
    }

    for (final item in items) {
      final bookId = item.bookId.trim();
      if (bookId.isEmpty) {
        continue;
      }
      final presentation = _resolver.resolveBookshelfBook(
        book: item,
        localBook:
            isLocalBookSourceId(item.sourceId) ? localBooksById[bookId] : null,
        metadataOverride:
            metadataOverridesByTargetKey[(isLocalBookSourceId(item.sourceId))
                ? BookMetadataOverride.localTargetKey(bookId)
                : BookMetadataOverride.remoteTargetKey(
                  sourceId: item.sourceId,
                  detailUrl: item.detailUrl,
                )],
      );
      result[bookId] = CachedBookPresentation(
        bookId: item.bookId,
        sourceId: item.sourceId,
        detailUrl: item.detailUrl,
        title:
            presentation.displayTitle.trim().isEmpty
                ? result[bookId]?.title
                : presentation.displayTitle.trim(),
        author: presentation.displayAuthor?.trim() ?? result[bookId]?.author,
        coverUrl: presentation.displayCover?.trim() ?? result[bookId]?.coverUrl,
        inBookshelf: true,
      );
    }

    return result;
  }

  Stream<List<CachedBookSummary>> watchCachedBooks() {
    return _chapterCacheService.watchCachedBooks().map(
      (items) => items
          .map(
            (item) => CachedBookSummary(
              bookId: item.bookId,
              cachedCount: item.cachedCount,
              estimatedBytes: item.estimatedBytes,
              updatedAt: item.updatedAt,
            ),
          )
          .toList(growable: false),
    );
  }

  Future<int> clearAllCaches() async {
    await _chapterCacheService.clearAllCaches();
    return _coverImageDiskCache.clearAll();
  }

  Future<int> clearChapterCachesOnly() async {
    final count = await _database.countChapterCaches();
    await _chapterCacheService.clearAllCaches();
    return count;
  }

  Future<int> clearPaginationCachesOnly() {
    return _paginationCacheService.clearPersistedChapterLayouts();
  }

  Future<int> clearCoverCachesOnly() {
    return _coverImageDiskCache.clearAll();
  }

  Future<int> clearSearchSourceHitsOnly() async {
    final count = await _database.countSearchSourceHits();
    await _database.clearSearchSourceHits();
    return count;
  }

  Future<int> clearLocalImportedBooksOnly() async {
    final localBookRepository = _localBookRepository;
    if (localBookRepository == null) {
      return 0;
    }

    final localBooks = await localBookRepository.getAllBooks();
    var deletedCount = 0;
    for (final localBook in localBooks) {
      await _localBookStorageService.deleteStoredBookArtifacts(localBook);
      await localBookRepository.deleteBook(localBook.id);
      await _sourceLoginStateService.removeBookCustomStatesForBook(
        localBook.id,
      );
      await _bookshelfService.remove(
        sourceId: BookIdentityScheme.localSourceId,
        detailUrl: buildLocalBookDetailUrl(localBook.id),
      );
      deletedCount += 1;
    }
    return deletedCount;
  }

  Future<int> clearLegacyResidualOnly() async {
    final targets = await _resolveLegacyResidualTargets();
    var deletedCount = 0;
    for (final entity in targets) {
      try {
        if (await entity.exists()) {
          await entity.delete(recursive: true);
          deletedCount++;
        }
      } catch (_) {
        // Ignore single-entity cleanup failure and continue.
      }
    }
    return deletedCount;
  }

  Future<int> clearOtherAppDataOnly() async {
    final targets = await _resolveOtherDataTargets();
    var deletedCount = 0;
    for (final entity in targets) {
      try {
        if (await entity.exists()) {
          await entity.delete(recursive: true);
          deletedCount++;
        }
      } catch (_) {
        // Ignore single-entity cleanup failure and continue.
      }
    }
    return deletedCount;
  }

  Future<List<StorageDetailEntry>> loadLegacyResidualDetails() async {
    final targets = await _resolveLegacyResidualTargets();
    return _mapEntitiesToDetailEntries(targets);
  }

  Future<List<StorageDetailEntry>> loadOtherDataDetails() async {
    final targets = await _resolveOtherDataTargets();
    return _mapEntitiesToDetailEntries(targets);
  }

  Future<List<StorageDetailEntry>> loadThemeAssetDetails() async {
    final entries = <StorageDetailEntry>[
      await _buildDirectoryDetailEntry(
        title: '应用背景',
        directory: await _themeDirectory(ThemeDataBucket.appBackground),
      ),
      await _buildDirectoryDetailEntry(
        title: '阅读背景',
        directory: await _themeDirectory(ThemeDataBucket.readerBackground),
      ),
      await _buildDirectoryDetailEntry(
        title: '封面图集',
        directory: await _themeDirectory(ThemeDataBucket.coverGallery),
      ),
      await _buildDirectoryDetailEntry(
        title: '启动图集',
        directory: await _themeDirectory(ThemeDataBucket.launchImageGallery),
      ),
      await _buildDirectoryDetailEntry(
        title: '底栏图标',
        directory: await _themeDirectory(ThemeDataBucket.bottomNavIcon),
      ),
      await _buildDirectoryDetailEntry(
        title: '字体资源',
        directory: await _themeDirectory(ThemeDataBucket.readerFont),
      ),
    ];
    return entries;
  }

  Future<bool> clearBookCache({
    required String bookId,
    String? coverUrl,
  }) async {
    await _chapterCacheService.clearBookCache(bookId);
    return _coverImageDiskCache.clearByUrl(coverUrl ?? '');
  }

  Future<Directory> _coverCacheDirectory() async {
    final baseDir = await getApplicationSupportDirectory();
    return Directory(p.join(baseDir.path, 'shuxiang_reading_next', 'covers'));
  }

  Future<Directory> _paginationCacheDirectory() async {
    final baseDir = await getApplicationSupportDirectory();
    return Directory(p.join(baseDir.path, 'reader_pagination_cache'));
  }

  Future<int> _directorySize(Directory directory) async {
    if (!await directory.exists()) {
      return 0;
    }
    var total = 0;
    await for (final entity in directory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is File) {
        try {
          total += await entity.length();
        } catch (_) {
          // Ignore single-file stat failure.
        }
      }
    }
    return total;
  }

  Future<int> _fileSize(File file) async {
    try {
      if (!await file.exists()) {
        return 0;
      }
      return await file.length();
    } catch (_) {
      return 0;
    }
  }

  Future<int> _calculateOtherDataBytes() async {
    final targets = await _resolveOtherDataTargets();
    return _entitiesSize(targets);
  }

  Future<int> _calculateThemeAssetBytes() async {
    final details = await loadThemeAssetDetails();
    return details.fold<int>(0, (sum, item) => sum + item.bytes);
  }

  Future<int> _entitiesSize(List<FileSystemEntity> targets) async {
    var total = 0;
    for (final entity in targets) {
      if (entity is File) {
        total += await _fileSize(entity);
        continue;
      }
      if (entity is Directory) {
        total += await _directorySize(entity);
      }
    }
    return total;
  }

  Future<List<FileSystemEntity>> _resolveOtherDataTargets() async {
    final supportDir = await getApplicationSupportDirectory();
    final documentsDir = await getApplicationDocumentsDirectory();
    final appDatabaseDir = Directory(
      p.join(supportDir.path, 'shuxiang_reading_next'),
    );

    final supportWhitelist = <String>{
      'reader_pagination_cache',
      'novel_sources',
      'bottom_nav_icon_galleries',
      'reader_fonts',
      'local_books',
      'shuxiang_reading_next',
    };
    final documentsWhitelist = <String>{
      'backgrounds',
      'reader_backgrounds',
      'cover_galleries',
      'launch_image_galleries',
    };
    final appDatabaseDirWhitelist = <String>{
      'shuxiang_reading_next.db',
      'covers',
      'custom_covers',
    };

    final targets = <FileSystemEntity>[];
    await _collectUnknownChildren(
      root: supportDir,
      whitelist: supportWhitelist,
      targets: targets,
    );
    await _collectUnknownChildren(
      root: documentsDir,
      whitelist: documentsWhitelist,
      targets: targets,
    );
    await _collectUnknownChildren(
      root: appDatabaseDir,
      whitelist: appDatabaseDirWhitelist,
      targets: targets,
    );
    return targets;
  }

  Future<void> _collectUnknownChildren({
    required Directory root,
    required Set<String> whitelist,
    required List<FileSystemEntity> targets,
  }) async {
    if (!await root.exists()) {
      return;
    }
    await for (final entity in root.list(followLinks: false)) {
      final name = p.basename(entity.path);
      if (!whitelist.contains(name)) {
        targets.add(entity);
      }
    }
  }

  Future<Directory> _themeDirectory(ThemeDataBucket bucket) {
    return switch (bucket) {
      ThemeDataBucket.appBackground => _assetRootDirectory(
        ManagedAssetType.appBackground,
      ),
      ThemeDataBucket.readerBackground => _assetRootDirectory(
        ManagedAssetType.readerBackground,
      ),
      ThemeDataBucket.coverGallery => _assetRootDirectory(
        ManagedAssetType.coverGalleryImage,
      ),
      ThemeDataBucket.launchImageGallery => _assetRootDirectory(
        ManagedAssetType.launchImageGalleryImage,
      ),
      ThemeDataBucket.bottomNavIcon => _assetRootDirectory(
        ManagedAssetType.bottomNavIcon,
      ),
      ThemeDataBucket.readerFont => _assetRootDirectory(
        ManagedAssetType.readerFont,
      ),
    };
  }

  Future<Directory> _assetRootDirectory(ManagedAssetType type) async {
    return _assetStore.resolveDirectory(type);
  }

  Future<StorageDetailEntry> _buildDirectoryDetailEntry({
    required String title,
    required Directory directory,
  }) async {
    final fileCount = await _countFiles(directory);
    final size = await _directorySize(directory);
    return StorageDetailEntry(
      title: title,
      bytes: size,
      trailingLabel: '$fileCount 条',
      subtitle: directory.path,
    );
  }

  Future<int> _countFiles(Directory directory) async {
    if (!await directory.exists()) {
      return 0;
    }
    var total = 0;
    await for (final entity in directory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is File) {
        total++;
      }
    }
    return total;
  }

  Future<List<StorageDetailEntry>> _mapEntitiesToDetailEntries(
    List<FileSystemEntity> targets,
  ) async {
    final entries = <StorageDetailEntry>[];
    for (final entity in targets) {
      final title = p.basename(entity.path);
      final bytes =
          entity is File
              ? await _fileSize(entity)
              : await _directorySize(entity as Directory);
      entries.add(
        StorageDetailEntry(
          title: title.isEmpty ? entity.path : title,
          subtitle: entity.path,
          bytes: bytes,
          trailingLabel: entity is Directory ? '目录' : '文件',
        ),
      );
    }
    entries.sort((a, b) => b.bytes.compareTo(a.bytes));
    return entries;
  }

  Future<List<FileSystemEntity>> _resolveLegacyResidualTargets() async {
    final targets = <String, FileSystemEntity>{};
    await _collectOrphanLocalBookArtifacts(targets);
    return targets.values.toList(growable: false);
  }

  Future<void> _collectOrphanLocalBookArtifacts(
    Map<String, FileSystemEntity> targets,
  ) async {
    final localBookRepository = _localBookRepository;
    if (localBookRepository == null) {
      return;
    }
    final root = await _localBookStorageService.resolveStorageDirectory();
    if (!await root.exists()) {
      return;
    }
    final localBooks = await localBookRepository.getAllBooks();
    final referencedPaths = <String>{};
    for (final book in localBooks) {
      final storageFile = await _localBookStorageService.resolveStorageFile(
        book,
      );
      referencedPaths.add(storageFile.path);
      if (book.requiresManagedAssetDirectory) {
        final assetDir = await _localBookStorageService.resolveAssetDirectory(
          book,
        );
        referencedPaths.add(assetDir.path);
      }
    }
    await for (final entity in root.list(followLinks: false)) {
      if (!referencedPaths.contains(entity.path)) {
        targets.putIfAbsent(entity.path, () => entity);
      }
    }
  }
}

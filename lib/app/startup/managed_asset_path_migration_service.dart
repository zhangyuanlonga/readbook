import 'package:shared_preferences/shared_preferences.dart';

import '../../app/navigation/bottom_nav_icon_gallery_service.dart';
import '../../core/logging/app_logger.dart';
import '../../core/storage/managed_file_path_resolver.dart';
import '../../data/datasources/local/app_database.dart';
import '../../domain/entities/book_metadata_override.dart';
import '../../features/mine/application/advanced_theme_service.dart';
import '../../features/mine/application/cover_gallery_service.dart';
import '../../features/mine/application/launch_image_gallery_service.dart';
import '../../features/reader/application/reader_font_registry_service.dart';

class ManagedAssetPathMigrationService {
  ManagedAssetPathMigrationService({
    SharedPreferences? preferences,
    AppDatabase? database,
    AppLogger? logger,
    ManagedFilePathResolver? pathResolver,
  }) : _preferences = preferences,
       _database = database ?? AppDatabase.instance,
       _logger = logger ?? AppLogger.instance,
       _pathResolver = pathResolver ?? ManagedFilePathResolver();

  final SharedPreferences? _preferences;
  final AppDatabase _database;
  final AppLogger _logger;
  final ManagedFilePathResolver _pathResolver;

  Future<void> migrate() async {
    await _runSafely('advanced themes', () async {
      await AdvancedThemeService(preferences: _preferences).loadThemes();
    });
    await _runSafely('cover galleries', () async {
      await CoverGalleryService(preferences: _preferences).loadGalleries();
    });
    await _runSafely('launch image galleries', () async {
      await LaunchImageGalleryService(
        preferences: _preferences,
      ).loadGalleries();
    });
    await _runSafely('bottom nav galleries', () async {
      await BottomNavIconGalleryService(
        preferences: _preferences,
      ).loadGalleries();
    });
    await _runSafely('font registry', () async {
      await ReaderFontRegistryService().listRegisteredFonts();
    });
    await _runSafely('book cover paths', _migrateBookCoverPaths);
  }

  Future<void> _migrateBookCoverPaths() async {
    final localBooks = await _database.getAllLocalBooks();
    var localBookChanges = 0;
    for (final book in localBooks) {
      final normalizedCoverPath = await _pathResolver
          .normalizePersistedFilePath(book.coverPath);
      if (normalizedCoverPath == book.coverPath) {
        continue;
      }
      await _database.upsertLocalBook(
        book.copyWith(coverPath: normalizedCoverPath),
      );
      localBookChanges += 1;
    }

    final overrides = await _database.getAllBookMetadataOverrides();
    var overrideChanges = 0;
    for (final override in overrides) {
      final normalizedCoverPath = await _pathResolver
          .normalizePersistedFilePath(override.coverPath);
      if (normalizedCoverPath == override.coverPath) {
        continue;
      }
      await _database.upsertBookMetadataOverride(
        _copyMetadataOverrideWithCoverPath(override, normalizedCoverPath),
      );
      overrideChanges += 1;
    }

    if (localBookChanges > 0 || overrideChanges > 0) {
      _logger.info(
        'Managed asset paths migrated',
        context: <String, Object?>{
          'localBookChanges': localBookChanges,
          'metadataOverrideChanges': overrideChanges,
        },
      );
    }
  }

  BookMetadataOverride _copyMetadataOverrideWithCoverPath(
    BookMetadataOverride override,
    String? coverPath,
  ) {
    return BookMetadataOverride(
      targetKey: override.targetKey,
      bookId: override.bookId,
      sourceId: override.sourceId,
      detailUrl: override.detailUrl,
      title: override.title,
      author: override.author,
      intro: override.intro,
      coverPath: coverPath,
      createdAt: override.createdAt,
      updatedAt: override.updatedAt,
    );
  }

  Future<void> _runSafely(
    String label,
    Future<void> Function() operation,
  ) async {
    try {
      await operation();
    } catch (error, stackTrace) {
      _logger.warn(
        'Managed asset migration step failed',
        context: <String, Object?>{
          'step': label,
          'error': error.toString(),
          'stackTrace': stackTrace.toString(),
        },
      );
    }
  }
}

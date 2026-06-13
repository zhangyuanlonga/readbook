import '../../../core/cache/app_cache_governance_service.dart';
import '../../../core/cache/cache_result.dart';
import '../../../core/cache/cache_scope.dart';
import '../../../core/cache/cache_store.dart';
import '../../../core/storage/directory_metrics.dart';
import '../../../core/storage/local_file_stat.dart';
import '../../../core/storage/managed_asset_directory_policy.dart';
import '../../../core/storage/managed_asset_store.dart';
import '../../../data/datasources/local/app_database.dart';
import '../../../data/datasources/local/app_database_connection.dart';
import '../../../domain/entities/managed_asset.dart';
import '../../reader/application/local/local_book_index_cache_store.dart';
import '../../reader/application/local/local_book_storage_service.dart';
import '../../reader/application/reader_pagination_cache_service.dart';
import '../../reader/application/reader_preference_cache_store.dart';
import '../presentation/advanced_theme_preview_image_cache.dart';

class StorageFootprint {
  const StorageFootprint({
    required this.label,
    required this.bytes,
    required this.fileCount,
  });

  final String label;
  final int bytes;
  final int fileCount;
}

class StorageManagementSnapshot {
  const StorageManagementSnapshot({
    required this.database,
    required this.localBooks,
    required this.userAssets,
    required this.cacheSnapshot,
    required this.totalManagedAssetBytes,
  });

  final StorageFootprint database;
  final StorageFootprint localBooks;
  final StorageFootprint userAssets;
  final AppCacheGovernanceSnapshot cacheSnapshot;
  final int totalManagedAssetBytes;
}

abstract interface class StorageManagementGateway {
  Future<StorageManagementSnapshot> loadSnapshot();

  Future<void> clearRebuildableCaches();

  Future<AppCacheDeleteResult> clearCacheScope(AppCacheScope scope);

  Future<AppDatabaseMaintenanceReport> clearOrphanedDatabaseData();
}

class StorageManagementService implements StorageManagementGateway {
  StorageManagementService({
    AppDatabase? database,
    AppCacheGovernanceService? cacheGovernanceService,
    ManagedAssetStore? managedAssetStore,
    LocalBookStorageService? localBookStorageService,
  }) : _database = database ?? AppDatabase.instance,
       _cacheGovernanceService =
           cacheGovernanceService ??
           AppCacheGovernanceService(
             paginationCacheStore: ReaderPaginationCacheService(),
             extraStores: <AppCacheStore>[
               AdvancedThemePreviewCacheStore(),
               LocalBookIndexCacheStore(database: database),
               ReaderPreferenceCacheStore(),
             ],
           ),
       _managedAssetStore = managedAssetStore ?? ManagedAssetStore(),
       _localBookStorageService =
           localBookStorageService ?? LocalBookStorageService();

  final AppDatabase _database;
  final AppCacheGovernanceService _cacheGovernanceService;
  final ManagedAssetStore _managedAssetStore;
  final LocalBookStorageService _localBookStorageService;

  @override
  Future<StorageManagementSnapshot> loadSnapshot() async {
    final cacheSnapshot = await _cacheGovernanceService.loadSnapshot();
    final databasePath = await resolveAppDatabaseFilePath();
    final databaseStat = await statLocalFile(databasePath);
    final localBooksDir =
        await _localBookStorageService.resolveStorageDirectory();
    final localBooksMetrics = await inspectDirectoryPath(localBooksDir.path);

    var userAssetBytes = 0;
    var userAssetFiles = 0;
    for (final policy in ManagedAssetDirectoryPolicies.all) {
      if (policy.type == ManagedAssetType.localBookArtifact) {
        continue;
      }
      final directory = await _managedAssetStore.resolveDirectory(policy.type);
      final metrics = await inspectDirectoryPath(directory.path);
      userAssetBytes += metrics.totalBytes;
      userAssetFiles += metrics.fileCount;
    }

    return StorageManagementSnapshot(
      database: StorageFootprint(
        label: '数据库',
        bytes: databaseStat?.size ?? 0,
        fileCount: databaseStat == null ? 0 : 1,
      ),
      localBooks: StorageFootprint(
        label: '本地图书',
        bytes: localBooksMetrics.totalBytes,
        fileCount: localBooksMetrics.fileCount,
      ),
      userAssets: StorageFootprint(
        label: '用户资源',
        bytes: userAssetBytes,
        fileCount: userAssetFiles,
      ),
      cacheSnapshot: cacheSnapshot,
      totalManagedAssetBytes: localBooksMetrics.totalBytes + userAssetBytes,
    );
  }

  @override
  Future<void> clearRebuildableCaches() {
    return _cacheGovernanceService.clearRebuildableCaches();
  }

  @override
  Future<AppCacheDeleteResult> clearCacheScope(AppCacheScope scope) {
    return _cacheGovernanceService.clearScope(scope);
  }

  @override
  Future<AppDatabaseMaintenanceReport> clearOrphanedDatabaseData() {
    return _database.runStorageMaintenance();
  }
}

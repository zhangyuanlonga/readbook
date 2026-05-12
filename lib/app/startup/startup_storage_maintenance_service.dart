import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/cache/cache_budget_policy.dart';
import '../../core/cache/cover_image_disk_cache.dart';
import '../../core/logging/app_logger.dart';
import '../../data/datasources/local/app_database.dart';
import '../../features/mine/application/cache_management_service.dart';
import '../../features/reader/application/reader_pagination_cache_service.dart';

class StartupStorageMaintenanceService {
  StartupStorageMaintenanceService({
    SharedPreferences? preferences,
    AppDatabase? database,
    ReaderPaginationCacheService? paginationCacheService,
    CoverImageDiskCache? coverImageDiskCache,
    AppLogger? logger,
  }) : _preferencesFuture =
           preferences == null
               ? SharedPreferences.getInstance()
               : Future.value(preferences),
       _database = database ?? AppDatabase.instance,
       _paginationCacheService =
           paginationCacheService ?? ReaderPaginationCacheService(),
       _coverImageDiskCache =
           coverImageDiskCache ?? CoverImageDiskCache.instance,
       _logger = logger ?? AppLogger.instance;

  static const String _lastRunVersionKey =
      'startup.storageMaintenance.lastRunVersion';
  static const String _lastRunAtKey = 'startup.storageMaintenance.lastRunAt';
  static const Duration _repeatInterval = Duration(days: 7);
  final Future<SharedPreferences> _preferencesFuture;
  final AppDatabase _database;
  final ReaderPaginationCacheService _paginationCacheService;
  final CoverImageDiskCache _coverImageDiskCache;
  final AppLogger _logger;

  Future<void> runIfNeeded() async {
    final prefs = await _preferencesFuture;
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersionKey =
        '${packageInfo.version.trim()}+${packageInfo.buildNumber.trim()}';
    final lastRunVersion = prefs.getString(_lastRunVersionKey)?.trim() ?? '';
    final lastRunAtMs = prefs.getInt(_lastRunAtKey);
    final lastRunAt =
        lastRunAtMs == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(lastRunAtMs);
    final now = DateTime.now();
    final shouldRun =
        lastRunVersion != currentVersionKey ||
        lastRunAt == null ||
        now.difference(lastRunAt) >= _repeatInterval;
    if (!shouldRun) {
      return;
    }

    final deletedChapterCaches = await _database.pruneChapterCachesByBudget(
      maxEntries: AppCacheBudgetPolicies.chapterCaches.maxEntries,
      maxBytes: AppCacheBudgetPolicies.chapterCaches.maxBytes,
      stalePeriod: AppCacheBudgetPolicies.chapterCaches.stalePeriod,
    );
    final deletedPaginationCaches = await _paginationCacheService
        .prunePersistedChapterLayoutsByBudget(
          maxEntries: AppCacheBudgetPolicies.paginationLayouts.maxEntries,
          maxBytes: AppCacheBudgetPolicies.paginationLayouts.maxBytes,
          stalePeriod: AppCacheBudgetPolicies.paginationLayouts.stalePeriod,
        );
    final deletedCoverCaches = await _coverImageDiskCache.compact(
      maxEntries: AppCacheBudgetPolicies.coverImages.maxEntries,
      maxBytes: AppCacheBudgetPolicies.coverImages.maxBytes,
      stalePeriod: AppCacheBudgetPolicies.coverImages.stalePeriod,
    );
    final deletedLegacyResidual =
        await CacheManagementService().clearLegacyResidualOnly();

    await prefs.setString(_lastRunVersionKey, currentVersionKey);
    await prefs.setInt(_lastRunAtKey, now.millisecondsSinceEpoch);

    _logger.info(
      'Startup storage maintenance complete',
      context: <String, Object?>{
        'version': currentVersionKey,
        'deletedChapterCaches': deletedChapterCaches,
        'deletedPaginationCaches': deletedPaginationCaches,
        'deletedCoverCaches': deletedCoverCaches,
        'deletedLegacyResidual': deletedLegacyResidual,
      },
    );
  }
}

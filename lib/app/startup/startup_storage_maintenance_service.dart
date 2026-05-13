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

    final chapterCountBefore = await _database.countChapterCaches();
    final chapterBytesBefore = await _database.estimateChapterCachesBytes();
    final paginationStatsBefore = await _paginationCacheService.loadStats();
    final coverCountBefore = await _coverImageDiskCache.countAll();
    final coverBytesBefore = await _coverImageDiskCache.estimateAllBytes();

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
    final chapterCountAfter = await _database.countChapterCaches();
    final chapterBytesAfter = await _database.estimateChapterCachesBytes();
    final paginationStatsAfter = await _paginationCacheService.loadStats();
    final coverCountAfter = await _coverImageDiskCache.countAll();
    final coverBytesAfter = await _coverImageDiskCache.estimateAllBytes();

    await prefs.setString(_lastRunVersionKey, currentVersionKey);
    await prefs.setInt(_lastRunAtKey, now.millisecondsSinceEpoch);

    _logger.info(
      'Startup storage maintenance complete',
      context: <String, Object?>{
        'version': currentVersionKey,
        'reason':
            lastRunVersion != currentVersionKey
                ? 'version_changed'
                : 'repeat_interval',
        'chapterCacheMaxEntries':
            AppCacheBudgetPolicies.chapterCaches.maxEntries,
        'chapterCacheMaxBytes': AppCacheBudgetPolicies.chapterCaches.maxBytes,
        'chapterCacheStaleDays':
            AppCacheBudgetPolicies.chapterCaches.stalePeriod.inDays,
        'chapterCacheCountBefore': chapterCountBefore,
        'chapterCacheCountAfter': chapterCountAfter,
        'chapterCacheBytesBefore': chapterBytesBefore,
        'chapterCacheBytesAfter': chapterBytesAfter,
        'deletedChapterCaches': deletedChapterCaches,
        'paginationCacheMaxEntries':
            AppCacheBudgetPolicies.paginationLayouts.maxEntries,
        'paginationCacheMaxBytes':
            AppCacheBudgetPolicies.paginationLayouts.maxBytes,
        'paginationCacheStaleDays':
            AppCacheBudgetPolicies.paginationLayouts.stalePeriod.inDays,
        'paginationCacheCountBefore': paginationStatsBefore.persistedEntries,
        'paginationCacheCountAfter': paginationStatsAfter.persistedEntries,
        'paginationCacheBytesBefore': paginationStatsBefore.persistedBytes,
        'paginationCacheBytesAfter': paginationStatsAfter.persistedBytes,
        'deletedPaginationCaches': deletedPaginationCaches,
        'coverCacheMaxEntries': AppCacheBudgetPolicies.coverImages.maxEntries,
        'coverCacheMaxBytes': AppCacheBudgetPolicies.coverImages.maxBytes,
        'coverCacheStaleDays':
            AppCacheBudgetPolicies.coverImages.stalePeriod.inDays,
        'coverCacheCountBefore': coverCountBefore,
        'coverCacheCountAfter': coverCountAfter,
        'coverCacheBytesBefore': coverBytesBefore,
        'coverCacheBytesAfter': coverBytesAfter,
        'deletedCoverCaches': deletedCoverCaches,
        'deletedLegacyResidual': deletedLegacyResidual,
      },
    );
  }
}

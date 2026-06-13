import 'package:shared_preferences/shared_preferences.dart';

import '../../core/cache/app_cache_governance_service.dart';
import '../../data/datasources/local/app_database.dart';
import '../../data/datasources/local/app_database_connection.dart';
import '../../domain/entities/managed_asset.dart';
import 'directory_metrics.dart';
import 'local_file_stat.dart';
import 'managed_asset_store.dart';

enum StorageHealthLevel { healthy, notice, warning, critical }

class StorageHealthReport {
  const StorageHealthReport({
    required this.level,
    required this.score,
    required this.sharedPreferencesEntryCount,
    required this.databaseBytes,
    required this.cacheBytes,
    required this.orphanCandidateCount,
    required this.warnings,
  });

  final StorageHealthLevel level;
  final int score;
  final int sharedPreferencesEntryCount;
  final int databaseBytes;
  final int cacheBytes;
  final int orphanCandidateCount;
  final List<String> warnings;
}

class StorageHealthService {
  StorageHealthService({
    SharedPreferences? preferences,
    AppDatabase? database,
    AppCacheGovernanceService? cacheGovernanceService,
    ManagedAssetStore? assetStore,
  }) : _preferencesFuture =
           preferences == null
               ? SharedPreferences.getInstance()
               : Future.value(preferences),
       _database = database ?? AppDatabase.instance,
       _cacheGovernanceService =
           cacheGovernanceService ?? AppCacheGovernanceService(),
       _assetStore = assetStore ?? ManagedAssetStore();

  static const int _databaseWarningBytes = 500 * 1024 * 1024;
  static const int _preferenceWarningCount = 100;

  final Future<SharedPreferences> _preferencesFuture;
  final AppDatabase _database;
  final AppCacheGovernanceService _cacheGovernanceService;
  final ManagedAssetStore _assetStore;

  Future<StorageHealthReport> buildReport() async {
    final prefs = await _preferencesFuture;
    final dbPath = await resolveAppDatabaseFilePath();
    final dbStat = await statLocalFile(dbPath);
    final dbBytes = dbStat?.size ?? 0;
    final cacheSnapshot = await _cacheGovernanceService.loadSnapshot();
    final cacheBytes = cacheSnapshot.totalBytes;
    final maintenance = await _database.inspectStorageMaintenance();
    final orphanCount = maintenance.totalDeleted;

    final warnings = <String>[];
    var score = 100;
    if (dbBytes > _databaseWarningBytes) {
      warnings.add('数据库体积超过 500MB');
      score -= 25;
    }
    if (prefs.getKeys().length > _preferenceWarningCount) {
      warnings.add('SharedPreferences 条目数超过 100');
      score -= 20;
    }
    if (orphanCount > 0) {
      warnings.add('检测到 $orphanCount 条孤立/过期数据库记录');
      score -= 20;
    }
    final overBudgetKinds =
        cacheSnapshot.entries.where((entry) => entry.overBudget).length;
    if (overBudgetKinds > 0) {
      warnings.add('$overBudgetKinds 类缓存超过预算');
      score -= 15;
    }
    final localBooksDir = await _assetStore.resolveDirectory(
      ManagedAssetType.localBookArtifact,
    );
    final localBooksStat = await inspectDirectoryPath(localBooksDir.path);
    if (localBooksStat.totalBytes <= 0 && dbBytes > _databaseWarningBytes) {
      warnings.add('数据库体积异常，且本地图书目录占用不匹配');
      score -= 10;
    }

    final clampedScore = score.clamp(0, 100);
    final level =
        clampedScore >= 90
            ? StorageHealthLevel.healthy
            : clampedScore >= 70
            ? StorageHealthLevel.notice
            : clampedScore >= 40
            ? StorageHealthLevel.warning
            : StorageHealthLevel.critical;

    return StorageHealthReport(
      level: level,
      score: clampedScore,
      sharedPreferencesEntryCount: prefs.getKeys().length,
      databaseBytes: dbBytes,
      cacheBytes: cacheBytes,
      orphanCandidateCount: orphanCount,
      warnings: List<String>.unmodifiable(warnings),
    );
  }
}

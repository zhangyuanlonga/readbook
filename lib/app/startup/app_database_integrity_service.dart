import '../../core/logging/app_logger.dart';
import '../../data/datasources/local/app_database.dart';
import '../../data/datasources/local/app_database_connection.dart';

class AppDatabaseIntegrityCheckResult {
  const AppDatabaseIntegrityCheckResult({
    required this.healthy,
    this.backupPath,
    this.message,
  });

  final bool healthy;
  final String? backupPath;
  final String? message;
}

class AppDatabaseIntegrityService {
  AppDatabaseIntegrityService({AppLogger? logger})
    : _logger = logger ?? AppLogger.instance;

  final AppLogger _logger;

  Future<AppDatabaseIntegrityCheckResult> ensureHealthy() async {
    try {
      await AppDatabase.resetSharedInstance();
      final database = AppDatabase();
      try {
        final rows = await database.customSelect('PRAGMA quick_check(1)').get();
        final result =
            rows.isEmpty
                ? 'ok'
                : (rows.first.data.values.first ?? '').toString();
        if (result.trim().toLowerCase() == 'ok') {
          return const AppDatabaseIntegrityCheckResult(healthy: true);
        }
        throw StateError('PRAGMA quick_check returned: $result');
      } finally {
        await database.close();
      }
    } catch (error, stackTrace) {
      final backupPath = await backupPersistedAppDatabase();
      final deleted = await deletePersistedAppDatabase();
      _logger.warn(
        'App database integrity check failed',
        context: <String, Object?>{
          'error': error.toString(),
          'stackTrace': stackTrace.toString(),
          'backupPath': backupPath,
          'deleted': deleted,
        },
      );
      return AppDatabaseIntegrityCheckResult(
        healthy: false,
        backupPath: backupPath,
        message: '数据库已损坏，已自动备份并重建。',
      );
    }
  }
}

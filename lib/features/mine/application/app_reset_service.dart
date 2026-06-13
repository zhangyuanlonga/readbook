import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/app_restart_scope.dart';
import '../../../app/bootstrap.dart';
import '../../../core/auth/auth_session_store.dart';
import '../../../core/cache/app_cache_governance_service.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/logging/source_log_store.dart';
import '../../../data/datasources/local/app_database.dart';
import '../../../data/datasources/local/app_database_connection.dart';
import '../../reader/application/reader_pagination_cache_service.dart';

class AppResetSummary {
  const AppResetSummary({
    required this.preferencesCleared,
    required this.databaseDeleted,
    required this.cachesCleared,
  });

  final bool preferencesCleared;
  final bool databaseDeleted;
  final bool cachesCleared;
}

class AppResetService {
  AppResetService({
    SharedPreferences? preferences,
    AuthSessionStore? authSessionStore,
    AppCacheGovernanceService? cacheGovernanceService,
    AppLogger? logger,
  }) : _preferencesFuture =
           preferences == null
               ? SharedPreferences.getInstance()
               : Future.value(preferences),
       _authSessionStore =
           authSessionStore ?? AuthSessionStore(preferences: preferences),
       _cacheGovernanceService =
           cacheGovernanceService ??
           AppCacheGovernanceService(
             paginationCacheStore: ReaderPaginationCacheService(),
           ),
       _logger = logger ?? AppLogger.instance;

  final Future<SharedPreferences> _preferencesFuture;
  final AuthSessionStore _authSessionStore;
  final AppCacheGovernanceService _cacheGovernanceService;
  final AppLogger _logger;

  Future<AppResetSummary> resetAppPreservingManagedAssets() async {
    final prefs = await _preferencesFuture;
    await _authSessionStore.clear();
    SourceLogStore.instance.clear();
    await _cacheGovernanceService.clearRebuildableCaches();
    await AppDatabase.resetSharedInstance();
    final databaseDeleted = await deletePersistedAppDatabase();
    await prefs.clear();
    primeBootstrappedPreferences(prefs);
    _logger.info(
      'Application reset completed',
      context: <String, Object?>{
        'databaseDeleted': databaseDeleted,
        'preservedManagedAssets': true,
      },
    );
    return AppResetSummary(
      preferencesCleared: true,
      databaseDeleted: databaseDeleted,
      cachesCleared: true,
    );
  }

  Future<void> resetAndRestart() async {
    await resetAppPreservingManagedAssets();
    await AppRestartScope.restartApp();
  }
}

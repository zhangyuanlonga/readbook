import '../../core/cache/cache_store.dart';
import '../../data/datasources/local/app_database.dart';
import '../../features/search/application/search_hit_cache_service.dart';
import '../../features/source/application/source_health_persistence_service.dart';

List<AppCacheStore> buildDefaultFeatureCacheStores({AppDatabase? database}) {
  return <AppCacheStore>[
    SearchHitCacheService(database: database),
    SourceHealthPersistenceService(database: database),
  ];
}

import '../../../core/cache/cache_entry.dart';
import '../../../core/cache/cache_key.dart';
import '../../../core/cache/cache_policy.dart';
import '../../../core/cache/cache_result.dart';
import '../../../core/cache/cache_scope.dart';
import '../../../core/cache/cache_store.dart';
import 'reader_font_registry_service.dart';
import 'reader_visual_overrides_service.dart';

class ReaderPreferenceCacheStore implements AppCacheStore {
  ReaderPreferenceCacheStore({
    ReaderFontRegistryService? fontRegistryService,
    ReaderVisualOverridesService? visualOverridesService,
  }) : _fontRegistryService =
           fontRegistryService ?? ReaderFontRegistryService(),
       _visualOverridesService =
           visualOverridesService ?? ReaderVisualOverridesService();

  final ReaderFontRegistryService _fontRegistryService;
  final ReaderVisualOverridesService _visualOverridesService;

  @override
  AppCacheScope get scope => AppCacheScope.readerPreference;

  @override
  String get backendName =>
      'shared_preferences.reader_visual_overrides+managed_assets.reader_fonts';

  @override
  Future<AppCacheReadResult> read(
    AppCacheKey key, {
    AppCachePolicy? policy,
  }) async {
    return AppCacheReadResult.miss(key: key, backend: backendName);
  }

  @override
  Future<AppCacheWriteResult> write(
    AppCacheEntry entry, {
    AppCachePolicy? policy,
  }) async {
    return AppCacheWriteResult.skipped(key: entry.key, backend: backendName);
  }

  @override
  Future<AppCacheDeleteResult> delete(AppCacheKey key) async {
    return AppCacheDeleteResult.skipped(
      scope: scope,
      backend: backendName,
      key: key,
    );
  }

  @override
  Future<AppCacheDeleteResult> clearScope({String? owner}) async {
    return AppCacheDeleteResult.skipped(scope: scope, backend: backendName);
  }

  @override
  Future<AppCacheStats> stats({String? owner}) async {
    final fontStats = await _fontRegistryService.loadRegistryStats();
    final visualStats = await _visualOverridesService.loadStorageStats();
    return AppCacheStats(
      scope: scope,
      backend:
          '$backendName; fontRegistryV${fontStats.version}; visualOverridesV${visualStats.version}',
      entries: fontStats.entries + visualStats.entries,
      bytes: fontStats.bytes + visualStats.bytes,
    );
  }

  @override
  Future<AppCachePruneResult> prune(AppCachePolicy policy) async {
    return AppCachePruneResult(scope: scope, backend: backendName);
  }
}

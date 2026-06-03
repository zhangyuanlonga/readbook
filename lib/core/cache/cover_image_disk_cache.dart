import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class CoverImageDiskCache {
  CoverImageDiskCache({CacheManager? cacheManager})
    : _cacheManager = cacheManager;

  static final CoverImageDiskCache instance = CoverImageDiskCache();

  static const Duration defaultStalePeriod = Duration(days: 30);
  static const int defaultMaxEntries = 300;
  static const Map<String, String> defaultHttpHeaders = <String, String>{
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 13; Pixel 7 Build/TQ3A.230901.001) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
  };

  static const String _cacheKey = 'shuxiang_reading_next_cover_images';

  CacheManager? _cacheManager;

  BaseCacheManager get cacheManager => _ensureCacheManager();

  Future<int> clearAll() async {
    final count = await countAll();
    await _ensureCacheManager().emptyCache();
    return count;
  }

  Future<int> countAll() async {
    if (kIsWeb) {
      return 0;
    }
    final objects = await _loadCacheObjects();
    return objects.length;
  }

  Future<int> estimateAllBytes() async {
    if (kIsWeb) {
      return 0;
    }
    return _ensureCacheManager().store.getCacheSize();
  }

  Future<int> compact({
    Duration stalePeriod = defaultStalePeriod,
    int maxEntries = defaultMaxEntries,
    int maxBytes = -1,
  }) async {
    if (kIsWeb) {
      return 0;
    }

    final cacheManager = _ensureCacheManager();
    final repository = cacheManager.config.repo;
    await repository.open();
    final removals = <String>{};

    for (final object in await repository.getOldObjects(stalePeriod)) {
      removals.add(object.key);
    }
    for (final object in await repository.getObjectsOverCapacity(maxEntries)) {
      removals.add(object.key);
    }

    final normalizedMaxBytes = maxBytes < 0 ? -1 : maxBytes;
    if (normalizedMaxBytes >= 0) {
      var retained = await repository.getAllObjects();
      retained = retained
        .where((object) => !removals.contains(object.key))
        .toList(growable: false)..sort((a, b) {
        final leftTouched = a.touched ?? DateTime.fromMillisecondsSinceEpoch(0);
        final rightTouched =
            b.touched ?? DateTime.fromMillisecondsSinceEpoch(0);
        return leftTouched.compareTo(rightTouched);
      });

      var retainedBytes = retained.fold<int>(
        0,
        (sum, object) => sum + (object.length ?? 0),
      );
      for (final object in retained) {
        if (retainedBytes <= normalizedMaxBytes) {
          break;
        }
        removals.add(object.key);
        retainedBytes -= object.length ?? 0;
      }
    }

    for (final key in removals) {
      await cacheManager.removeFile(key);
    }
    return removals.length;
  }

  Future<bool> clearByUrl(String imageUrl) async {
    final normalizedUrl = _normalizeHttpUrl(imageUrl);
    if (normalizedUrl == null) {
      return false;
    }

    final cacheManager = _ensureCacheManager();
    final cached = await cacheManager.getFileFromCache(
      normalizedUrl,
      ignoreMemCache: true,
    );
    await cacheManager.removeFile(normalizedUrl);
    return cached != null;
  }

  Future<List<CacheObject>> _loadCacheObjects() async {
    final repository = _ensureCacheManager().config.repo;
    await repository.open();
    return repository.getAllObjects();
  }

  CacheManager _ensureCacheManager() {
    return _cacheManager ??= _buildDefaultCacheManager();
  }

  static CacheManager _buildDefaultCacheManager() {
    return CacheManager(
      Config(
        _cacheKey,
        stalePeriod: defaultStalePeriod,
        maxNrOfCacheObjects: defaultMaxEntries,
      ),
    );
  }

  static String? _normalizeHttpUrl(String imageUrl) {
    final normalizedUrl = imageUrl.trim();
    if (normalizedUrl.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(normalizedUrl);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return null;
    }
    return normalizedUrl;
  }
}

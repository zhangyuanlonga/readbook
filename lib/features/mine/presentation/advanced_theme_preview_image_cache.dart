import 'dart:io';

import 'package:flutter/widgets.dart';

import '../../../app/widgets/advanced_theme_backdrop_decoration.dart';
import '../../../core/cache/cache_entry.dart';
import '../../../core/cache/cache_key.dart';
import '../../../core/cache/cache_policy.dart';
import '../../../core/cache/cache_result.dart';
import '../../../core/cache/cache_scope.dart';
import '../../../core/cache/cache_store.dart';

class AdvancedThemePreviewImageCache {
  static final AdvancedThemePreviewImageCache shared =
      AdvancedThemePreviewImageCache();

  final Map<String, ImageProvider<Object>> _providers =
      <String, ImageProvider<Object>>{};

  ImageProvider<Object> providerFor(String wallpaperPath) {
    return _providers.putIfAbsent(
      wallpaperPath,
      () => ResizeImage(FileImage(File(wallpaperPath)), width: 640),
    );
  }

  int get length => _providers.length;

  int clear() {
    final count = _providers.length;
    _providers.clear();
    return count;
  }
}

class AdvancedThemePreviewCacheStore implements AppCacheStore {
  AdvancedThemePreviewCacheStore({AdvancedThemePreviewImageCache? previewCache})
    : _previewCache = previewCache ?? AdvancedThemePreviewImageCache.shared;

  final AdvancedThemePreviewImageCache _previewCache;

  @override
  AppCacheScope get scope => AppCacheScope.themePreview;

  @override
  String get backendName => 'memory.advanced_theme_preview_providers';

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
    final deleted =
        _previewCache.clear() + clearAdvancedThemeBackdropImageProviderCache();
    return AppCacheDeleteResult.deleted(
      scope: scope,
      backend: backendName,
      deletedEntries: deleted,
    );
  }

  @override
  Future<AppCacheStats> stats({String? owner}) async {
    return AppCacheStats(
      scope: scope,
      backend: backendName,
      entries:
          _previewCache.length + advancedThemeBackdropImageProviderCacheLength,
      bytes: 0,
    );
  }

  @override
  Future<AppCachePruneResult> prune(AppCachePolicy policy) async {
    final maxEntries = policy.maxEntries;
    if (maxEntries == null || maxEntries <= 0) {
      return AppCachePruneResult(scope: scope, backend: backendName);
    }
    final current = await stats();
    if (current.entries <= maxEntries) {
      return AppCachePruneResult(scope: scope, backend: backendName);
    }
    final deleted =
        _previewCache.clear() + clearAdvancedThemeBackdropImageProviderCache();
    return AppCachePruneResult(
      scope: scope,
      backend: backendName,
      deletedEntries: deleted,
    );
  }
}

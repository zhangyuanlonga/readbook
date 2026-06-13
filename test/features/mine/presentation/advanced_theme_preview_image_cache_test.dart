import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/core/cache/cache_result.dart';
import 'package:shuxiang_reading_next/core/cache/cache_scope.dart';
import 'package:shuxiang_reading_next/features/mine/presentation/advanced_theme_preview_image_cache.dart';

void main() {
  group('AdvancedThemePreviewImageCache', () {
    test('reuses providers by wallpaper path and can be cleared', () {
      final cache = AdvancedThemePreviewImageCache();

      final first = cache.providerFor('C:/tmp/wallpaper.png');
      final second = cache.providerFor('C:/tmp/wallpaper.png');
      final other = cache.providerFor('C:/tmp/other.png');

      expect(identical(first, second), isTrue);
      expect(identical(first, other), isFalse);
      expect(cache.length, 2);

      cache.clear();

      expect(cache.length, 0);
    });

    test('cache store reports and clears preview providers', () async {
      final cache = AdvancedThemePreviewImageCache();
      final store = AdvancedThemePreviewCacheStore(previewCache: cache);

      cache.providerFor('C:/tmp/wallpaper.png');
      cache.providerFor('C:/tmp/other.png');

      final stats = await store.stats();

      expect(stats.scope, AppCacheScope.themePreview);
      expect(stats.entries, 2);

      final result = await store.clearScope();

      expect(result.status, AppCacheDeleteStatus.deleted);
      expect(result.deletedEntries, 2);
      expect(cache.length, 0);
    });
  });
}

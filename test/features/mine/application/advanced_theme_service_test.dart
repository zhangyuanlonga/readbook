import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuxiang_reading_next/core/storage/managed_asset_store.dart';
import 'package:shuxiang_reading_next/domain/entities/app_advanced_theme.dart';
import 'package:shuxiang_reading_next/features/mine/application/advanced_theme_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('encodes theme colors as portable json payload', () {
    final service = AdvancedThemeService();
    final theme = AppAdvancedTheme(
      id: 'theme_a',
      name: '护眼绿',
      createdAt: DateTime.parse('2026-04-18T00:00:00.000Z'),
      updatedAt: DateTime.parse('2026-04-18T00:00:00.000Z'),
      lightConfig: AppAdvancedThemeModeConfig(
        colors: AppAdvancedThemeColors(
          primaryColorValue: 0xFF336699,
          backgroundColorValue: 0xFFF5F8F2,
        ),
        readerWallpaperPath: '/tmp/reader_light.jpg',
      ),
      darkConfig: AppAdvancedThemeModeConfig(
        colors: AppAdvancedThemeColors(
          primaryColorValue: 0xFF88CCAA,
          backgroundColorValue: 0xFF101512,
        ),
        readerWallpaperPath: '/tmp/reader_dark.jpg',
      ),
      coverGalleryId: 'cover_gallery_1',
      launchImageGalleryId: 'launch_gallery_1',
      bottomNavGalleryId: 'bottom_gallery_1',
    );

    final rawJson = service.encodeThemeColorJson(theme);
    final decoded = jsonDecode(rawJson) as Map<String, dynamic>;

    expect(decoded['type'], 'advanced_theme_colors');
    expect(decoded['version'], 2);
    expect(decoded['name'], '护眼绿');
    expect(decoded['lightConfig'], isA<Map>());
    expect(decoded['darkConfig'], isA<Map>());
    expect(decoded.containsKey('coverGalleryId'), isFalse);
    expect(decoded.containsKey('launchImageGalleryId'), isFalse);
    expect(decoded.containsKey('bottomNavGalleryId'), isFalse);
    expect(decoded.containsKey('wallpaperPath'), isFalse);
  });

  test('imports theme colors into a new saved theme', () async {
    final service = AdvancedThemeService(assetStore: await _createAssetStore());

    final imported = await service.importThemeColorJson(
      jsonEncode(<String, dynamic>{
        'type': 'advanced_theme_colors',
        'version': 1,
        'name': '薄雾灰',
        'lightColors': <String, dynamic>{
          'primaryColorValue': 0xFF556677,
          'surfaceColorValue': 0xFFF6F6F4,
        },
        'darkColors': <String, dynamic>{
          'primaryColorValue': 0xFF99AABB,
          'surfaceColorValue': 0xFF17191A,
        },
      }),
    );

    expect(imported.id, startsWith('advanced_theme_'));
    expect(imported.name, '薄雾灰');
    expect(imported.lightConfig.colors.primaryColorValue, 0xFF556677);
    expect(imported.darkConfig.colors.primaryColorValue, 0xFF99AABB);
    expect(imported.coverGalleryId, isNull);
    expect(imported.launchImageGalleryId, isNull);
    expect(imported.bottomNavGalleryId, isNull);
    expect(imported.lightConfig.wallpaperPath, isNull);
    expect(imported.darkConfig.wallpaperPath, isNull);
    expect(imported.lightConfig.readerWallpaperPath, isNull);
    expect(imported.darkConfig.readerWallpaperPath, isNull);

    final themes = await service.loadThemes();
    expect(themes, hasLength(1));
    expect(themes.first.name, '薄雾灰');
  });

  test('persists reader wallpaper path inside theme mode config', () async {
    final service = AdvancedThemeService(assetStore: await _createAssetStore());
    final theme = AppAdvancedTheme(
      id: 'theme_reader_wallpaper',
      name: '阅读器联动',
      createdAt: DateTime.parse('2026-04-21T00:00:00.000Z'),
      updatedAt: DateTime.parse('2026-04-21T00:00:00.000Z'),
      lightConfig: AppAdvancedThemeModeConfig(
        readerWallpaperPath: '/tmp/reader_light.jpg',
      ),
      darkConfig: AppAdvancedThemeModeConfig(
        readerWallpaperPath: '/tmp/reader_dark.jpg',
      ),
    );

    await service.saveTheme(theme);
    final themes = await service.loadThemes();

    expect(themes, hasLength(1));
    expect(
      themes.first.lightConfig.readerWallpaperPath,
      '/tmp/reader_light.jpg',
    );
    expect(themes.first.darkConfig.readerWallpaperPath, '/tmp/reader_dark.jpg');
  });

  test('persists launch image gallery binding in theme payload', () async {
    final service = AdvancedThemeService(assetStore: await _createAssetStore());
    final theme = AppAdvancedTheme(
      id: 'theme_launch_gallery',
      name: '启动联动',
      createdAt: DateTime.parse('2026-04-22T00:00:00.000Z'),
      updatedAt: DateTime.parse('2026-04-22T00:00:00.000Z'),
      lightConfig: AppAdvancedThemeModeConfig(),
      darkConfig: AppAdvancedThemeModeConfig(),
      launchImageGalleryId: 'launch_gallery_a',
    );

    await service.saveTheme(theme);
    final themes = await service.loadThemes();

    expect(themes, hasLength(1));
    expect(themes.first.launchImageGalleryId, 'launch_gallery_a');
  });

  test(
    'persists theme category and mode-specific cover gallery bindings',
    () async {
      final service = AdvancedThemeService(
        assetStore: await _createAssetStore(),
      );
      final theme = AppAdvancedTheme(
        id: 'theme_cover_modes',
        name: '双封面主题',
        createdAt: DateTime.parse('2026-04-22T00:00:00.000Z'),
        updatedAt: DateTime.parse('2026-04-22T00:00:00.000Z'),
        lightConfig: AppAdvancedThemeModeConfig(),
        darkConfig: AppAdvancedThemeModeConfig(),
        category: '护眼',
        lightCoverGalleryId: 'cover_gallery_light',
        darkCoverGalleryId: 'cover_gallery_dark',
      );

      await service.saveTheme(theme);
      final themes = await service.loadThemes();

      expect(themes, hasLength(1));
      expect(themes.first.category, '护眼');
      expect(
        themes.first.coverGalleryIdFor(AppAdvancedThemeMode.light),
        'cover_gallery_light',
      );
      expect(
        themes.first.coverGalleryIdFor(AppAdvancedThemeMode.dark),
        'cover_gallery_dark',
      );
    },
  );

  test('rejects importing duplicate theme payload by fingerprint', () async {
    final service = AdvancedThemeService(assetStore: await _createAssetStore());
    final payload = jsonEncode(<String, dynamic>{
      'type': 'advanced_theme_colors',
      'version': 2,
      'name': '薄雾灰',
      'lightConfig': <String, dynamic>{
        'colors': <String, dynamic>{'primaryColorValue': 0xFF556677},
      },
      'darkConfig': <String, dynamic>{
        'colors': <String, dynamic>{'primaryColorValue': 0xFF99AABB},
      },
    });

    await service.importThemeColorJson(payload);

    await expectLater(
      () => service.importThemeColorJson(payload),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('已导入重复主题'),
        ),
      ),
    );
  });
}

Future<ManagedAssetStore> _createAssetStore() async {
  final documentsDir = await Directory.systemTemp.createTemp('theme_docs_');
  final supportDir = await Directory.systemTemp.createTemp('theme_support_');
  addTearDown(() async {
    if (documentsDir.existsSync()) {
      await documentsDir.delete(recursive: true);
    }
    if (supportDir.existsSync()) {
      await supportDir.delete(recursive: true);
    }
  });
  return ManagedAssetStore(
    documentsDirectoryProvider: () async => documentsDir,
    supportDirectoryProvider: () async => supportDir,
  );
}

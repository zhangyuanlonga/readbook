import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuxiang_reading_next/app/navigation/bottom_nav_icon_gallery_service.dart';
import 'package:shuxiang_reading_next/core/storage/managed_asset_store.dart';
import 'package:shuxiang_reading_next/domain/entities/app_advanced_theme.dart';
import 'package:shuxiang_reading_next/features/mine/application/advanced_theme_resource_reference_service.dart';
import 'package:shuxiang_reading_next/features/mine/application/cover_gallery_service.dart';
import 'package:shuxiang_reading_next/features/mine/application/gallery_index_file_store.dart';
import 'package:shuxiang_reading_next/features/mine/application/launch_image_gallery_service.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_font_registry_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('resource reference index resolves theme-bound assets', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final service = AdvancedThemeResourceReferenceService(preferences: prefs);
    final themes = <AppAdvancedTheme>[
      AppAdvancedTheme(
        id: 'theme_a',
        name: '主题 A',
        createdAt: DateTime.parse('2026-05-06T00:00:00.000Z'),
        updatedAt: DateTime.parse('2026-05-06T00:00:00.000Z'),
        lightConfig: AppAdvancedThemeModeConfig(
          wallpaperPath: '/tmp/wallpaper_light.png',
          readerWallpaperPath: '/tmp/reader_light.png',
        ),
        darkConfig: AppAdvancedThemeModeConfig(
          wallpaperPath: '/tmp/wallpaper_dark.png',
          readerWallpaperPath: '/tmp/reader_dark.png',
        ),
        coverGalleryId: 'cover_shared',
        lightCoverGalleryId: 'cover_light',
        darkCoverGalleryId: 'cover_dark',
        launchImageGalleryId: 'launch_a',
        bottomNavGalleryId: 'bottom_a',
      ),
    ];

    expect(service.coverGalleryIdsForTheme(themes.single), <String>{
      'cover_shared',
      'cover_light',
      'cover_dark',
    });
    expect(
      service.isAppearanceBackgroundReferenced(
        themes,
        ' /tmp/wallpaper_light.png ',
      ),
      isTrue,
    );
    expect(
      service.isReaderBackgroundReferenced(themes, '/tmp/reader_dark.png'),
      isTrue,
    );
    expect(service.isCoverGalleryReferenced(themes, 'cover_dark'), isTrue);
    expect(service.isLaunchGalleryReferenced(themes, 'launch_a'), isTrue);
    expect(service.isBottomNavGalleryReferenced(themes, 'bottom_a'), isTrue);
    expect(service.isCoverGalleryReferenced(themes, 'missing'), isFalse);
  });

  test(
    'filterRemovableFontFamilyKeys respects theme and manual settings references',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'app.interfaceFont.familyKey': 'font_ui_1',
        'reader.settings.fontFamilyKey': 'font_reader_1',
      });
      final prefs = await SharedPreferences.getInstance();
      final service = AdvancedThemeResourceReferenceService(preferences: prefs);

      final removable = await service.filterRemovableFontFamilyKeys(
        fontFamilyKeys: const <String>[
          'font_ui_1',
          'font_reader_1',
          'font_theme_1',
          'font_free_1',
        ],
        remainingThemes: <AppAdvancedTheme>[
          AppAdvancedTheme(
            id: 'theme_other',
            name: '其他主题',
            createdAt: DateTime.parse('2026-05-06T00:00:00.000Z'),
            updatedAt: DateTime.parse('2026-05-06T00:00:00.000Z'),
            lightConfig: AppAdvancedThemeModeConfig(),
            darkConfig: AppAdvancedThemeModeConfig(),
            readerFontFamilyKey: 'font_theme_1',
          ),
        ],
      );

      expect(removable, <String>['font_free_1']);
    },
  );

  test(
    'buildDeletePreview exposes actual bound resources and safe defaults',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      final assetStore = await _createAssetStore();
      final service = AdvancedThemeResourceReferenceService(
        preferences: prefs,
        coverGalleryService: CoverGalleryService(
          preferences: prefs,
          assetStore: assetStore,
          indexFileStore: await _createGalleryIndexFileStore(
            directoryName: 'cover_galleries',
            legacyPreferencesKey: 'coverGallery.galleries',
          ),
        ),
        launchImageGalleryService: LaunchImageGalleryService(
          preferences: prefs,
          assetStore: assetStore,
          indexFileStore: await _createGalleryIndexFileStore(
            directoryName: 'launch_image_galleries',
            legacyPreferencesKey: 'launchImageGallery.galleries',
          ),
        ),
        bottomNavIconGalleryService: BottomNavIconGalleryService(
          preferences: prefs,
          assetStore: assetStore,
        ),
        fontRegistryService: ReaderFontRegistryService(assetStore: assetStore),
      );
      final theme = AppAdvancedTheme(
        id: 'theme_preview',
        name: '预览主题',
        createdAt: DateTime.parse('2026-05-06T00:00:00.000Z'),
        updatedAt: DateTime.parse('2026-05-06T00:00:00.000Z'),
        lightConfig: AppAdvancedThemeModeConfig(
          wallpaperPath: '/tmp/light_wallpaper.png',
        ),
        darkConfig: AppAdvancedThemeModeConfig(
          readerWallpaperPath: '/tmp/dark_reader.png',
        ),
        launchImageGalleryId: 'launch_gallery_demo',
        appInterfaceFontFamilyKey: 'font_ui_demo',
      );

      final preview = await service.buildDeletePreview(
        theme: theme,
        remainingThemes: const <AppAdvancedTheme>[],
      );

      expect(preview.themeName, '预览主题');
      expect(preview.sections, isNotEmpty);
      expect(
        preview.sections.any(
          (section) =>
              section.kind ==
                  AdvancedThemeDeleteOptionKind.appearanceWallpapers &&
              section.defaultSelected,
        ),
        isTrue,
      );
      expect(
        preview.sections.any(
          (section) =>
              section.kind == AdvancedThemeDeleteOptionKind.readerWallpapers &&
              section.defaultSelected,
        ),
        isTrue,
      );
      expect(
        preview.sections.any(
          (section) =>
              section.kind ==
                  AdvancedThemeDeleteOptionKind.launchImageGallery &&
              !section.defaultSelected,
        ),
        isTrue,
      );
      expect(
        preview.sections.any(
          (section) =>
              section.kind == AdvancedThemeDeleteOptionKind.fonts &&
              !section.defaultSelected,
        ),
        isTrue,
      );
    },
  );
}

Future<GalleryIndexFileStore> _createGalleryIndexFileStore({
  required String directoryName,
  required String legacyPreferencesKey,
}) async {
  final documentsDir = await Directory.systemTemp.createTemp(
    'theme_ref_gallery_index_',
  );
  addTearDown(() async {
    if (documentsDir.existsSync()) {
      await documentsDir.delete(recursive: true);
    }
  });
  return GalleryIndexFileStore(
    directoryName: directoryName,
    legacyPreferencesKey: legacyPreferencesKey,
    documentsDirectoryProvider: () async => documentsDir,
  );
}

Future<ManagedAssetStore> _createAssetStore() async {
  final documentsDir = await Directory.systemTemp.createTemp('theme_ref_docs_');
  final supportDir = await Directory.systemTemp.createTemp(
    'theme_ref_support_',
  );
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

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuxiang_reading_next/core/storage/managed_asset_store.dart';
import 'package:shuxiang_reading_next/domain/entities/app_advanced_theme.dart';
import 'package:shuxiang_reading_next/features/mine/application/advanced_theme_resource_reference_service.dart';
import 'package:shuxiang_reading_next/features/mine/application/cover_gallery_service.dart';
import 'package:shuxiang_reading_next/features/mine/application/launch_image_gallery_service.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_font_registry_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
        ),
        launchImageGalleryService: LaunchImageGalleryService(
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

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuxiang_reading_next/app/navigation/bottom_nav_icon_gallery_provider.dart';
import 'package:shuxiang_reading_next/app/navigation/bottom_nav_icon_gallery_service.dart';
import 'package:shuxiang_reading_next/core/storage/managed_asset_store.dart';
import 'package:shuxiang_reading_next/domain/entities/app_advanced_theme.dart';
import 'package:shuxiang_reading_next/domain/entities/bottom_nav_icon_gallery.dart';
import 'package:shuxiang_reading_next/features/mine/application/advanced_theme_provider.dart';
import 'package:shuxiang_reading_next/features/mine/application/advanced_theme_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    ActiveAdvancedThemeIdNotifier.prime(prefs);
  });

  test('effective gallery prefers active advanced theme binding', () async {
    final prefs = await SharedPreferences.getInstance();
    final assetStore = await _createAssetStore();
    final themeService = AdvancedThemeService(
      preferences: prefs,
      assetStore: assetStore,
    );
    final galleryService = BottomNavIconGalleryService(
      preferences: prefs,
      assetStore: assetStore,
    );
    await galleryService.saveGalleries(<BottomNavIconGallery>[
      _gallery(id: 'gallery_active', name: '当前默认图集'),
      _gallery(id: 'gallery_theme', name: '主题图集'),
    ]);
    await galleryService.saveActiveGalleryId('gallery_active');
    await themeService.saveTheme(
      AppAdvancedTheme(
        id: 'theme_nav_override',
        name: '底栏覆盖主题',
        createdAt: DateTime.parse('2026-05-06T00:00:00.000Z'),
        updatedAt: DateTime.parse('2026-05-06T00:00:00.000Z'),
        lightConfig: AppAdvancedThemeModeConfig(),
        darkConfig: AppAdvancedThemeModeConfig(),
        bottomNavGalleryId: 'gallery_theme',
      ),
    );
    await themeService.saveActiveThemeId('theme_nav_override');
    ActiveAdvancedThemeIdNotifier.prime(prefs);

    final container = ProviderContainer(
      overrides: <Override>[
        advancedThemeServiceProvider.overrideWithValue(themeService),
        bottomNavIconGalleryServiceProvider.overrideWithValue(galleryService),
      ],
    );
    addTearDown(container.dispose);

    final gallery = await container.read(
      effectiveBottomNavIconGalleryProvider.future,
    );

    expect(gallery?.id, 'gallery_theme');
    expect(gallery?.name, '主题图集');
  });

  test(
    'effective gallery falls back to active gallery without theme binding',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final assetStore = await _createAssetStore();
      final themeService = AdvancedThemeService(
        preferences: prefs,
        assetStore: assetStore,
      );
      final galleryService = BottomNavIconGalleryService(
        preferences: prefs,
        assetStore: assetStore,
      );
      await galleryService.saveGalleries(<BottomNavIconGallery>[
        _gallery(id: 'gallery_active', name: '当前默认图集'),
      ]);
      await galleryService.saveActiveGalleryId('gallery_active');
      await themeService.saveTheme(
        AppAdvancedTheme(
          id: 'theme_without_override',
          name: '不覆盖底栏',
          createdAt: DateTime.parse('2026-05-06T00:00:00.000Z'),
          updatedAt: DateTime.parse('2026-05-06T00:00:00.000Z'),
          lightConfig: AppAdvancedThemeModeConfig(),
          darkConfig: AppAdvancedThemeModeConfig(),
        ),
      );
      await themeService.saveActiveThemeId('theme_without_override');
      ActiveAdvancedThemeIdNotifier.prime(prefs);

      final container = ProviderContainer(
        overrides: <Override>[
          advancedThemeServiceProvider.overrideWithValue(themeService),
          bottomNavIconGalleryServiceProvider.overrideWithValue(galleryService),
        ],
      );
      addTearDown(container.dispose);

      final gallery = await container.read(
        effectiveBottomNavIconGalleryProvider.future,
      );

      expect(gallery?.id, 'gallery_active');
      expect(gallery?.name, '当前默认图集');
    },
  );
}

BottomNavIconGallery _gallery({required String id, required String name}) {
  return BottomNavIconGallery(
    id: id,
    name: name,
    createdAt: DateTime.parse('2026-05-06T00:00:00.000Z'),
    updatedAt: DateTime.parse('2026-05-06T00:00:00.000Z'),
    isBuiltIn: false,
    isEditable: true,
    isDeletable: true,
    items: const <BottomNavIconGalleryTab, BottomNavIconSet>{
      BottomNavIconGalleryTab.home: BottomNavIconSet(),
    },
  );
}

Future<ManagedAssetStore> _createAssetStore() async {
  final documentsDir = await Directory.systemTemp.createTemp(
    'nav_provider_docs_',
  );
  final supportDir = await Directory.systemTemp.createTemp(
    'nav_provider_support_',
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

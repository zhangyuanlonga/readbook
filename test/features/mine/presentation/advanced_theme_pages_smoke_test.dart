import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuxiang_reading_next/core/storage/managed_asset_store.dart';
import 'package:shuxiang_reading_next/domain/entities/app_advanced_theme.dart';
import 'package:shuxiang_reading_next/features/mine/application/advanced_theme_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  late Directory documentsDir;
  late Directory supportDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'auth.access_token': 'token_smoke',
      'auth.user_id': 'user_smoke',
      'auth.username': 'theme_smoke',
    });
    documentsDir = await Directory.systemTemp.createTemp(
      'advanced_theme_pages_docs_',
    );
    supportDir = await Directory.systemTemp.createTemp(
      'advanced_theme_pages_support_',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
          if (call.method == 'getApplicationDocumentsDirectory') {
            return documentsDir.path;
          }
          if (call.method == 'getApplicationSupportDirectory') {
            return supportDir.path;
          }
          return null;
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
    if (documentsDir.existsSync()) {
      await documentsDir.delete(recursive: true);
    }
    if (supportDir.existsSync()) {
      await supportDir.delete(recursive: true);
    }
  });

  test('legacy flat theme can save without losing visuals', () async {
    final prefs = await SharedPreferences.getInstance();
    final legacyThemeJson = <String, dynamic>{
      'id': 'legacy_theme_editor',
      'name': '旧结构主题',
      'createdAt': '2026-05-07T00:00:00.000Z',
      'updatedAt': '2026-05-07T00:00:00.000Z',
      'lightConfig': <String, dynamic>{
        'colors': <String, dynamic>{
          'primaryColorValue': 0xFF556677,
          'cardColorValue': 0xFFF8F6F0,
          'cardBorderColorValue': 0xFFD9D3C7,
          'shadowColorValue': 0x55334455,
          'wallpaperOverlayColorValue': 0xFFF2EEE6,
        },
        'wallpaperOpacity': 1.0,
        'wallpaperBlurSigma': 0.0,
        'wallpaperFit': 'cover',
        'wallpaperOverlayOpacity': 0.32,
        'readerWallpaperOpacity': 1.0,
        'readerWallpaperBlurSigma': 0.0,
        'readerWallpaperFit': 'cover',
        'readerWallpaperOverlayOpacity': 0.0,
      },
      'darkConfig': <String, dynamic>{
        'colors': <String, dynamic>{
          'primaryColorValue': 0xFF99AABB,
          'cardColorValue': 0xFF202326,
          'cardBorderColorValue': 0xFF3A4048,
          'shadowColorValue': 0x66334455,
          'wallpaperOverlayColorValue': 0xFF12161C,
        },
        'wallpaperOpacity': 1.0,
        'wallpaperBlurSigma': 0.0,
        'wallpaperFit': 'cover',
        'wallpaperOverlayOpacity': 0.32,
        'readerWallpaperOpacity': 1.0,
        'readerWallpaperBlurSigma': 0.0,
        'readerWallpaperFit': 'cover',
        'readerWallpaperOverlayOpacity': 0.0,
      },
    };

    final service = AdvancedThemeService(
      preferences: prefs,
      assetStore: _assetStore(),
    );
    final legacyTheme = AppAdvancedTheme.fromJson(legacyThemeJson);
    await service.saveTheme(legacyTheme);

    final saved = await service.loadThemeById('legacy_theme_editor');
    expect(saved, isNotNull);
    expect(saved!.lightConfig.colors.primaryColorValue, 0xFF556677);
    expect(saved.lightConfig.colors.cardBorderColorValue, 0xFFD9D3C7);
    expect(saved.lightConfig.colors.shadowColorValue, 0x55334455);
    expect(saved.darkConfig.colors.primaryColorValue, 0xFF99AABB);
    expect(saved.darkConfig.colors.shadowColorValue, 0x66334455);
  });

  test(
    'advanced theme service stores many themes for list page smoke',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final service = AdvancedThemeService(
        preferences: prefs,
        assetStore: _assetStore(),
      );

      final themes = <AppAdvancedTheme>[
        for (var index = 0; index < 50; index += 1)
          AppAdvancedTheme(
            id: 'theme_$index',
            name: '主题 $index',
            createdAt: DateTime.parse('2026-05-07T00:00:00.000Z'),
            updatedAt: DateTime.parse(
              '2026-05-07T00:${(index % 60).toString().padLeft(2, '0')}:00.000Z',
            ),
            lightConfig: AppAdvancedThemeModeConfig(
              colors: AppAdvancedThemeColors(
                primaryColorValue: 0xFF336699 + index,
                backgroundColorValue: 0xFFF5F1E8,
              ),
            ),
            darkConfig: AppAdvancedThemeModeConfig(
              colors: AppAdvancedThemeColors(
                primaryColorValue: 0xFF88AACC + index,
                backgroundColorValue: 0xFF161B22,
              ),
            ),
            category: index.isEven ? '护眼' : '极简',
          ),
      ];
      await service.saveThemes(themes);

      final summaries = await service.loadThemeSummaries();
      expect(summaries, hasLength(50));
      expect(summaries.first.name, '主题 49');
      expect(summaries.map((theme) => theme.category).toSet(), {'护眼', '极简'});
    },
  );
}

ManagedAssetStore _assetStore() {
  return ManagedAssetStore();
}

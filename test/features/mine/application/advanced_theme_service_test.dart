import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuxiang_reading_next/domain/entities/app_advanced_theme.dart';
import 'package:shuxiang_reading_next/features/mine/application/advanced_theme_service.dart';

void main() {
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
      lightConfig: const AppAdvancedThemeModeConfig(
        colors: AppAdvancedThemeColors(
          primaryColorValue: 0xFF336699,
          backgroundColorValue: 0xFFF5F8F2,
        ),
      ),
      darkConfig: const AppAdvancedThemeModeConfig(
        colors: AppAdvancedThemeColors(
          primaryColorValue: 0xFF88CCAA,
          backgroundColorValue: 0xFF101512,
        ),
      ),
      coverGalleryId: 'cover_gallery_1',
      bottomNavGalleryId: 'bottom_gallery_1',
    );

    final rawJson = service.encodeThemeColorJson(theme);
    final decoded = jsonDecode(rawJson) as Map<String, dynamic>;

    expect(decoded['type'], 'advanced_theme_colors');
    expect(decoded['version'], 1);
    expect(decoded['name'], '护眼绿');
    expect(decoded['lightColors'], isA<Map>());
    expect(decoded['darkColors'], isA<Map>());
    expect(decoded.containsKey('coverGalleryId'), isFalse);
    expect(decoded.containsKey('bottomNavGalleryId'), isFalse);
    expect(decoded.containsKey('wallpaperPath'), isFalse);
  });

  test('imports theme colors into a new saved theme', () async {
    final service = AdvancedThemeService();

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
    expect(imported.bottomNavGalleryId, isNull);
    expect(imported.lightConfig.wallpaperPath, isNull);
    expect(imported.darkConfig.wallpaperPath, isNull);

    final themes = await service.loadThemes();
    expect(themes, hasLength(1));
    expect(themes.first.name, '薄雾灰');
  });
}

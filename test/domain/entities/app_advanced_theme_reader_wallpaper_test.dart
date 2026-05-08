import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/app_advanced_theme.dart';

void main() {
  test('mode config serializes and copies reader wallpaper binding', () {
    final config = AppAdvancedThemeModeConfig(
      wallpaperPath: '/tmp/app_bg.jpg',
      readerWallpaperPath: '/tmp/reader_bg.jpg',
    );

    final json = config.toJson();
    expect((json['wallpaperAsset'] as Map)['relativePath'], '/tmp/app_bg.jpg');
    expect(
      (json['readerWallpaperAsset'] as Map)['relativePath'],
      '/tmp/reader_bg.jpg',
    );

    final restored = AppAdvancedThemeModeConfig.fromJson(json);
    expect(restored.wallpaperPath, '/tmp/app_bg.jpg');
    expect(restored.readerWallpaperPath, '/tmp/reader_bg.jpg');
    expect(restored.hasReaderWallpaper, isTrue);

    final cleared = restored.copyWith(clearReaderWallpaperPath: true);
    expect(cleared.readerWallpaperPath, isNull);
    expect(cleared.hasReaderWallpaper, isFalse);
  });

  test('theme colors serialize semantic groups while keeping flat fields', () {
    const colors = AppAdvancedThemeColors(
      primaryColorValue: 0xFF123456,
      backgroundColorValue: 0xFFF5F1E8,
      cardColorValue: 0xFFFFFFFF,
      shadowColorValue: 0xFF334455,
    );

    final json = colors.toJson();
    final semanticGroups =
        json[AppAdvancedThemeColors.semanticColorGroupsKey] as Map;

    expect(json['primaryColorValue'], 0xFF123456);
    expect((semanticGroups['core'] as Map)['primary'], 0xFF123456);
    expect((semanticGroups['core'] as Map)['background'], 0xFFF5F1E8);
    expect((semanticGroups['component'] as Map)['card'], 0xFFFFFFFF);
    expect((semanticGroups['effects'] as Map)['shadow'], 0xFF334455);
  });

  test('theme colors can restore from semantic groups without flat fields', () {
    final restored = AppAdvancedThemeColors.fromJson(<String, dynamic>{
      AppAdvancedThemeColors.semanticColorGroupsKey: <String, dynamic>{
        'core': <String, dynamic>{
          'primary': 0xFF123456,
          'background': 0xFFF5F1E8,
          'surface': 0xFFF0E8DA,
          'textPrimary': 0xFF1A1A1A,
          'textSecondary': 0xFF666666,
          'outline': 0xFFD0C7B8,
        },
        'component': <String, dynamic>{'card': 0xFFFFFFFF},
        'state': <String, dynamic>{
          'primaryContainer': 0xFFE6DDCD,
          'noticeAccent': 0xFFAA7744,
          'noticeSurface': 0xFFF7E8D0,
        },
        'advanced': <String, dynamic>{
          'searchFieldBackground': 0xFFF3EEE5,
          'elevatedSurface': 0xFFF8F3EA,
          'cardText': 0xFF252525,
          'cardBorder': 0xFFE0D7C7,
          'secondary': 0xFF886644,
        },
        'derived': <String, dynamic>{
          'buttonText': 0xFFFFFFFF,
          'iconBackground': 0xFFF1ECE3,
        },
        'effects': <String, dynamic>{
          'shadow': 0xFF334455,
          'wallpaperOverlayColor': 0xFFF5F1E8,
        },
      },
    });

    expect(restored.primaryColorValue, 0xFF123456);
    expect(restored.backgroundColorValue, 0xFFF5F1E8);
    expect(restored.cardColorValue, 0xFFFFFFFF);
    expect(restored.secondaryColorValue, 0xFF886644);
    expect(restored.buttonTextColorValue, 0xFFFFFFFF);
    expect(restored.shadowColorValue, 0xFF334455);
  });
}

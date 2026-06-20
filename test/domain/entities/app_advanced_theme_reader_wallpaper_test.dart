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
      dividerColorValue: 0xFFE6DFD3,
      shadowColorValue: 0xFF334455,
    );

    final json = colors.toJson();
    final semanticGroups =
        json[AppAdvancedThemeColors.semanticColorGroupsKey] as Map;

    expect(json['primaryColorValue'], 0xFF123456);
    expect((semanticGroups['core'] as Map)['primary'], 0xFF123456);
    expect((semanticGroups['core'] as Map)['background'], 0xFFF5F1E8);
    expect((semanticGroups['core'] as Map)['divider'], 0xFFE6DFD3);
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
          'divider': 0xFFE6DFD3,
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
    expect(restored.dividerColorValue, 0xFFE6DFD3);
    expect(restored.shadowColorValue, 0xFF334455);
  });

  test(
    'mode config restores default component style when legacy json has no componentStyle',
    () {
      final restored = AppAdvancedThemeModeConfig.fromJson(<String, dynamic>{
        'colors': <String, dynamic>{'primaryColorValue': 0xFF123456},
        'wallpaperOpacity': 1.0,
        'wallpaperBlurSigma': 0.0,
        'wallpaperFit': 'cover',
        'wallpaperOverlayOpacity': 0.32,
      });

      expect(restored.componentStyle.globalRadiusScale, 1);
      expect(restored.componentStyle.shadowStrength, 0.5);
      expect(restored.componentStyle.cardStyle, AppAdvancedThemeCardStyle.soft);
      expect(
        restored.componentStyle.buttonStyle,
        AppAdvancedThemeButtonStyle.stadium,
      );
    },
  );

  test('theme effect serializes only when configured and restores safely', () {
    final theme = AppAdvancedTheme(
      id: 'theme_effect',
      name: '特效主题',
      createdAt: DateTime.parse('2026-06-20T00:00:00.000Z'),
      updatedAt: DateTime.parse('2026-06-20T00:00:00.000Z'),
      lightConfig: AppAdvancedThemeModeConfig(),
      darkConfig: AppAdvancedThemeModeConfig(),
      themeEffect: AppAdvancedThemeEffect.sakura,
    );

    final json = theme.toJson();
    expect(json['themeEffect'], 'sakura');

    final restored = AppAdvancedTheme.fromJson(json);
    expect(restored.themeEffect, AppAdvancedThemeEffect.sakura);

    final cleared = restored.copyWith(themeEffect: AppAdvancedThemeEffect.none);
    expect(cleared.toJson().containsKey('themeEffect'), isFalse);
    expect(
      AppAdvancedTheme.fromJson(<String, dynamic>{
        ...json,
        'themeEffect': 'unknown',
      }).themeEffect,
      AppAdvancedThemeEffect.none,
    );
  });

  test('mode config serializes and restores component style fields', () {
    final config = AppAdvancedThemeModeConfig(
      componentStyle: const AppAdvancedThemeComponentStyle(
        globalRadiusScale: 1.25,
        shadowStrength: 0.82,
        cardStyle: AppAdvancedThemeCardStyle.elevated,
        buttonStyle: AppAdvancedThemeButtonStyle.rounded,
        inputStyle: AppAdvancedThemeInputStyle.outlined,
        overlayStyle: AppAdvancedThemeOverlayStyle.compact,
        navigationStyle: AppAdvancedThemeNavigationStyle.floating,
        switchStyle: AppAdvancedThemeSwitchStyle.contrast,
      ),
    );

    final json = config.toJson();
    final restored = AppAdvancedThemeModeConfig.fromJson(json);

    expect(restored.componentStyle.globalRadiusScale, 1.25);
    expect(restored.componentStyle.shadowStrength, 0.82);
    expect(
      restored.componentStyle.cardStyle,
      AppAdvancedThemeCardStyle.elevated,
    );
    expect(
      restored.componentStyle.buttonStyle,
      AppAdvancedThemeButtonStyle.rounded,
    );
    expect(
      restored.componentStyle.inputStyle,
      AppAdvancedThemeInputStyle.outlined,
    );
    expect(
      restored.componentStyle.overlayStyle,
      AppAdvancedThemeOverlayStyle.compact,
    );
    expect(
      restored.componentStyle.navigationStyle,
      AppAdvancedThemeNavigationStyle.floating,
    );
    expect(
      restored.componentStyle.switchStyle,
      AppAdvancedThemeSwitchStyle.contrast,
    );
  });
}

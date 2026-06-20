import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shuxiang_reading_next/app/theme/app_advanced_theme_tokens.dart';
import 'package:shuxiang_reading_next/domain/entities/app_advanced_theme.dart';

void main() {
  test(
    'infers readable text colors from overridden dark surface in light mode',
    () {
      final colorScheme = ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.light,
      );
      final palette = resolveAdvancedThemePaletteFromModeConfig(
        colorScheme,
        AppAdvancedThemeModeConfig(
          colors: AppAdvancedThemeColors(
            backgroundColorValue: 0xFF141414,
            surfaceColorValue: 0xFF181818,
            searchFieldBackgroundColorValue: 0xFF222222,
            cardColorValue: 0xFF1C1C1C,
          ),
        ),
      );

      expect(palette.textPrimaryColor.computeLuminance(), greaterThan(0.7));
      expect(palette.buttonTextColor.computeLuminance(), greaterThan(0.7));
    },
  );

  test('resolves light and dark configs by active brightness', () {
    final activeTheme = AppAdvancedTheme(
      id: 'theme_mode_switch',
      name: '双模式',
      createdAt: DateTime.parse('2026-05-06T00:00:00.000Z'),
      updatedAt: DateTime.parse('2026-05-06T00:00:00.000Z'),
      lightConfig: AppAdvancedThemeModeConfig(
        colors: const AppAdvancedThemeColors(primaryColorValue: 0xFF112233),
      ),
      darkConfig: AppAdvancedThemeModeConfig(
        colors: const AppAdvancedThemeColors(primaryColorValue: 0xFFCCDDEE),
      ),
    );

    final lightPalette = resolveAdvancedThemePalette(
      ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.light,
      ),
      activeTheme,
    );
    final darkPalette = resolveAdvancedThemePalette(
      ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.dark),
      activeTheme,
    );

    expect(lightPalette.primaryColor, const Color(0xFF112233));
    expect(darkPalette.primaryColor, const Color(0xFFCCDDEE));
  });

  test(
    'derives secondary, card border and icon background from core colors',
    () {
      const primary = Color(0xFF6A4CFF);
      const surface = Color(0xFFF5F3FF);
      final palette = resolveAdvancedThemePaletteFromModeConfig(
        ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        AppAdvancedThemeModeConfig(
          colors: const AppAdvancedThemeColors(
            primaryColorValue: 0xFF6A4CFF,
            surfaceColorValue: 0xFFF5F3FF,
            outlineColorValue: 0xFFB5B0D6,
          ),
        ),
      );

      expect(palette.secondaryColor, isNot(primary));
      expect(palette.secondaryColor, isNot(surface));
      expect(palette.cardBorderColor, isNot(const Color(0xFFB5B0D6)));
      expect(palette.iconBackgroundColor, isNot(surface));
    },
  );

  test('resolves divider color with card border fallback', () {
    final colorScheme = ColorScheme.fromSeed(seedColor: Colors.blue);

    final explicit = resolveAdvancedThemePaletteFromModeConfig(
      colorScheme,
      AppAdvancedThemeModeConfig(
        colors: const AppAdvancedThemeColors(
          cardBorderColorValue: 0xFF112233,
          dividerColorValue: 0xFF445566,
        ),
      ),
    );
    final fallback = resolveAdvancedThemePaletteFromModeConfig(
      colorScheme,
      AppAdvancedThemeModeConfig(
        colors: const AppAdvancedThemeColors(cardBorderColorValue: 0xFF112233),
      ),
    );

    expect(explicit.dividerColor, const Color(0xFF445566));
    expect(fallback.dividerColor, const Color(0xFF112233));
  });

  test('derives wallpaper overlay opacity from brightness when unset', () {
    final lightBackdrop = resolveAdvancedThemeBackdropFromModeConfig(
      ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.light,
      ),
      null,
    );
    final darkBackdrop = resolveAdvancedThemeBackdropFromModeConfig(
      ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.dark),
      null,
    );

    expect(lightBackdrop.wallpaperOverlayOpacity, 0.28);
    expect(darkBackdrop.wallpaperOverlayOpacity, 0.46);
  });

  test('uses active advanced theme app wallpaper before default backdrop', () {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: Brightness.light,
    );
    final activeTheme = AppAdvancedTheme(
      id: 'theme_backdrop',
      name: '背景主题',
      createdAt: DateTime.parse('2026-05-06T00:00:00.000Z'),
      updatedAt: DateTime.parse('2026-05-06T00:00:00.000Z'),
      lightConfig: AppAdvancedThemeModeConfig(
        wallpaperPath: '/tmp/theme-wallpaper.png',
        wallpaperOpacity: 0.72,
        wallpaperBlurSigma: 6,
        colors: const AppAdvancedThemeColors(
          backgroundColorValue: 0xFF101820,
          surfaceColorValue: 0xFF1C2733,
        ),
      ),
      darkConfig: AppAdvancedThemeModeConfig(),
    );

    final themedBackdrop = resolveAdvancedThemeBackdrop(
      colorScheme,
      activeTheme,
    );
    final defaultBackdrop = resolveAdvancedThemeBackdrop(colorScheme, null);

    expect(themedBackdrop.wallpaperPath, '/tmp/theme-wallpaper.png');
    expect(themedBackdrop.wallpaperOpacity, 0.72);
    expect(themedBackdrop.wallpaperBlurSigma, 6);
    expect(themedBackdrop.backgroundColor, const Color(0xFF101820));
    expect(themedBackdrop.surfaceColor, const Color(0xFF1C2733));
    expect(defaultBackdrop.wallpaperPath, isNull);
    expect(defaultBackdrop.backgroundColor, colorScheme.surface);
  });

  test('derives shadow color from primary with brightness-aware alpha', () {
    final lightPalette = resolveAdvancedThemePaletteFromModeConfig(
      ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.light,
      ),
      AppAdvancedThemeModeConfig(
        colors: const AppAdvancedThemeColors(primaryColorValue: 0xFF3366FF),
      ),
    );
    final darkPalette = resolveAdvancedThemePaletteFromModeConfig(
      ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.dark),
      AppAdvancedThemeModeConfig(
        colors: const AppAdvancedThemeColors(primaryColorValue: 0xFF3366FF),
      ),
    );

    final lightArgb = lightPalette.shadowColor.toARGB32();
    final darkArgb = darkPalette.shadowColor.toARGB32();
    final primaryArgb = const Color(0xFF3366FF).toARGB32();

    expect((lightArgb >> 24) & 0xFF, lessThan((darkArgb >> 24) & 0xFF));
    expect((lightArgb >> 16) & 0xFF, (primaryArgb >> 16) & 0xFF);
    expect((darkArgb >> 16) & 0xFF, (primaryArgb >> 16) & 0xFF);
  });
}

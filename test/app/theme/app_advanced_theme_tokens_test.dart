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

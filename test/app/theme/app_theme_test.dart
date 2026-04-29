import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shuxiang_reading_next/app/theme/app_advanced_theme_tokens.dart';
import 'package:shuxiang_reading_next/app/theme/app_theme.dart';
import 'package:shuxiang_reading_next/app/theme/app_theme_palette.dart';
import 'package:shuxiang_reading_next/domain/entities/app_advanced_theme.dart';

void main() {
  test('AppTheme input decoration is transparent by default', () {
    final theme = AppTheme.build(
      ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.light,
      ),
    );

    expect(theme.inputDecorationTheme.filled, isFalse);
    expect(theme.inputDecorationTheme.fillColor, Colors.transparent);
    expect(theme.inputDecorationTheme.enabledBorder, isNotNull);
    expect(theme.inputDecorationTheme.focusedBorder, isNotNull);
  });

  test('light theme keeps seeded accents but neutralizes surface colors', () {
    final lightScheme = buildAppLightColorScheme(const Color(0xFF0F8B8D));
    final tonalSpotScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0F8B8D),
      dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
      brightness: Brightness.light,
    );
    final neutralSurfaceScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF9E9E9E),
      dynamicSchemeVariant: DynamicSchemeVariant.neutral,
      brightness: Brightness.light,
    );

    expect(lightScheme.primary, tonalSpotScheme.primary);
    expect(lightScheme.surface, neutralSurfaceScheme.surface);
    expect(
      lightScheme.surfaceContainerLow,
      neutralSurfaceScheme.surfaceContainerLow,
    );
    expect(
      lightScheme.surfaceContainerHighest,
      neutralSurfaceScheme.surfaceContainerHighest,
    );
    expect(lightScheme.surfaceTint, Colors.transparent);
  });

  test('pure white seed still produces fully white surfaces', () {
    final lightScheme = buildAppLightColorScheme(const Color(0xFFFFFFFF));

    expect(lightScheme.primary, const Color(0xFF1677FF));
    expect(lightScheme.onPrimary, const Color(0xFFFFFFFF));
    expect(lightScheme.primaryContainer, const Color(0xFFEAF2FF));
    expect(lightScheme.surface, const Color(0xFFFFFFFF));
    expect(lightScheme.surfaceContainerLow, const Color(0xFFFFFFFF));
    expect(lightScheme.surfaceContainerHighest, const Color(0xFFFFFFFF));
    expect(lightScheme.outlineVariant, const Color(0xFFE6E6E6));
    expect(lightScheme.surfaceTint, Colors.transparent);
  });

  test('pure white seed uses default app dark accents', () {
    final darkScheme = buildAppDarkColorScheme(const Color(0xFFFFFFFF));

    expect(darkScheme.primary, const Color(0xFF8EB8FF));
    expect(darkScheme.onPrimary, const Color(0xFF082A5E));
    expect(darkScheme.surface, const Color(0xFF111418));
    expect(darkScheme.surfaceContainerHigh, const Color(0xFF222831));
    expect(darkScheme.surfaceTint, Colors.transparent);
  });

  test('Selune seed applies warm paper light surfaces', () {
    final lightScheme = buildAppLightColorScheme(appThemeSeluneOption.color);

    expect(lightScheme.primary, const Color(0xFFAA8552));
    expect(lightScheme.primaryContainer, const Color(0xFFF2E4CC));
    expect(lightScheme.surface, const Color(0xFFF7F3EC));
    expect(lightScheme.surfaceContainer, const Color(0xFFF2ECE1));
    expect(lightScheme.onSurface, const Color(0xFF1E1A16));
    expect(lightScheme.surfaceTint, Colors.transparent);
  });

  test('Selune seed applies graphite dark surfaces', () {
    final darkScheme = buildAppDarkColorScheme(appThemeSeluneOption.color);

    expect(darkScheme.primary, const Color(0xFFE6CCA0));
    expect(darkScheme.primaryContainer, const Color(0xFF6B5230));
    expect(darkScheme.surface, const Color(0xFF17171C));
    expect(darkScheme.surfaceContainerHigh, const Color(0xFF2A2A32));
    expect(darkScheme.onSurface, const Color(0xFFF5EEE4));
    expect(darkScheme.surfaceTint, Colors.transparent);
  });

  test(
    'advanced theme app bar overlay style follows actual background color',
    () {
      final theme = AppTheme.build(
        ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        advancedPalette: const ResolvedAdvancedThemePalette(
          backgroundColor: Color(0xFF141414),
          surfaceColor: Color(0xFF181818),
          searchFieldBackgroundColor: Color(0xFF222222),
          elevatedSurfaceColor: Color(0xFF202020),
          cardColor: Color(0xFF1C1C1C),
          cardTextColor: Colors.white,
          cardBorderColor: Color(0xFF2F2F2F),
          outlineColor: Color(0xFF3A3A3A),
          iconBackgroundColor: Color(0xFF242424),
          textPrimaryColor: Colors.white,
          textSecondaryColor: Color(0xFFBDBDBD),
          primaryColor: Color(0xFF3D8BFF),
          primaryContainerColor: Color(0xFF16335B),
          secondaryColor: Color(0xFF7CB8FF),
          buttonTextColor: Colors.white,
          shadowColor: Color(0x66000000),
          noticeAccentColor: Color(0xFFFFB74D),
          noticeSurfaceColor: Color(0xFF4A3412),
        ),
        advancedBackdrop: const ResolvedAdvancedThemeBackdrop(
          backgroundColor: Color(0xFF141414),
          surfaceColor: Color(0xFF181818),
          wallpaperPath: null,
          wallpaperOpacity: 1,
          wallpaperBlurSigma: 0,
          wallpaperFit: AppAdvancedThemeWallpaperFit.cover,
          wallpaperOverlayColor: Color(0xFF141414),
          wallpaperOverlayOpacity: 0.32,
        ),
      );

      expect(
        theme.appBarTheme.systemOverlayStyle?.statusBarIconBrightness,
        Brightness.light,
      );
    },
  );
}

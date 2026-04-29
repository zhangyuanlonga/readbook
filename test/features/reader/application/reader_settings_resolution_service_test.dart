import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/app_advanced_theme.dart';
import 'package:shuxiang_reading_next/domain/entities/reader_settings.dart';
import 'package:shuxiang_reading_next/domain/entities/reader_visual_overrides.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_settings_resolution_service.dart';

void main() {
  group('ReaderSettingsResolutionService', () {
    const service = ReaderSettingsResolutionService();

    final theme = AppAdvancedTheme(
      id: 'theme_1',
      name: 'Theme',
      createdAt: DateTime(2026, 4, 29),
      updatedAt: DateTime(2026, 4, 29),
      lightConfig: AppAdvancedThemeModeConfig(readerWallpaperPath: 'light_bg'),
      darkConfig: AppAdvancedThemeModeConfig(readerWallpaperPath: 'dark_bg'),
      readerFontFamilyKey: 'theme_reader_font',
    );

    test(
      'applies advanced theme visual overlay without mutating base input',
      () {
        const persisted = ReaderSettings(
          backgroundImageBase64: 'base_bg',
          fontSource: ReaderFontSource.system,
          systemFontPreset: ReaderSystemFontPreset.defaultSans,
        );

        final resolved = service.resolve(
          persistedSettings: persisted,
          visualOverrides: ReaderVisualOverrides.empty,
          activeTheme: theme,
          appThemeMode: ThemeMode.light,
          platformBrightness: Brightness.light,
        );

        expect(persisted.backgroundImageBase64, 'base_bg');
        expect(persisted.fontSource, ReaderFontSource.system);
        expect(resolved.backgroundImageBase64, 'light_bg');
        expect(resolved.fontSource, ReaderFontSource.custom);
        expect(resolved.fontFamilyKey, 'theme_reader_font');
        expect(resolved.customFontPath, isNull);
      },
    );

    test(
      'returns persisted visual settings when no advanced theme is active',
      () {
        const persisted = ReaderSettings(
          backgroundImageBase64: 'base_bg',
          fontSource: ReaderFontSource.custom,
          fontFamilyKey: 'base_font',
          backgroundStyle: ReaderBackgroundStyle.paper,
          backgroundTone: ReaderBackgroundTone.containerHigh,
        );

        final resolved = service.resolve(
          persistedSettings: persisted,
          visualOverrides: ReaderVisualOverrides.empty,
          activeTheme: null,
          appThemeMode: ThemeMode.system,
          platformBrightness: Brightness.dark,
        );

        expect(resolved.backgroundImageBase64, 'base_bg');
        expect(resolved.fontSource, ReaderFontSource.custom);
        expect(resolved.fontFamilyKey, 'base_font');
        expect(resolved.backgroundStyle, ReaderBackgroundStyle.paper);
        expect(resolved.backgroundTone, ReaderBackgroundTone.containerHigh);
      },
    );

    test('manual background and font overrides win over advanced theme', () {
      const persisted = ReaderSettings(
        backgroundImageBase64: 'base_bg',
        fontSource: ReaderFontSource.system,
        systemFontPreset: ReaderSystemFontPreset.defaultSans,
      );
      const overrides = ReaderVisualOverrides(
        hasBackgroundImageOverride: true,
        backgroundImageBase64: 'manual_bg',
        fontSource: ReaderFontSource.system,
        systemFontPreset: ReaderSystemFontPreset.monospace,
        hasFontFamilyKeyOverride: true,
        hasCustomFontPathOverride: true,
      );

      final resolved = service.resolve(
        persistedSettings: persisted,
        visualOverrides: overrides,
        activeTheme: theme,
        appThemeMode: ThemeMode.dark,
        platformBrightness: Brightness.dark,
      );

      expect(resolved.backgroundImageBase64, 'manual_bg');
      expect(resolved.fontSource, ReaderFontSource.system);
      expect(resolved.systemFontPreset, ReaderSystemFontPreset.monospace);
      expect(resolved.fontFamilyKey, isNull);
      expect(resolved.customFontPath, isNull);
    });

    test(
      'manual visual overrides still apply after advanced theme is removed',
      () {
        const persisted = ReaderSettings(
          backgroundImageBase64: 'base_bg',
          fontSource: ReaderFontSource.system,
        );
        const overrides = ReaderVisualOverrides(
          hasBackgroundImageOverride: true,
          backgroundImageBase64: 'manual_bg',
          fontSource: ReaderFontSource.custom,
          hasFontFamilyKeyOverride: true,
          fontFamilyKey: 'manual_font',
          hasCustomFontPathOverride: true,
        );

        final resolved = service.resolve(
          persistedSettings: persisted,
          visualOverrides: overrides,
          activeTheme: null,
          appThemeMode: ThemeMode.light,
          platformBrightness: Brightness.light,
        );

        expect(resolved.backgroundImageBase64, 'manual_bg');
        expect(resolved.fontSource, ReaderFontSource.custom);
        expect(resolved.fontFamilyKey, 'manual_font');
        expect(resolved.customFontPath, isNull);
      },
    );

    test('clearing overrides restores advanced theme visual output', () {
      const persisted = ReaderSettings(
        backgroundImageBase64: 'base_bg',
        fontSource: ReaderFontSource.system,
      );

      final resolved = service.resolve(
        persistedSettings: persisted,
        visualOverrides: ReaderVisualOverrides.empty,
        activeTheme: theme,
        appThemeMode: ThemeMode.dark,
        platformBrightness: Brightness.dark,
      );

      expect(resolved.backgroundImageBase64, 'dark_bg');
      expect(resolved.fontSource, ReaderFontSource.custom);
      expect(resolved.fontFamilyKey, 'theme_reader_font');
      expect(resolved.customFontPath, isNull);
    });
  });
}

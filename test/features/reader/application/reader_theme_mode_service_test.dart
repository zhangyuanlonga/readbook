import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/reader_settings.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_theme_mode_service.dart';

void main() {
  group('ReaderThemeModeService', () {
    const service = ReaderThemeModeService();

    test('switches light mode to dark mode and preserves background image', () {
      final result = service.buildToggleResult(
        settings: const ReaderSettings(
          themeMode: ReaderThemeMode.light,
          backgroundImageBase64: 'abc',
        ),
        lightModeBackgroundImageBackup: null,
      );

      expect(result.nextSettings.themeMode, ReaderThemeMode.dark);
      expect(
        result.nextSettings.backgroundTone,
        ReaderBackgroundTone.pureBlack,
      );
      expect(result.nextSettings.backgroundImageBase64, 'abc');
      expect(result.nextAppThemeMode, ThemeMode.dark);
      expect(result.nextLightModeBackgroundImageBackup, 'abc');
    });

    test('switches dark mode back to light mode with restored backup', () {
      final result = service.buildToggleResult(
        settings: const ReaderSettings(themeMode: ReaderThemeMode.dark),
        lightModeBackgroundImageBackup: 'light-bg',
      );

      expect(result.nextSettings.themeMode, ReaderThemeMode.light);
      expect(result.nextSettings.backgroundImageBase64, 'light-bg');
      expect(result.nextAppThemeMode, ThemeMode.light);
    });
  });
}

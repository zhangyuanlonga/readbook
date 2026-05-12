import 'package:flutter/material.dart';

import '../../../domain/entities/reader_settings.dart';

class ReaderThemeModeToggleResult {
  const ReaderThemeModeToggleResult({
    required this.nextSettings,
    required this.nextAppThemeMode,
    this.nextLightModeBackgroundImageBackup,
  });

  final ReaderSettings nextSettings;
  final ThemeMode nextAppThemeMode;
  final String? nextLightModeBackgroundImageBackup;
}

class ReaderThemeModeService {
  const ReaderThemeModeService();

  ReaderThemeModeToggleResult buildToggleResult({
    required ReaderSettings settings,
    required String? lightModeBackgroundImageBackup,
  }) {
    final isDarkMode = settings.themeMode == ReaderThemeMode.dark;
    final currentBackgroundImage = settings.backgroundImageBase64?.trim();
    final nextBackup =
        !isDarkMode &&
                currentBackgroundImage != null &&
                currentBackgroundImage.isNotEmpty
            ? currentBackgroundImage
            : lightModeBackgroundImageBackup;

    final nextSettings = switch (isDarkMode) {
      true => settings.copyWith(
        themeMode: ReaderThemeMode.light,
        backgroundStyle: ReaderBackgroundStyle.plain,
        backgroundTone: ReaderBackgroundTone.surface,
        backgroundImageBase64:
            (settings.backgroundImageBase64?.trim().isEmpty ?? true)
                ? nextBackup
                : settings.backgroundImageBase64,
      ),
      false => settings.copyWith(
        themeMode: ReaderThemeMode.dark,
        backgroundStyle: ReaderBackgroundStyle.plain,
        backgroundTone: ReaderBackgroundTone.pureBlack,
      ),
    };

    return ReaderThemeModeToggleResult(
      nextSettings: nextSettings,
      nextAppThemeMode: isDarkMode ? ThemeMode.light : ThemeMode.dark,
      nextLightModeBackgroundImageBackup: nextBackup,
    );
  }
}

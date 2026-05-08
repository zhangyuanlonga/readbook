import 'package:flutter/material.dart';

import '../../../domain/entities/app_advanced_theme.dart';
import '../../../domain/entities/reader_settings.dart';
import '../../../domain/entities/reader_visual_overrides.dart';

class ReaderSettingsResolutionService {
  const ReaderSettingsResolutionService();

  ReaderSettings resolve({
    required ReaderSettings persistedSettings,
    required ReaderVisualOverrides visualOverrides,
    required AppAdvancedTheme? activeTheme,
    required ThemeMode appThemeMode,
    required Brightness platformBrightness,
  }) {
    var resolved = synchronizeThemeModeWithAppShell(
      settings: persistedSettings,
      appThemeMode: appThemeMode,
      platformBrightness: platformBrightness,
    );
    resolved = applyAdvancedThemeVisualOverlay(
      settings: resolved,
      activeTheme: activeTheme,
      appThemeMode: appThemeMode,
      platformBrightness: platformBrightness,
    );
    return applyVisualOverrides(
      settings: resolved,
      visualOverrides: visualOverrides,
      activeTheme: activeTheme,
      appThemeMode: appThemeMode,
      platformBrightness: platformBrightness,
    );
  }

  ReaderSettings synchronizeThemeModeWithAppShell({
    required ReaderSettings settings,
    required ThemeMode appThemeMode,
    required Brightness platformBrightness,
  }) {
    if (settings.themeMode == ReaderThemeMode.sepia) {
      return settings;
    }
    final targetMode = _resolveReaderThemeMode(
      appThemeMode: appThemeMode,
      platformBrightness: platformBrightness,
    );
    if (settings.themeMode == targetMode) {
      return settings;
    }
    return settings.copyWith(themeMode: targetMode);
  }

  ReaderSettings applyAdvancedThemeVisualOverlay({
    required ReaderSettings settings,
    required AppAdvancedTheme? activeTheme,
    required ThemeMode appThemeMode,
    required Brightness platformBrightness,
  }) {
    if (activeTheme == null) {
      return settings;
    }
    var resolved = settings;
    final readerFontFamilyKey = resolveThemeReaderFontFamilyKey(activeTheme);
    if (readerFontFamilyKey != null) {
      resolved = resolved.copyWith(
        fontSource: ReaderFontSource.custom,
        fontFamilyKey: readerFontFamilyKey,
        clearCustomFontPath: true,
      );
    }
    final readerBackgroundPath = resolveThemeReaderBackgroundPath(
      activeTheme: activeTheme,
      appThemeMode: appThemeMode,
      platformBrightness: platformBrightness,
    );
    if (readerBackgroundPath != null) {
      resolved = resolved.copyWith(backgroundImageBase64: readerBackgroundPath);
    }
    return resolved;
  }

  ReaderSettings applyVisualOverrides({
    required ReaderSettings settings,
    required ReaderVisualOverrides visualOverrides,
    required AppAdvancedTheme? activeTheme,
    required ThemeMode appThemeMode,
    required Brightness platformBrightness,
  }) {
    var resolved = settings;
    if (visualOverrides.hasBackgroundImageOverride) {
      final backgroundValue = visualOverrides.backgroundImageBase64?.trim();
      resolved = resolved.copyWith(
        backgroundImageBase64: backgroundValue,
        clearBackgroundImage:
            backgroundValue == null || backgroundValue.isEmpty,
      );
    }

    if (visualOverrides.hasFontBindingOverride) {
      resolved = resolved.copyWith(
        fontSource: visualOverrides.fontSource ?? resolved.fontSource,
        systemFontPreset:
            visualOverrides.systemFontPreset ?? resolved.systemFontPreset,
        fontFamilyKey: visualOverrides.fontFamilyKey,
        clearFontFamilyKey:
            visualOverrides.hasFontFamilyKeyOverride &&
            ((visualOverrides.fontFamilyKey?.trim().isEmpty ?? true)),
        customFontPath: visualOverrides.customFontPath,
        clearCustomFontPath:
            visualOverrides.hasCustomFontPathOverride &&
            ((visualOverrides.customFontPath?.trim().isEmpty ?? true)),
      );
      if (visualOverrides.fontSource == ReaderFontSource.system ||
          visualOverrides.fontSource == ReaderFontSource.builtin) {
        resolved = resolved.copyWith(
          clearFontFamilyKey: true,
          clearCustomFontPath: true,
        );
      }
    }

    return resolved;
  }

  String? resolveThemeReaderFontFamilyKey(AppAdvancedTheme? activeTheme) {
    final normalized = activeTheme?.readerFontFamilyKey?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  String? resolveThemeReaderBackgroundPath({
    required AppAdvancedTheme? activeTheme,
    required ThemeMode appThemeMode,
    required Brightness platformBrightness,
  }) {
    if (activeTheme == null) {
      return null;
    }
    final mode = _resolveAdvancedThemeMode(
      appThemeMode: appThemeMode,
      platformBrightness: platformBrightness,
    );
    final path = activeTheme.configFor(mode).readerWallpaperPath?.trim();
    if (path == null || path.isEmpty) {
      return null;
    }
    return path;
  }

  AppAdvancedThemeMode _resolveAdvancedThemeMode({
    required ThemeMode appThemeMode,
    required Brightness platformBrightness,
  }) {
    final brightness = _resolveBrightness(
      appThemeMode: appThemeMode,
      platformBrightness: platformBrightness,
    );
    return brightness == Brightness.dark
        ? AppAdvancedThemeMode.dark
        : AppAdvancedThemeMode.light;
  }

  ReaderThemeMode _resolveReaderThemeMode({
    required ThemeMode appThemeMode,
    required Brightness platformBrightness,
  }) {
    final brightness = _resolveBrightness(
      appThemeMode: appThemeMode,
      platformBrightness: platformBrightness,
    );
    return brightness == Brightness.dark
        ? ReaderThemeMode.dark
        : ReaderThemeMode.light;
  }

  Brightness _resolveBrightness({
    required ThemeMode appThemeMode,
    required Brightness platformBrightness,
  }) {
    final brightness = switch (appThemeMode) {
      ThemeMode.dark => Brightness.dark,
      ThemeMode.light => Brightness.light,
      ThemeMode.system => platformBrightness,
    };
    return brightness;
  }
}

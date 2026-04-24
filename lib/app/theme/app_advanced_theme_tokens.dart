import 'package:flutter/material.dart';

import '../../domain/entities/app_advanced_theme.dart';

class ResolvedAdvancedThemePalette {
  const ResolvedAdvancedThemePalette({
    required this.backgroundColor,
    required this.surfaceColor,
    required this.searchFieldBackgroundColor,
    required this.elevatedSurfaceColor,
    required this.cardColor,
    required this.cardTextColor,
    required this.cardBorderColor,
    required this.outlineColor,
    required this.iconBackgroundColor,
    required this.textPrimaryColor,
    required this.textSecondaryColor,
    required this.primaryColor,
    required this.primaryContainerColor,
    required this.secondaryColor,
    required this.buttonTextColor,
    required this.shadowColor,
    required this.noticeAccentColor,
    required this.noticeSurfaceColor,
  });

  final Color backgroundColor;
  final Color surfaceColor;
  final Color searchFieldBackgroundColor;
  final Color elevatedSurfaceColor;
  final Color cardColor;
  final Color cardTextColor;
  final Color cardBorderColor;
  final Color outlineColor;
  final Color iconBackgroundColor;
  final Color textPrimaryColor;
  final Color textSecondaryColor;
  final Color primaryColor;
  final Color primaryContainerColor;
  final Color secondaryColor;
  final Color buttonTextColor;
  final Color shadowColor;
  final Color noticeAccentColor;
  final Color noticeSurfaceColor;
}

class ResolvedAdvancedThemeBackdrop {
  const ResolvedAdvancedThemeBackdrop({
    required this.backgroundColor,
    required this.surfaceColor,
    required this.wallpaperPath,
    required this.wallpaperOpacity,
    required this.wallpaperBlurSigma,
    required this.wallpaperFit,
    required this.wallpaperOverlayColor,
    required this.wallpaperOverlayOpacity,
  });

  final Color backgroundColor;
  final Color surfaceColor;
  final String? wallpaperPath;
  final double wallpaperOpacity;
  final double wallpaperBlurSigma;
  final AppAdvancedThemeWallpaperFit wallpaperFit;
  final Color wallpaperOverlayColor;
  final double wallpaperOverlayOpacity;
}

ResolvedAdvancedThemePalette resolveAdvancedThemePalette(
  ColorScheme colorScheme,
  AppAdvancedTheme? activeTheme,
) {
  final modeConfig = _modeConfigForActiveTheme(colorScheme, activeTheme);
  return resolveAdvancedThemePaletteFromModeConfig(colorScheme, modeConfig);
}

ResolvedAdvancedThemePalette resolveAdvancedThemePaletteFromModeConfig(
  ColorScheme colorScheme,
  AppAdvancedThemeModeConfig? modeConfig,
) {
  final colors = modeConfig?.colors;

  return ResolvedAdvancedThemePalette(
    backgroundColor:
        colors?.backgroundColorValue != null
            ? Color(colors!.backgroundColorValue!)
            : colorScheme.surface,
    surfaceColor:
        colors?.surfaceColorValue != null
            ? Color(colors!.surfaceColorValue!)
            : colorScheme.surfaceContainerLow,
    searchFieldBackgroundColor:
        colors?.searchFieldBackgroundColorValue != null
            ? Color(colors!.searchFieldBackgroundColorValue!)
            : colorScheme.surfaceContainerHighest,
    elevatedSurfaceColor:
        colors?.elevatedSurfaceColorValue != null
            ? Color(colors!.elevatedSurfaceColorValue!)
            : colorScheme.surfaceContainerHigh,
    cardColor:
        colors?.cardColorValue != null
            ? Color(colors!.cardColorValue!)
            : colorScheme.surface,
    cardTextColor:
        colors?.cardTextColorValue != null
            ? Color(colors!.cardTextColorValue!)
            : (colors?.textPrimaryColorValue != null
                ? Color(colors!.textPrimaryColorValue!)
                : colorScheme.onSurface),
    cardBorderColor:
        colors?.cardBorderColorValue != null
            ? Color(colors!.cardBorderColorValue!)
            : colorScheme.outlineVariant,
    outlineColor:
        colors?.outlineColorValue != null
            ? Color(colors!.outlineColorValue!)
            : colorScheme.outline,
    iconBackgroundColor:
        colors?.iconBackgroundColorValue != null
            ? Color(colors!.iconBackgroundColorValue!)
            : Color.alphaBlend(
              colorScheme.onSurface.withValues(alpha: 0.04),
              colorScheme.surface,
            ),
    textPrimaryColor:
        colors?.textPrimaryColorValue != null
            ? Color(colors!.textPrimaryColorValue!)
            : colorScheme.onSurface,
    textSecondaryColor:
        colors?.textSecondaryColorValue != null
            ? Color(colors!.textSecondaryColorValue!)
            : colorScheme.onSurfaceVariant,
    primaryColor:
        colors?.primaryColorValue != null
            ? Color(colors!.primaryColorValue!)
            : colorScheme.primary,
    primaryContainerColor:
        colors?.primaryContainerColorValue != null
            ? Color(colors!.primaryContainerColorValue!)
            : colorScheme.primaryContainer,
    secondaryColor:
        colors?.secondaryColorValue != null
            ? Color(colors!.secondaryColorValue!)
            : colorScheme.secondary,
    buttonTextColor:
        colors?.buttonTextColorValue != null
            ? Color(colors!.buttonTextColorValue!)
            : colorScheme.onPrimary,
    shadowColor:
        colors?.shadowColorValue != null
            ? Color(colors!.shadowColorValue!)
            : colorScheme.shadow.withValues(
              alpha: colorScheme.brightness == Brightness.dark ? 0.22 : 0.12,
            ),
    noticeAccentColor:
        colors?.noticeAccentColorValue != null
            ? Color(colors!.noticeAccentColorValue!)
            : colorScheme.tertiary,
    noticeSurfaceColor:
        colors?.noticeSurfaceColorValue != null
            ? Color(colors!.noticeSurfaceColorValue!)
            : colorScheme.tertiaryContainer,
  );
}

ResolvedAdvancedThemeBackdrop resolveAdvancedThemeBackdrop(
  ColorScheme colorScheme,
  AppAdvancedTheme? activeTheme,
) {
  final modeConfig = _modeConfigForActiveTheme(colorScheme, activeTheme);
  return resolveAdvancedThemeBackdropFromModeConfig(colorScheme, modeConfig);
}

ResolvedAdvancedThemeBackdrop resolveAdvancedThemeBackdropFromModeConfig(
  ColorScheme colorScheme,
  AppAdvancedThemeModeConfig? modeConfig,
) {
  final colors = modeConfig?.colors;

  return ResolvedAdvancedThemeBackdrop(
    backgroundColor:
        colors?.backgroundColorValue != null
            ? Color(colors!.backgroundColorValue!)
            : colorScheme.surface,
    surfaceColor:
        colors?.surfaceColorValue != null
            ? Color(colors!.surfaceColorValue!)
            : colorScheme.surfaceContainerLow,
    wallpaperPath: modeConfig?.wallpaperPath?.trim(),
    wallpaperOpacity: modeConfig?.wallpaperOpacity ?? 1,
    wallpaperBlurSigma: modeConfig?.wallpaperBlurSigma ?? 0,
    wallpaperFit:
        modeConfig?.wallpaperFit ?? AppAdvancedThemeWallpaperFit.cover,
    wallpaperOverlayColor:
        colors?.wallpaperOverlayColorValue != null
            ? Color(colors!.wallpaperOverlayColorValue!)
            : colorScheme.surface,
    wallpaperOverlayOpacity: modeConfig?.wallpaperOverlayOpacity ?? 0.32,
  );
}

AppAdvancedThemeModeConfig? _modeConfigForActiveTheme(
  ColorScheme colorScheme,
  AppAdvancedTheme? activeTheme,
) {
  return switch (activeTheme) {
    null => null,
    _ when colorScheme.brightness == Brightness.dark => activeTheme.darkConfig,
    _ => activeTheme.lightConfig,
  };
}

import 'package:flutter/material.dart';

import '../../domain/entities/app_advanced_theme.dart';

class ResolvedAdvancedThemePalette {
  const ResolvedAdvancedThemePalette({
    required this.backgroundColor,
    required this.surfaceColor,
    required this.elevatedSurfaceColor,
    required this.cardColor,
    required this.cardBorderColor,
    required this.iconBackgroundColor,
    required this.textPrimaryColor,
    required this.textSecondaryColor,
    required this.primaryColor,
    required this.noticeAccentColor,
    required this.noticeSurfaceColor,
  });

  final Color backgroundColor;
  final Color surfaceColor;
  final Color elevatedSurfaceColor;
  final Color cardColor;
  final Color cardBorderColor;
  final Color iconBackgroundColor;
  final Color textPrimaryColor;
  final Color textSecondaryColor;
  final Color primaryColor;
  final Color noticeAccentColor;
  final Color noticeSurfaceColor;
}

class ResolvedAdvancedThemeBackdrop {
  const ResolvedAdvancedThemeBackdrop({
    required this.backgroundColor,
    required this.surfaceColor,
    required this.wallpaperPath,
    required this.wallpaperOverlayColor,
    required this.wallpaperOverlayOpacity,
  });

  final Color backgroundColor;
  final Color surfaceColor;
  final String? wallpaperPath;
  final Color wallpaperOverlayColor;
  final double wallpaperOverlayOpacity;
}

ResolvedAdvancedThemePalette resolveAdvancedThemePalette(
  ColorScheme colorScheme,
  AppAdvancedTheme? activeTheme,
) {
  final modeConfig = switch (activeTheme) {
    null => null,
    _ when colorScheme.brightness == Brightness.dark => activeTheme.darkConfig,
    _ => activeTheme.lightConfig,
  };
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
    elevatedSurfaceColor:
        colors?.elevatedSurfaceColorValue != null
            ? Color(colors!.elevatedSurfaceColorValue!)
            : colorScheme.surfaceContainerHigh,
    cardColor:
        colors?.cardColorValue != null
            ? Color(colors!.cardColorValue!)
            : colorScheme.surface,
    cardBorderColor:
        colors?.cardBorderColorValue != null
            ? Color(colors!.cardBorderColorValue!)
            : colorScheme.outlineVariant,
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
  final modeConfig = switch (activeTheme) {
    null => null,
    _ when colorScheme.brightness == Brightness.dark => activeTheme.darkConfig,
    _ => activeTheme.lightConfig,
  };
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
    wallpaperOverlayColor:
        colors?.wallpaperOverlayColorValue != null
            ? Color(colors!.wallpaperOverlayColorValue!)
            : colorScheme.surface,
    wallpaperOverlayOpacity: modeConfig?.wallpaperOverlayOpacity ?? 0.32,
  );
}

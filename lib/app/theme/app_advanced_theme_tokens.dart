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
    required this.dividerColor,
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
  final Color dividerColor;
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
  final backgroundColor = _resolveColor(
    colors?.backgroundColorValue,
    fallback: colorScheme.surface,
  );
  final surfaceColor = _resolveColor(
    colors?.surfaceColorValue,
    fallback: colorScheme.surfaceContainerLow,
  );
  final cardColor = _resolveColor(
    colors?.cardColorValue,
    fallback: colorScheme.surface,
  );
  final primaryColor = _resolveColor(
    colors?.primaryColorValue,
    fallback: colorScheme.primary,
  );
  final outlineColor = _resolveColor(
    colors?.outlineColorValue,
    fallback: colorScheme.outline,
  );
  final textPrimaryColor =
      colors?.textPrimaryColorValue != null
          ? Color(colors!.textPrimaryColorValue!)
          : _resolveReadableOnColor(<Color>[
            backgroundColor,
            surfaceColor,
            cardColor,
          ]);
  final textSecondaryColor =
      colors?.textSecondaryColorValue != null
          ? Color(colors!.textSecondaryColorValue!)
          : _resolveMutedTextColor(
            foreground: textPrimaryColor,
            background: surfaceColor,
          );
  final searchFieldBackgroundColor =
      colors?.searchFieldBackgroundColorValue != null
          ? Color(colors!.searchFieldBackgroundColorValue!)
          : _resolveSearchFieldBackgroundColor(
            surfaceColor: surfaceColor,
            textPrimaryColor: textPrimaryColor,
          );
  final elevatedSurfaceColor =
      colors?.elevatedSurfaceColorValue != null
          ? Color(colors!.elevatedSurfaceColorValue!)
          : _resolveElevatedSurfaceColor(
            surfaceColor: surfaceColor,
            cardColor: cardColor,
            brightness: colorScheme.brightness,
          );
  final cardTextColor =
      colors?.cardTextColorValue != null
          ? Color(colors!.cardTextColorValue!)
          : _resolveReadableOnColor(
            <Color>[cardColor],
            fallbackLight: textPrimaryColor,
            fallbackDark: textPrimaryColor,
          );
  final primaryContainerColor =
      colors?.primaryContainerColorValue != null
          ? Color(colors!.primaryContainerColorValue!)
          : _resolvePrimaryContainerColor(
            primaryColor: primaryColor,
            surfaceColor: surfaceColor,
          );
  final secondaryColor =
      colors?.secondaryColorValue != null
          ? Color(colors!.secondaryColorValue!)
          : _resolveSecondaryColor(
            primaryColor: primaryColor,
            surfaceColor: surfaceColor,
          );
  final buttonTextColor =
      colors?.buttonTextColorValue != null
          ? Color(colors!.buttonTextColorValue!)
          : _resolveReadableOnColor(<Color>[primaryColor]);
  final cardBorderColor =
      colors?.cardBorderColorValue != null
          ? Color(colors!.cardBorderColorValue!)
          : _resolveCardBorderColor(
            outlineColor: outlineColor,
            cardColor: cardColor,
          );
  final dividerColor =
      colors?.dividerColorValue != null
          ? Color(colors!.dividerColorValue!)
          : cardBorderColor;
  final iconBackgroundColor =
      colors?.iconBackgroundColorValue != null
          ? Color(colors!.iconBackgroundColorValue!)
          : _resolveIconBackgroundColor(
            foreground: textPrimaryColor,
            surface: surfaceColor,
          );
  final shadowColor =
      colors?.shadowColorValue != null
          ? _resolveShadowColor(
            baseColor: Color(colors!.shadowColorValue!),
            brightness: colorScheme.brightness,
            preserveExplicitAlpha: true,
          )
          : _resolveShadowColor(
            baseColor: primaryColor,
            brightness: colorScheme.brightness,
          );
  final noticeAccentColor = _resolveColor(
    colors?.noticeAccentColorValue,
    fallback: colorScheme.tertiary,
  );
  final noticeSurfaceColor = _resolveColor(
    colors?.noticeSurfaceColorValue,
    fallback: colorScheme.tertiaryContainer,
  );

  return ResolvedAdvancedThemePalette(
    backgroundColor: backgroundColor,
    surfaceColor: surfaceColor,
    searchFieldBackgroundColor: searchFieldBackgroundColor,
    elevatedSurfaceColor: elevatedSurfaceColor,
    cardColor: cardColor,
    cardTextColor: cardTextColor,
    cardBorderColor: cardBorderColor,
    dividerColor: dividerColor,
    outlineColor: outlineColor,
    iconBackgroundColor: iconBackgroundColor,
    textPrimaryColor: textPrimaryColor,
    textSecondaryColor: textSecondaryColor,
    primaryColor: primaryColor,
    primaryContainerColor: primaryContainerColor,
    secondaryColor: secondaryColor,
    buttonTextColor: buttonTextColor,
    shadowColor: shadowColor,
    noticeAccentColor: noticeAccentColor,
    noticeSurfaceColor: noticeSurfaceColor,
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
            : _resolveWallpaperOverlayColor(
              backgroundColor:
                  colors?.backgroundColorValue != null
                      ? Color(colors!.backgroundColorValue!)
                      : colorScheme.surface,
            ),
    wallpaperOverlayOpacity:
        modeConfig?.wallpaperOverlayOpacity ??
        _defaultWallpaperOverlayOpacity(colorScheme.brightness),
  );
}

AppAdvancedThemeModeConfig buildDefaultAdvancedThemeModeConfig(
  ColorScheme colorScheme,
) {
  return AppAdvancedThemeModeConfig(
    colors: AppAdvancedThemeColors(
      primaryColorValue: colorScheme.primary.toARGB32(),
      secondaryColorValue: colorScheme.secondary.toARGB32(),
      noticeAccentColorValue: colorScheme.tertiary.toARGB32(),
      noticeSurfaceColorValue: colorScheme.tertiaryContainer.toARGB32(),
      primaryContainerColorValue: colorScheme.primaryContainer.toARGB32(),
      backgroundColorValue: colorScheme.surface.toARGB32(),
      surfaceColorValue: colorScheme.surfaceContainerLow.toARGB32(),
      searchFieldBackgroundColorValue:
          colorScheme.surfaceContainerHighest.toARGB32(),
      elevatedSurfaceColorValue: colorScheme.surfaceContainerHigh.toARGB32(),
      cardColorValue: colorScheme.surface.toARGB32(),
      cardTextColorValue: colorScheme.onSurface.toARGB32(),
      cardBorderColorValue: colorScheme.outlineVariant.toARGB32(),
      dividerColorValue: colorScheme.outlineVariant.toARGB32(),
      iconBackgroundColorValue:
          Color.alphaBlend(
            colorScheme.onSurface.withValues(alpha: 0.04),
            colorScheme.surface,
          ).toARGB32(),
      textPrimaryColorValue: colorScheme.onSurface.toARGB32(),
      textSecondaryColorValue: colorScheme.onSurfaceVariant.toARGB32(),
      buttonTextColorValue: colorScheme.onPrimary.toARGB32(),
      outlineColorValue: colorScheme.outline.toARGB32(),
      shadowColorValue: colorScheme.primary.withValues(alpha: 0.18).toARGB32(),
      wallpaperOverlayColorValue: colorScheme.surface.toARGB32(),
    ),
    readerWallpaperOverlayOpacity: 0,
    wallpaperOverlayOpacity:
        colorScheme.brightness == Brightness.dark ? 0.46 : 0.28,
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

Color _resolveReadableOnColor(
  List<Color> backgrounds, {
  Color fallbackLight = Colors.white,
  Color fallbackDark = const Color(0xFF111111),
}) {
  final candidates = <Color>[fallbackLight, fallbackDark];
  Color? bestColor;
  var bestScore = -1.0;
  for (final candidate in candidates) {
    final score = backgrounds.fold<double>(double.infinity, (
      current,
      background,
    ) {
      final next = _contrastRatio(candidate, background);
      return current < next ? current : next;
    });
    if (score > bestScore) {
      bestScore = score;
      bestColor = candidate;
    }
  }
  return bestColor ?? fallbackDark;
}

Color _resolveMutedTextColor({
  required Color foreground,
  required Color background,
}) {
  final alpha =
      ThemeData.estimateBrightnessForColor(background) == Brightness.dark
          ? 0.72
          : 0.62;
  return Color.alphaBlend(foreground.withValues(alpha: alpha), background);
}

Color _resolveColor(int? value, {required Color fallback}) {
  if (value == null) {
    return fallback;
  }
  return Color(value);
}

Color _resolveSearchFieldBackgroundColor({
  required Color surfaceColor,
  required Color textPrimaryColor,
}) {
  return Color.alphaBlend(
    textPrimaryColor.withValues(alpha: 0.035),
    surfaceColor,
  );
}

Color _resolveElevatedSurfaceColor({
  required Color surfaceColor,
  required Color cardColor,
  required Brightness brightness,
}) {
  final liftAlpha = brightness == Brightness.dark ? 0.08 : 0.04;
  return Color.alphaBlend(
    _resolveReadableOnColor(<Color>[cardColor]).withValues(alpha: liftAlpha),
    surfaceColor,
  );
}

Color _resolvePrimaryContainerColor({
  required Color primaryColor,
  required Color surfaceColor,
}) {
  return Color.alphaBlend(primaryColor.withValues(alpha: 0.18), surfaceColor);
}

Color _resolveSecondaryColor({
  required Color primaryColor,
  required Color surfaceColor,
}) {
  return Color.alphaBlend(primaryColor.withValues(alpha: 0.72), surfaceColor);
}

Color _resolveCardBorderColor({
  required Color outlineColor,
  required Color cardColor,
}) {
  return Color.alphaBlend(outlineColor.withValues(alpha: 0.72), cardColor);
}

Color _resolveIconBackgroundColor({
  required Color foreground,
  required Color surface,
}) {
  return Color.alphaBlend(foreground.withValues(alpha: 0.06), surface);
}

Color _resolveShadowColor({
  required Color baseColor,
  required Brightness brightness,
  bool preserveExplicitAlpha = false,
}) {
  if (preserveExplicitAlpha && baseColor.a < 1) {
    return baseColor;
  }
  final alpha = brightness == Brightness.dark ? 0.26 : 0.16;
  return baseColor.withValues(alpha: alpha);
}

Color _resolveWallpaperOverlayColor({required Color backgroundColor}) {
  final overlayBase = _resolveReadableOnColor(<Color>[backgroundColor]);
  return Color.alphaBlend(overlayBase.withValues(alpha: 0.08), backgroundColor);
}

double _defaultWallpaperOverlayOpacity(Brightness brightness) {
  return brightness == Brightness.dark ? 0.46 : 0.28;
}

double _contrastRatio(Color foreground, Color background) {
  final foregroundLuminance = foreground.computeLuminance();
  final backgroundLuminance = background.computeLuminance();
  final lighter =
      foregroundLuminance > backgroundLuminance
          ? foregroundLuminance
          : backgroundLuminance;
  final darker =
      foregroundLuminance > backgroundLuminance
          ? backgroundLuminance
          : foregroundLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_advanced_theme_tokens.dart';
import 'app_border_tokens.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData build(
    ColorScheme colorScheme, {
    ResolvedAdvancedThemePalette? advancedPalette,
    ResolvedAdvancedThemeBackdrop? advancedBackdrop,
    String? fontFamily,
    FontWeight? fontWeight,
  }) {
    final effectiveColorScheme =
        advancedPalette == null || advancedBackdrop == null
            ? colorScheme
            : _applyAdvancedThemeColorScheme(
              colorScheme,
              palette: advancedPalette,
              backdrop: advancedBackdrop,
            );
    final overlayStyle = _overlayStyleFor(effectiveColorScheme.brightness);
    final scaffoldBackgroundColor =
        advancedBackdrop?.backgroundColor ?? effectiveColorScheme.surface;
    final appBarBackgroundColor = scaffoldBackgroundColor;
    final appBarForegroundColor =
        advancedPalette?.textPrimaryColor ?? effectiveColorScheme.onSurface;
    final cardColor =
        advancedPalette?.cardColor ?? effectiveColorScheme.surface;

    final baseTheme = ThemeData(
      useMaterial3: true,
      colorScheme: effectiveColorScheme,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: scaffoldBackgroundColor,
      visualDensity: const VisualDensity(horizontal: -0.2, vertical: -0.2),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: appBarBackgroundColor,
        foregroundColor: appBarForegroundColor,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: overlayStyle,
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: resolveAppBorderSide(
            effectiveColorScheme,
            containerColor: cardColor,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 40),
          shape: const StadiumBorder(),
          backgroundColor: effectiveColorScheme.primary,
          foregroundColor: effectiveColorScheme.onPrimary,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 40),
          shape: const StadiumBorder(),
          foregroundColor: effectiveColorScheme.onSurface,
          side: resolveAppBorderSide(
            effectiveColorScheme,
            tone: AppBorderTone.strong,
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        fillColor: Colors.transparent,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: resolveAppBorderSide(
            effectiveColorScheme,
            tone: AppBorderTone.subtle,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: resolveAppBorderSide(
            effectiveColorScheme,
            tone: AppBorderTone.defaultTone,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: effectiveColorScheme.primary.withValues(alpha: 0.86),
            width: 1.4,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: effectiveColorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: effectiveColorScheme.error, width: 1.4),
        ),
      ),
    );

    return baseTheme.copyWith(
      textTheme: _applyGlobalFontWeight(baseTheme.textTheme, fontWeight),
      primaryTextTheme: _applyGlobalFontWeight(
        baseTheme.primaryTextTheme,
        fontWeight,
      ),
    );
  }

  static ColorScheme _applyAdvancedThemeColorScheme(
    ColorScheme base, {
    required ResolvedAdvancedThemePalette palette,
    required ResolvedAdvancedThemeBackdrop backdrop,
  }) {
    return base.copyWith(
      primary: palette.primaryColor,
      onPrimary: palette.buttonTextColor,
      primaryContainer: palette.primaryContainerColor,
      onPrimaryContainer: palette.textPrimaryColor,
      secondary: palette.secondaryColor,
      onSecondary: palette.textPrimaryColor,
      secondaryContainer: palette.primaryContainerColor,
      onSecondaryContainer: palette.textPrimaryColor,
      tertiary: palette.noticeAccentColor,
      onTertiary: palette.textPrimaryColor,
      tertiaryContainer: palette.noticeSurfaceColor,
      onTertiaryContainer: palette.textPrimaryColor,
      surface: palette.cardColor,
      surfaceDim: backdrop.backgroundColor,
      surfaceBright: palette.surfaceColor,
      surfaceContainerLowest: backdrop.backgroundColor,
      surfaceContainerLow: palette.surfaceColor,
      surfaceContainer: palette.surfaceColor,
      surfaceContainerHigh: palette.elevatedSurfaceColor,
      surfaceContainerHighest: palette.searchFieldBackgroundColor,
      onSurface: palette.textPrimaryColor,
      onSurfaceVariant: palette.textSecondaryColor,
      surfaceTint: Colors.transparent,
      outline: palette.outlineColor,
      outlineVariant: palette.cardBorderColor,
      shadow: palette.shadowColor,
      scrim: palette.shadowColor.withValues(alpha: 0.52),
    );
  }

  static SystemUiOverlayStyle _overlayStyleFor(Brightness brightness) {
    final base =
        brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark;

    return base.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
    );
  }

  static TextTheme _applyGlobalFontWeight(
    TextTheme theme,
    FontWeight? fontWeight,
  ) {
    if (fontWeight == null) {
      return theme;
    }
    TextStyle? withWeight(TextStyle? style) =>
        style?.copyWith(fontWeight: fontWeight);

    return TextTheme(
      displayLarge: withWeight(theme.displayLarge),
      displayMedium: withWeight(theme.displayMedium),
      displaySmall: withWeight(theme.displaySmall),
      headlineLarge: withWeight(theme.headlineLarge),
      headlineMedium: withWeight(theme.headlineMedium),
      headlineSmall: withWeight(theme.headlineSmall),
      titleLarge: withWeight(theme.titleLarge),
      titleMedium: withWeight(theme.titleMedium),
      titleSmall: withWeight(theme.titleSmall),
      bodyLarge: withWeight(theme.bodyLarge),
      bodyMedium: withWeight(theme.bodyMedium),
      bodySmall: withWeight(theme.bodySmall),
      labelLarge: withWeight(theme.labelLarge),
      labelMedium: withWeight(theme.labelMedium),
      labelSmall: withWeight(theme.labelSmall),
    );
  }
}

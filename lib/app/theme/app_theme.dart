import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData build(
    ColorScheme colorScheme, {
    String? fontFamily,
    FontWeight? fontWeight,
  }) {
    final overlayStyle = _overlayStyleFor(colorScheme.brightness);

    final baseTheme = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: colorScheme.surface,
      visualDensity: const VisualDensity(horizontal: -0.2, vertical: -0.2),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: overlayStyle,
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        surfaceTintColor: colorScheme.surfaceTint,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.45),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 40),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 40),
          shape: const StadiumBorder(),
          side: BorderSide(color: colorScheme.outline),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        fillColor: Colors.transparent,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.82),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: colorScheme.primary.withValues(alpha: 0.86),
            width: 1.4,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.error, width: 1.4),
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
    TextStyle? withWeight(TextStyle? style) => style?.copyWith(
      fontWeight: fontWeight,
    );

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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/entities/app_advanced_theme.dart';
import 'app_advanced_theme_tokens.dart';
import 'app_border_tokens.dart';
import 'app_component_theme_tokens.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData build(
    ColorScheme colorScheme, {
    ResolvedAdvancedThemePalette? advancedPalette,
    ResolvedAdvancedThemeBackdrop? advancedBackdrop,
    AppAdvancedThemeModeConfig? advancedModeConfig,
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
    final scaffoldBackgroundColor =
        advancedBackdrop?.backgroundColor ?? effectiveColorScheme.surface;
    final appBarBackgroundColor = scaffoldBackgroundColor;
    final appBarForegroundColor =
        advancedPalette?.textPrimaryColor ?? effectiveColorScheme.onSurface;
    final cardColor =
        advancedPalette?.cardColor ?? effectiveColorScheme.surface;
    final dividerColor =
        advancedPalette?.dividerColor ?? effectiveColorScheme.outlineVariant;
    final modalSurfaceColor =
        advancedPalette?.surfaceColor ??
        effectiveColorScheme.surfaceContainerLow;
    final componentTokens = resolveAppComponentThemeTokensFromModeConfig(
      effectiveColorScheme,
      modeConfig: advancedModeConfig,
    );
    final selectionColor = effectiveColorScheme.secondary;
    final selectionContainerColor = effectiveColorScheme.secondaryContainer;
    final onSelectionContainerColor = effectiveColorScheme.onSecondaryContainer;
    final buttonShape =
        componentTokens.button.shapeStyle == AppButtonShapeStyle.stadium
            ? const StadiumBorder()
            : RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                componentTokens.button.radius,
              ),
            );
    final overlayShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(componentTokens.overlay.radius),
      side: BorderSide(
        color: effectiveColorScheme.outlineVariant.withValues(alpha: 0.46),
        width: componentTokens.overlay.borderWidth,
      ),
    );
    final overlayStyle = _overlayStyleForColor(appBarBackgroundColor);

    final baseTheme = ThemeData(
      useMaterial3: true,
      colorScheme: effectiveColorScheme,
      extensions: <ThemeExtension<dynamic>>[componentTokens],
      fontFamily: fontFamily,
      scaffoldBackgroundColor: scaffoldBackgroundColor,
      dividerColor: dividerColor,
      visualDensity: const VisualDensity(horizontal: -0.2, vertical: -0.2),
      dividerTheme: DividerThemeData(color: dividerColor, thickness: 1),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: appBarBackgroundColor,
        foregroundColor: appBarForegroundColor,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: overlayStyle,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: modalSurfaceColor,
        surfaceTintColor: Colors.transparent,
        shadowColor: effectiveColorScheme.shadow.withValues(
          alpha: componentTokens.overlay.shadowAlpha,
        ),
        shape: overlayShape,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: modalSurfaceColor,
        modalBackgroundColor: modalSurfaceColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(componentTokens.overlay.topRadius),
          ),
          side: BorderSide(
            color: effectiveColorScheme.outlineVariant.withValues(alpha: 0.46),
            width: componentTokens.overlay.borderWidth,
          ),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: modalSurfaceColor,
        surfaceTintColor: Colors.transparent,
        shadowColor: effectiveColorScheme.shadow.withValues(
          alpha: componentTokens.overlay.shadowAlpha,
        ),
        shape: overlayShape,
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        surfaceTintColor: Colors.transparent,
        elevation: componentTokens.card.elevation,
        shadowColor: effectiveColorScheme.shadow.withValues(
          alpha: componentTokens.card.shadowAlpha,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(componentTokens.card.radius),
          side: resolveAppBorderSide(
            effectiveColorScheme,
            containerColor: cardColor,
          ).copyWith(width: componentTokens.card.borderWidth),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: componentTokens.navigation.standardHeightWithLabel,
      ),
      tabBarTheme: TabBarThemeData(
        dividerColor: Colors.transparent,
        labelColor: effectiveColorScheme.onSecondaryContainer,
        unselectedLabelColor: effectiveColorScheme.onSurfaceVariant,
        indicator: BoxDecoration(
          color: effectiveColorScheme.secondaryContainer.withValues(
            alpha: 0.82,
          ),
          borderRadius: BorderRadius.circular(
            componentTokens.selection.tabIndicatorRadius,
          ),
          border: Border.all(
            color: effectiveColorScheme.outlineVariant.withValues(alpha: 0.5),
            width: componentTokens.selection.chipBorderWidth,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: Size(0, componentTokens.button.height),
          shape: buttonShape,
          padding: EdgeInsets.symmetric(
            horizontal: componentTokens.button.horizontalPadding,
          ),
          backgroundColor: effectiveColorScheme.primary,
          foregroundColor: effectiveColorScheme.onPrimary,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: Size(0, componentTokens.button.height),
          shape: buttonShape,
          padding: EdgeInsets.symmetric(
            horizontal: componentTokens.button.horizontalPadding,
          ),
          foregroundColor: effectiveColorScheme.onSurface,
          side: resolveAppBorderSide(
            effectiveColorScheme,
            tone: AppBorderTone.strong,
          ).copyWith(width: componentTokens.button.outlinedBorderWidth),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: Size(0, componentTokens.button.height),
          shape: buttonShape,
          padding: EdgeInsets.symmetric(
            horizontal: componentTokens.button.horizontalPadding,
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: effectiveColorScheme.surfaceContainerLow,
          foregroundColor: effectiveColorScheme.onSurfaceVariant,
          selectedBackgroundColor: selectionContainerColor.withValues(
            alpha: 0.86,
          ),
          selectedForegroundColor: onSelectionContainerColor,
          side: BorderSide(
            color: effectiveColorScheme.outlineVariant,
            width: componentTokens.selection.segmentBorderWidth,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              componentTokens.selection.segmentRadius,
            ),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: componentTokens.button.horizontalPadding * 0.75,
            vertical: 8,
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: effectiveColorScheme.surfaceContainerLow,
        selectedColor: selectionContainerColor.withValues(alpha: 0.86),
        checkmarkColor: onSelectionContainerColor,
        labelStyle: TextStyle(
          color: effectiveColorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
        secondaryLabelStyle: TextStyle(
          color: onSelectionContainerColor,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            componentTokens.selection.chipRadius,
          ),
          side: BorderSide(
            color: effectiveColorScheme.outlineVariant.withValues(alpha: 0.78),
            width: componentTokens.selection.chipBorderWidth,
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return effectiveColorScheme.onSurface.withValues(alpha: 0.34);
          }
          if (states.contains(WidgetState.selected)) {
            return onSelectionContainerColor;
          }
          return effectiveColorScheme.outline;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return effectiveColorScheme.surfaceContainerHighest.withValues(
              alpha: 0.46,
            );
          }
          if (states.contains(WidgetState.selected)) {
            return selectionContainerColor;
          }
          return effectiveColorScheme.surfaceContainerHighest;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return selectionColor.withValues(alpha: 0.34);
          }
          return effectiveColorScheme.outlineVariant;
        }),
        trackOutlineWidth: WidgetStateProperty.all(
          componentTokens.selection.switchTrackOutlineWidth,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return effectiveColorScheme.surfaceContainerHighest;
          }
          if (states.contains(WidgetState.selected)) {
            return selectionColor;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(effectiveColorScheme.onSecondary),
        side: BorderSide(
          color: effectiveColorScheme.outline,
          width: componentTokens.selection.chipBorderWidth,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: selectionColor,
        inactiveTrackColor: effectiveColorScheme.surfaceContainerHighest,
        thumbColor: selectionColor,
        overlayColor: selectionColor.withValues(alpha: 0.14),
        valueIndicatorColor: effectiveColorScheme.inverseSurface,
        valueIndicatorTextStyle: TextStyle(
          color: effectiveColorScheme.onInverseSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: effectiveColorScheme.surfaceContainerLow.withValues(
          alpha: 0.92,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(componentTokens.input.radius),
          borderSide: resolveAppBorderSide(
            effectiveColorScheme,
            tone: AppBorderTone.subtle,
          ).copyWith(width: componentTokens.input.borderWidth),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(componentTokens.input.radius),
          borderSide: resolveAppBorderSide(
            effectiveColorScheme,
            tone: AppBorderTone.defaultTone,
          ).copyWith(width: componentTokens.input.borderWidth),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(componentTokens.input.radius),
          borderSide: BorderSide(
            color: effectiveColorScheme.primary.withValues(alpha: 0.86),
            width: componentTokens.input.focusedBorderWidth,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(componentTokens.input.radius),
          borderSide: BorderSide(color: effectiveColorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(componentTokens.input.radius),
          borderSide: BorderSide(
            color: effectiveColorScheme.error,
            width: componentTokens.input.focusedBorderWidth,
          ),
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

  static SystemUiOverlayStyle _overlayStyleForColor(Color backgroundColor) {
    final brightness = ThemeData.estimateBrightnessForColor(backgroundColor);
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

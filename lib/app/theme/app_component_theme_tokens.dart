import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../../domain/entities/app_advanced_theme.dart';

enum AppButtonShapeStyle { stadium, rounded }

class AppCardComponentTokens {
  const AppCardComponentTokens({
    required this.radius,
    required this.elevation,
    required this.borderWidth,
    required this.shadowBlur,
    required this.shadowOffsetY,
    required this.shadowAlpha,
  });

  final double radius;
  final double elevation;
  final double borderWidth;
  final double shadowBlur;
  final double shadowOffsetY;
  final double shadowAlpha;

  AppCardComponentTokens copyWith({
    double? radius,
    double? elevation,
    double? borderWidth,
    double? shadowBlur,
    double? shadowOffsetY,
    double? shadowAlpha,
  }) {
    return AppCardComponentTokens(
      radius: radius ?? this.radius,
      elevation: elevation ?? this.elevation,
      borderWidth: borderWidth ?? this.borderWidth,
      shadowBlur: shadowBlur ?? this.shadowBlur,
      shadowOffsetY: shadowOffsetY ?? this.shadowOffsetY,
      shadowAlpha: shadowAlpha ?? this.shadowAlpha,
    );
  }

  static AppCardComponentTokens lerp(
    AppCardComponentTokens a,
    AppCardComponentTokens b,
    double t,
  ) {
    return AppCardComponentTokens(
      radius: lerpDouble(a.radius, b.radius, t)!,
      elevation: lerpDouble(a.elevation, b.elevation, t)!,
      borderWidth: lerpDouble(a.borderWidth, b.borderWidth, t)!,
      shadowBlur: lerpDouble(a.shadowBlur, b.shadowBlur, t)!,
      shadowOffsetY: lerpDouble(a.shadowOffsetY, b.shadowOffsetY, t)!,
      shadowAlpha: lerpDouble(a.shadowAlpha, b.shadowAlpha, t)!,
    );
  }
}

class AppButtonComponentTokens {
  const AppButtonComponentTokens({
    required this.shapeStyle,
    required this.radius,
    required this.height,
    required this.outlinedBorderWidth,
    required this.horizontalPadding,
  });

  final AppButtonShapeStyle shapeStyle;
  final double radius;
  final double height;
  final double outlinedBorderWidth;
  final double horizontalPadding;

  AppButtonComponentTokens copyWith({
    AppButtonShapeStyle? shapeStyle,
    double? radius,
    double? height,
    double? outlinedBorderWidth,
    double? horizontalPadding,
  }) {
    return AppButtonComponentTokens(
      shapeStyle: shapeStyle ?? this.shapeStyle,
      radius: radius ?? this.radius,
      height: height ?? this.height,
      outlinedBorderWidth: outlinedBorderWidth ?? this.outlinedBorderWidth,
      horizontalPadding: horizontalPadding ?? this.horizontalPadding,
    );
  }

  static AppButtonComponentTokens lerp(
    AppButtonComponentTokens a,
    AppButtonComponentTokens b,
    double t,
  ) {
    return AppButtonComponentTokens(
      shapeStyle: t < 0.5 ? a.shapeStyle : b.shapeStyle,
      radius: lerpDouble(a.radius, b.radius, t)!,
      height: lerpDouble(a.height, b.height, t)!,
      outlinedBorderWidth:
          lerpDouble(a.outlinedBorderWidth, b.outlinedBorderWidth, t)!,
      horizontalPadding:
          lerpDouble(a.horizontalPadding, b.horizontalPadding, t)!,
    );
  }
}

class AppInputComponentTokens {
  const AppInputComponentTokens({
    required this.radius,
    required this.borderWidth,
    required this.focusedBorderWidth,
  });

  final double radius;
  final double borderWidth;
  final double focusedBorderWidth;

  AppInputComponentTokens copyWith({
    double? radius,
    double? borderWidth,
    double? focusedBorderWidth,
  }) {
    return AppInputComponentTokens(
      radius: radius ?? this.radius,
      borderWidth: borderWidth ?? this.borderWidth,
      focusedBorderWidth: focusedBorderWidth ?? this.focusedBorderWidth,
    );
  }

  static AppInputComponentTokens lerp(
    AppInputComponentTokens a,
    AppInputComponentTokens b,
    double t,
  ) {
    return AppInputComponentTokens(
      radius: lerpDouble(a.radius, b.radius, t)!,
      borderWidth: lerpDouble(a.borderWidth, b.borderWidth, t)!,
      focusedBorderWidth:
          lerpDouble(a.focusedBorderWidth, b.focusedBorderWidth, t)!,
    );
  }
}

class AppOverlayComponentTokens {
  const AppOverlayComponentTokens({
    required this.radius,
    required this.topRadius,
    required this.backgroundBlurSigma,
    required this.borderWidth,
    required this.shadowBlur,
    required this.shadowOffsetY,
    required this.shadowAlpha,
  });

  final double radius;
  final double topRadius;
  final double backgroundBlurSigma;
  final double borderWidth;
  final double shadowBlur;
  final double shadowOffsetY;
  final double shadowAlpha;

  AppOverlayComponentTokens copyWith({
    double? radius,
    double? topRadius,
    double? backgroundBlurSigma,
    double? borderWidth,
    double? shadowBlur,
    double? shadowOffsetY,
    double? shadowAlpha,
  }) {
    return AppOverlayComponentTokens(
      radius: radius ?? this.radius,
      topRadius: topRadius ?? this.topRadius,
      backgroundBlurSigma: backgroundBlurSigma ?? this.backgroundBlurSigma,
      borderWidth: borderWidth ?? this.borderWidth,
      shadowBlur: shadowBlur ?? this.shadowBlur,
      shadowOffsetY: shadowOffsetY ?? this.shadowOffsetY,
      shadowAlpha: shadowAlpha ?? this.shadowAlpha,
    );
  }

  static AppOverlayComponentTokens lerp(
    AppOverlayComponentTokens a,
    AppOverlayComponentTokens b,
    double t,
  ) {
    return AppOverlayComponentTokens(
      radius: lerpDouble(a.radius, b.radius, t)!,
      topRadius: lerpDouble(a.topRadius, b.topRadius, t)!,
      backgroundBlurSigma:
          lerpDouble(a.backgroundBlurSigma, b.backgroundBlurSigma, t)!,
      borderWidth: lerpDouble(a.borderWidth, b.borderWidth, t)!,
      shadowBlur: lerpDouble(a.shadowBlur, b.shadowBlur, t)!,
      shadowOffsetY: lerpDouble(a.shadowOffsetY, b.shadowOffsetY, t)!,
      shadowAlpha: lerpDouble(a.shadowAlpha, b.shadowAlpha, t)!,
    );
  }
}

class AppNavigationComponentTokens {
  const AppNavigationComponentTokens({
    required this.standardHeightWithLabel,
    required this.standardHeightIconOnly,
    required this.standardFloatingRadius,
    required this.standardBorderWidth,
    required this.standardFloatingShadowBlur,
    required this.standardAttachedShadowBlur,
    required this.standardFloatingShadowOffsetY,
    required this.standardAttachedShadowOffsetY,
    required this.standardFrostedBlurSigmaFloating,
    required this.standardFrostedBlurSigmaAttached,
    required this.dockItemRadius,
    required this.dockSurfaceBorderWidth,
    required this.dockSurfaceShadowBlur,
    required this.dockSurfaceShadowOffsetY,
    required this.dockSearchShadowBlur,
    required this.dockSearchShadowOffsetY,
  });

  final double standardHeightWithLabel;
  final double standardHeightIconOnly;
  final double standardFloatingRadius;
  final double standardBorderWidth;
  final double standardFloatingShadowBlur;
  final double standardAttachedShadowBlur;
  final double standardFloatingShadowOffsetY;
  final double standardAttachedShadowOffsetY;
  final double standardFrostedBlurSigmaFloating;
  final double standardFrostedBlurSigmaAttached;
  final double dockItemRadius;
  final double dockSurfaceBorderWidth;
  final double dockSurfaceShadowBlur;
  final double dockSurfaceShadowOffsetY;
  final double dockSearchShadowBlur;
  final double dockSearchShadowOffsetY;

  AppNavigationComponentTokens copyWith({
    double? standardHeightWithLabel,
    double? standardHeightIconOnly,
    double? standardFloatingRadius,
    double? standardBorderWidth,
    double? standardFloatingShadowBlur,
    double? standardAttachedShadowBlur,
    double? standardFloatingShadowOffsetY,
    double? standardAttachedShadowOffsetY,
    double? standardFrostedBlurSigmaFloating,
    double? standardFrostedBlurSigmaAttached,
    double? dockItemRadius,
    double? dockSurfaceBorderWidth,
    double? dockSurfaceShadowBlur,
    double? dockSurfaceShadowOffsetY,
    double? dockSearchShadowBlur,
    double? dockSearchShadowOffsetY,
  }) {
    return AppNavigationComponentTokens(
      standardHeightWithLabel:
          standardHeightWithLabel ?? this.standardHeightWithLabel,
      standardHeightIconOnly:
          standardHeightIconOnly ?? this.standardHeightIconOnly,
      standardFloatingRadius:
          standardFloatingRadius ?? this.standardFloatingRadius,
      standardBorderWidth: standardBorderWidth ?? this.standardBorderWidth,
      standardFloatingShadowBlur:
          standardFloatingShadowBlur ?? this.standardFloatingShadowBlur,
      standardAttachedShadowBlur:
          standardAttachedShadowBlur ?? this.standardAttachedShadowBlur,
      standardFloatingShadowOffsetY:
          standardFloatingShadowOffsetY ?? this.standardFloatingShadowOffsetY,
      standardAttachedShadowOffsetY:
          standardAttachedShadowOffsetY ?? this.standardAttachedShadowOffsetY,
      standardFrostedBlurSigmaFloating:
          standardFrostedBlurSigmaFloating ??
          this.standardFrostedBlurSigmaFloating,
      standardFrostedBlurSigmaAttached:
          standardFrostedBlurSigmaAttached ??
          this.standardFrostedBlurSigmaAttached,
      dockItemRadius: dockItemRadius ?? this.dockItemRadius,
      dockSurfaceBorderWidth:
          dockSurfaceBorderWidth ?? this.dockSurfaceBorderWidth,
      dockSurfaceShadowBlur:
          dockSurfaceShadowBlur ?? this.dockSurfaceShadowBlur,
      dockSurfaceShadowOffsetY:
          dockSurfaceShadowOffsetY ?? this.dockSurfaceShadowOffsetY,
      dockSearchShadowBlur: dockSearchShadowBlur ?? this.dockSearchShadowBlur,
      dockSearchShadowOffsetY:
          dockSearchShadowOffsetY ?? this.dockSearchShadowOffsetY,
    );
  }

  static AppNavigationComponentTokens lerp(
    AppNavigationComponentTokens a,
    AppNavigationComponentTokens b,
    double t,
  ) {
    return AppNavigationComponentTokens(
      standardHeightWithLabel:
          lerpDouble(a.standardHeightWithLabel, b.standardHeightWithLabel, t)!,
      standardHeightIconOnly:
          lerpDouble(a.standardHeightIconOnly, b.standardHeightIconOnly, t)!,
      standardFloatingRadius:
          lerpDouble(a.standardFloatingRadius, b.standardFloatingRadius, t)!,
      standardBorderWidth:
          lerpDouble(a.standardBorderWidth, b.standardBorderWidth, t)!,
      standardFloatingShadowBlur:
          lerpDouble(
            a.standardFloatingShadowBlur,
            b.standardFloatingShadowBlur,
            t,
          )!,
      standardAttachedShadowBlur:
          lerpDouble(
            a.standardAttachedShadowBlur,
            b.standardAttachedShadowBlur,
            t,
          )!,
      standardFloatingShadowOffsetY:
          lerpDouble(
            a.standardFloatingShadowOffsetY,
            b.standardFloatingShadowOffsetY,
            t,
          )!,
      standardAttachedShadowOffsetY:
          lerpDouble(
            a.standardAttachedShadowOffsetY,
            b.standardAttachedShadowOffsetY,
            t,
          )!,
      standardFrostedBlurSigmaFloating:
          lerpDouble(
            a.standardFrostedBlurSigmaFloating,
            b.standardFrostedBlurSigmaFloating,
            t,
          )!,
      standardFrostedBlurSigmaAttached:
          lerpDouble(
            a.standardFrostedBlurSigmaAttached,
            b.standardFrostedBlurSigmaAttached,
            t,
          )!,
      dockItemRadius: lerpDouble(a.dockItemRadius, b.dockItemRadius, t)!,
      dockSurfaceBorderWidth:
          lerpDouble(a.dockSurfaceBorderWidth, b.dockSurfaceBorderWidth, t)!,
      dockSurfaceShadowBlur:
          lerpDouble(a.dockSurfaceShadowBlur, b.dockSurfaceShadowBlur, t)!,
      dockSurfaceShadowOffsetY:
          lerpDouble(
            a.dockSurfaceShadowOffsetY,
            b.dockSurfaceShadowOffsetY,
            t,
          )!,
      dockSearchShadowBlur:
          lerpDouble(a.dockSearchShadowBlur, b.dockSearchShadowBlur, t)!,
      dockSearchShadowOffsetY:
          lerpDouble(a.dockSearchShadowOffsetY, b.dockSearchShadowOffsetY, t)!,
    );
  }
}

class AppSelectionComponentTokens {
  const AppSelectionComponentTokens({
    required this.chipRadius,
    required this.chipBorderWidth,
    required this.tabIndicatorRadius,
    required this.segmentRadius,
    required this.segmentBorderWidth,
    required this.switchTrackOutlineWidth,
  });

  final double chipRadius;
  final double chipBorderWidth;
  final double tabIndicatorRadius;
  final double segmentRadius;
  final double segmentBorderWidth;
  final double switchTrackOutlineWidth;

  AppSelectionComponentTokens copyWith({
    double? chipRadius,
    double? chipBorderWidth,
    double? tabIndicatorRadius,
    double? segmentRadius,
    double? segmentBorderWidth,
    double? switchTrackOutlineWidth,
  }) {
    return AppSelectionComponentTokens(
      chipRadius: chipRadius ?? this.chipRadius,
      chipBorderWidth: chipBorderWidth ?? this.chipBorderWidth,
      tabIndicatorRadius: tabIndicatorRadius ?? this.tabIndicatorRadius,
      segmentRadius: segmentRadius ?? this.segmentRadius,
      segmentBorderWidth: segmentBorderWidth ?? this.segmentBorderWidth,
      switchTrackOutlineWidth:
          switchTrackOutlineWidth ?? this.switchTrackOutlineWidth,
    );
  }

  static AppSelectionComponentTokens lerp(
    AppSelectionComponentTokens a,
    AppSelectionComponentTokens b,
    double t,
  ) {
    return AppSelectionComponentTokens(
      chipRadius: lerpDouble(a.chipRadius, b.chipRadius, t)!,
      chipBorderWidth: lerpDouble(a.chipBorderWidth, b.chipBorderWidth, t)!,
      tabIndicatorRadius:
          lerpDouble(a.tabIndicatorRadius, b.tabIndicatorRadius, t)!,
      segmentRadius: lerpDouble(a.segmentRadius, b.segmentRadius, t)!,
      segmentBorderWidth:
          lerpDouble(a.segmentBorderWidth, b.segmentBorderWidth, t)!,
      switchTrackOutlineWidth:
          lerpDouble(a.switchTrackOutlineWidth, b.switchTrackOutlineWidth, t)!,
    );
  }
}

class AppComponentThemeTokens extends ThemeExtension<AppComponentThemeTokens> {
  const AppComponentThemeTokens({
    required this.card,
    required this.button,
    required this.input,
    required this.overlay,
    required this.navigation,
    required this.selection,
  });

  final AppCardComponentTokens card;
  final AppButtonComponentTokens button;
  final AppInputComponentTokens input;
  final AppOverlayComponentTokens overlay;
  final AppNavigationComponentTokens navigation;
  final AppSelectionComponentTokens selection;

  @override
  AppComponentThemeTokens copyWith({
    AppCardComponentTokens? card,
    AppButtonComponentTokens? button,
    AppInputComponentTokens? input,
    AppOverlayComponentTokens? overlay,
    AppNavigationComponentTokens? navigation,
    AppSelectionComponentTokens? selection,
  }) {
    return AppComponentThemeTokens(
      card: card ?? this.card,
      button: button ?? this.button,
      input: input ?? this.input,
      overlay: overlay ?? this.overlay,
      navigation: navigation ?? this.navigation,
      selection: selection ?? this.selection,
    );
  }

  @override
  AppComponentThemeTokens lerp(
    covariant ThemeExtension<AppComponentThemeTokens>? other,
    double t,
  ) {
    if (other is! AppComponentThemeTokens) {
      return this;
    }
    return AppComponentThemeTokens(
      card: AppCardComponentTokens.lerp(card, other.card, t),
      button: AppButtonComponentTokens.lerp(button, other.button, t),
      input: AppInputComponentTokens.lerp(input, other.input, t),
      overlay: AppOverlayComponentTokens.lerp(overlay, other.overlay, t),
      navigation: AppNavigationComponentTokens.lerp(
        navigation,
        other.navigation,
        t,
      ),
      selection: AppSelectionComponentTokens.lerp(
        selection,
        other.selection,
        t,
      ),
    );
  }
}

AppComponentThemeTokens resolveAppComponentThemeTokens(
  ColorScheme colorScheme,
) {
  final isDark = colorScheme.brightness == Brightness.dark;
  return AppComponentThemeTokens(
    card: AppCardComponentTokens(
      radius: 20,
      elevation: 0,
      borderWidth: 1,
      shadowBlur: 16,
      shadowOffsetY: 6,
      shadowAlpha: isDark ? 0.22 : 0.14,
    ),
    button: const AppButtonComponentTokens(
      shapeStyle: AppButtonShapeStyle.stadium,
      radius: 14,
      height: 40,
      outlinedBorderWidth: 1,
      horizontalPadding: 16,
    ),
    input: const AppInputComponentTokens(
      radius: 14,
      borderWidth: 1,
      focusedBorderWidth: 1.4,
    ),
    overlay: AppOverlayComponentTokens(
      radius: 16,
      topRadius: 20,
      backgroundBlurSigma: 0,
      borderWidth: 1,
      shadowBlur: 18,
      shadowOffsetY: 8,
      shadowAlpha: isDark ? 0.34 : 0.18,
    ),
    navigation: const AppNavigationComponentTokens(
      standardHeightWithLabel: 72,
      standardHeightIconOnly: 58,
      standardFloatingRadius: 28,
      standardBorderWidth: 0.8,
      standardFloatingShadowBlur: 20,
      standardAttachedShadowBlur: 16,
      standardFloatingShadowOffsetY: 10,
      standardAttachedShadowOffsetY: -4,
      standardFrostedBlurSigmaFloating: 18,
      standardFrostedBlurSigmaAttached: 14,
      dockItemRadius: 24,
      dockSurfaceBorderWidth: 0.8,
      dockSurfaceShadowBlur: 20,
      dockSurfaceShadowOffsetY: 10,
      dockSearchShadowBlur: 16,
      dockSearchShadowOffsetY: 8,
    ),
    selection: const AppSelectionComponentTokens(
      chipRadius: 10,
      chipBorderWidth: 0.8,
      tabIndicatorRadius: 12,
      segmentRadius: 12,
      segmentBorderWidth: 0.9,
      switchTrackOutlineWidth: 0.8,
    ),
  );
}

AppComponentThemeTokens resolveAppComponentThemeTokensFromModeConfig(
  ColorScheme colorScheme, {
  AppAdvancedThemeModeConfig? modeConfig,
}) {
  final base = resolveAppComponentThemeTokens(colorScheme);
  final style = modeConfig?.componentStyle;
  if (style == null) {
    return base;
  }

  final radiusScale = _clamp(style.globalRadiusScale, 0.72, 1.45);
  final shadowScale = _clamp(style.shadowStrength, 0.1, 1.0);

  var card = base.card.copyWith(
    radius: base.card.radius * radiusScale,
    shadowAlpha: _clamp(base.card.shadowAlpha * (0.55 + shadowScale * 0.95)),
  );
  switch (style.cardStyle) {
    case AppAdvancedThemeCardStyle.soft:
      card = card.copyWith(elevation: 0, borderWidth: 1, shadowBlur: 16);
    case AppAdvancedThemeCardStyle.outlined:
      card = card.copyWith(
        elevation: 0,
        borderWidth: 1.2,
        shadowBlur: 8,
        shadowOffsetY: 3,
        shadowAlpha: _clamp(card.shadowAlpha * 0.7),
      );
    case AppAdvancedThemeCardStyle.elevated:
      card = card.copyWith(
        elevation: 1,
        borderWidth: 0.8,
        shadowBlur: 22,
        shadowOffsetY: 10,
        shadowAlpha: _clamp(card.shadowAlpha * 1.15),
      );
  }

  var button = base.button.copyWith(
    radius: base.button.radius * radiusScale,
    height: _clamp(base.button.height * (0.94 + radiusScale * 0.08), 36, 54),
  );
  switch (style.buttonStyle) {
    case AppAdvancedThemeButtonStyle.stadium:
      button = button.copyWith(
        shapeStyle: AppButtonShapeStyle.stadium,
        horizontalPadding: 16,
      );
    case AppAdvancedThemeButtonStyle.rounded:
      button = button.copyWith(
        shapeStyle: AppButtonShapeStyle.rounded,
        radius: _clamp(16 * radiusScale, 10, 24),
        horizontalPadding: 15,
      );
    case AppAdvancedThemeButtonStyle.sharp:
      button = button.copyWith(
        shapeStyle: AppButtonShapeStyle.rounded,
        radius: _clamp(8 * radiusScale, 4, 14),
        horizontalPadding: 14,
      );
  }

  var input = base.input.copyWith(
    radius: base.input.radius * radiusScale,
    focusedBorderWidth: _clamp(
      base.input.focusedBorderWidth * (0.92 + shadowScale * 0.25),
      1.0,
      1.8,
    ),
  );
  switch (style.inputStyle) {
    case AppAdvancedThemeInputStyle.soft:
      input = input.copyWith(borderWidth: 1);
    case AppAdvancedThemeInputStyle.outlined:
      input = input.copyWith(
        radius: _clamp(12 * radiusScale, 8, 18),
        borderWidth: 1.15,
      );
    case AppAdvancedThemeInputStyle.underlined:
      input = input.copyWith(
        radius: _clamp(9 * radiusScale, 6, 14),
        borderWidth: 0.95,
      );
  }

  var overlay = base.overlay.copyWith(
    radius: base.overlay.radius * radiusScale,
    topRadius: base.overlay.topRadius * radiusScale,
    backgroundBlurSigma: _clamp(style.modalBackgroundBlurSigma, 0, 24),
    shadowAlpha: _clamp(base.overlay.shadowAlpha * (0.6 + shadowScale * 0.9)),
  );
  switch (style.overlayStyle) {
    case AppAdvancedThemeOverlayStyle.comfortable:
      overlay = overlay.copyWith(
        borderWidth: 1,
        shadowBlur: 18,
        shadowOffsetY: 8,
      );
    case AppAdvancedThemeOverlayStyle.compact:
      overlay = overlay.copyWith(
        radius: _clamp(13 * radiusScale, 10, 20),
        topRadius: _clamp(16 * radiusScale, 12, 24),
        borderWidth: 1.1,
        shadowBlur: 12,
        shadowOffsetY: 5,
      );
  }

  var navigation = base.navigation.copyWith(
    standardFloatingRadius:
        base.navigation.standardFloatingRadius * radiusScale,
    dockItemRadius: _clamp(
      base.navigation.dockItemRadius * radiusScale,
      16,
      34,
    ),
  );
  switch (style.navigationStyle) {
    case AppAdvancedThemeNavigationStyle.soft:
      navigation = navigation.copyWith(
        standardHeightWithLabel: 72,
        standardHeightIconOnly: 58,
      );
    case AppAdvancedThemeNavigationStyle.floating:
      navigation = navigation.copyWith(
        standardFloatingRadius: _clamp(30 * radiusScale, 20, 40),
        standardFloatingShadowBlur: 24,
        standardFloatingShadowOffsetY: 12,
      );
    case AppAdvancedThemeNavigationStyle.compact:
      navigation = navigation.copyWith(
        standardHeightWithLabel: 66,
        standardHeightIconOnly: 54,
        dockSurfaceShadowBlur: 14,
        dockSearchShadowBlur: 12,
      );
  }

  var selection = base.selection.copyWith(
    chipRadius: base.selection.chipRadius * radiusScale,
    tabIndicatorRadius: base.selection.tabIndicatorRadius * radiusScale,
    segmentRadius: base.selection.segmentRadius * radiusScale,
  );
  switch (style.switchStyle) {
    case AppAdvancedThemeSwitchStyle.soft:
      selection = selection.copyWith(
        chipBorderWidth: 0.8,
        switchTrackOutlineWidth: 0.8,
      );
    case AppAdvancedThemeSwitchStyle.contrast:
      selection = selection.copyWith(
        chipBorderWidth: 1.05,
        segmentBorderWidth: 1.1,
        switchTrackOutlineWidth: 1.1,
      );
  }

  return AppComponentThemeTokens(
    card: card,
    button: button,
    input: input,
    overlay: overlay,
    navigation: navigation,
    selection: selection,
  );
}

double _clamp(double value, [double min = 0.0, double max = 1.0]) {
  return value.clamp(min, max).toDouble();
}

AppComponentThemeTokens appComponentThemeTokensOf(BuildContext context) {
  final theme = Theme.of(context);
  return theme.extension<AppComponentThemeTokens>() ??
      resolveAppComponentThemeTokens(theme.colorScheme);
}

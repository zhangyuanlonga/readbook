import 'package:flutter/material.dart';

class AppThemeSeedOption {
  const AppThemeSeedOption(this.label, this.color);

  final String label;
  final Color color;
}

enum AppBaseColorSchemeId {
  luminaNeutral('lumina-neutral', '净白', Color(0xFF1C1B1B)),
  monoBlue('mono-blue', '黑白蓝', Color(0xFF2F5F8F)),
  inkGreen('ink-green', '黑白绿', Color(0xFF4D705E)),
  seluneWarm('selune-warm', '暖灰', Color(0xFFAA8552));

  const AppBaseColorSchemeId(this.id, this.label, this.swatch);

  final String id;
  final String label;
  final Color swatch;
}

class AppBaseColorSchemeOption {
  const AppBaseColorSchemeOption(this.id);

  final AppBaseColorSchemeId id;

  String get label => id.label;

  Color get swatch => id.swatch;
}

const AppThemeSeedOption appThemeFlameOrangeOption = AppThemeSeedOption(
  '焰阳橙',
  Color(0xFFE7573B),
);
const AppThemeSeedOption appThemePineGreenOption = AppThemeSeedOption(
  '松烟绿',
  Color(0xFF2E7D32),
);
const AppThemeSeedOption appThemeSeaBlueOption = AppThemeSeedOption(
  '澄海蓝',
  Color(0xFF1565C0),
);
const AppThemeSeedOption appThemeNightPurpleOption = AppThemeSeedOption(
  '星夜紫',
  Color(0xFF6750A4),
);
const AppThemeSeedOption appThemeMistTealOption = AppThemeSeedOption(
  '雾岚青',
  Color(0xFF0F8B8D),
);
const AppThemeSeedOption appThemeBerryRoseOption = AppThemeSeedOption(
  '莓霞红',
  Color(0xFFB83280),
);
const AppThemeSeedOption appThemeAmberGoldOption = AppThemeSeedOption(
  '琥珀金',
  Color(0xFFB7791F),
);
const AppThemeSeedOption appThemeSeluneOption = AppThemeSeedOption(
  '暖灰金',
  Color(0xFFC3A46E),
);
const AppThemeSeedOption appThemeSnowWhiteOption = AppThemeSeedOption(
  '霁雪白',
  Color(0xFFFFFFFF),
);

const List<AppThemeSeedOption> appThemeSeedOptions = [
  appThemeFlameOrangeOption,
  appThemePineGreenOption,
  appThemeSeaBlueOption,
  appThemeNightPurpleOption,
  appThemeMistTealOption,
  appThemeBerryRoseOption,
  appThemeAmberGoldOption,
  appThemeSeluneOption,
  appThemeSnowWhiteOption,
];

const List<AppBaseColorSchemeOption> appBaseColorSchemeOptions = [
  AppBaseColorSchemeOption(AppBaseColorSchemeId.luminaNeutral),
  AppBaseColorSchemeOption(AppBaseColorSchemeId.monoBlue),
  AppBaseColorSchemeOption(AppBaseColorSchemeId.inkGreen),
  AppBaseColorSchemeOption(AppBaseColorSchemeId.seluneWarm),
];

const Color _pureWhiteSeed = Color(0xFFFFFFFF);
const Color _seluneSeed = Color(0xFFC3A46E);
const Color _neutralSeed = Color(0xFF9E9E9E);
const Color _luminaLightSurface = Color(0xFFFFFFFF);
const Color _luminaLightSurfaceDim = Color(0xFFEEF1F4);
const Color _luminaLightSurfaceBright = Color(0xFFFFFFFF);
const Color _luminaLightSurfaceContainerLowest = Color(0xFFFFFFFF);
const Color _luminaLightSurfaceContainerLow = Color(0xFFF8FAFC);
const Color _luminaLightSurfaceContainer = Color(0xFFF2F5F8);
const Color _luminaLightSurfaceContainerHigh = Color(0xFFEBEFF4);
const Color _luminaLightSurfaceContainerHighest = Color(0xFFE2E7EE);
const Color _luminaLightOnSurface = Color(0xFF1C1B1B);
const Color _luminaLightOnSurfaceVariant = Color(0xFF606773);
const Color _luminaLightPrimary = Color(0xFF1C1B1B);
const Color _luminaLightOnPrimary = Color(0xFFFFFFFF);
const Color _luminaLightPrimaryContainer = Color(0xFFF1F3F5);
const Color _luminaLightOnPrimaryContainer = Color(0xFF1C1B1B);
const Color _luminaLightSecondary = Color(0xFF68717E);
const Color _luminaLightOnSecondary = Color(0xFFFFFFFF);
const Color _luminaLightSecondaryContainer = Color(0xFFE6EBF2);
const Color _luminaLightOnSecondaryContainer = Color(0xFF2D3540);
const Color _luminaLightTertiary = Color(0xFF5F6F7A);
const Color _luminaLightOnTertiary = Color(0xFFFFFFFF);
const Color _luminaLightTertiaryContainer = Color(0xFFE6EDF0);
const Color _luminaLightOnTertiaryContainer = Color(0xFF243139);
const Color _luminaLightOutline = Color(0xFFD5DAE2);
const Color _luminaLightOutlineVariant = Color(0xFFE7EBF0);
const Color _luminaDarkSurface = Color(0xFF161A20);
const Color _luminaDarkSurfaceDim = Color(0xFF0F1216);
const Color _luminaDarkSurfaceBright = Color(0xFF242A33);
const Color _luminaDarkSurfaceContainerLowest = Color(0xFF0B0D10);
const Color _luminaDarkSurfaceContainerLow = Color(0xFF151A20);
const Color _luminaDarkSurfaceContainer = Color(0xFF1B2129);
const Color _luminaDarkSurfaceContainerHigh = Color(0xFF232B35);
const Color _luminaDarkSurfaceContainerHighest = Color(0xFF2C3540);
const Color _luminaDarkOnSurface = Color(0xFFF4F0EF);
const Color _luminaDarkOnSurfaceVariant = Color(0xFFC4CAD3);
const Color _luminaDarkPrimary = Color(0xFFF4F0EF);
const Color _luminaDarkOnPrimary = Color(0xFF111418);
const Color _luminaDarkPrimaryContainer = Color(0xFF2B323C);
const Color _luminaDarkOnPrimaryContainer = Color(0xFFF4F0EF);
const Color _luminaDarkSecondary = Color(0xFFC0C7D6);
const Color _luminaDarkOnSecondary = Color(0xFF1E2630);
const Color _luminaDarkSecondaryContainer = Color(0xFF303846);
const Color _luminaDarkOnSecondaryContainer = Color(0xFFE6EBF2);
const Color _luminaDarkTertiary = Color(0xFFADC9C0);
const Color _luminaDarkOnTertiary = Color(0xFF19342D);
const Color _luminaDarkTertiaryContainer = Color(0xFF28443C);
const Color _luminaDarkOnTertiaryContainer = Color(0xFFD5EFE6);
const Color _luminaDarkOutline = Color(0xFF4D5662);
const Color _luminaDarkOutlineVariant = Color(0xFF333B46);
const Color _defaultLightPrimary = Color(0xFF1677FF);
const Color _defaultLightOnPrimary = Color(0xFFFFFFFF);
const Color _defaultLightPrimaryContainer = Color(0xFFEAF2FF);
const Color _defaultLightOnPrimaryContainer = Color(0xFF0F172A);
const Color _defaultLightSecondary = Color(0xFF4B5563);
const Color _defaultLightOnSecondary = Color(0xFFFFFFFF);
const Color _defaultLightSecondaryContainer = Color(0xFFF5F7FA);
const Color _defaultLightOnSecondaryContainer = Color(0xFF111827);
const Color _defaultLightTertiary = Color(0xFF1677FF);
const Color _defaultLightOnTertiary = Color(0xFFFFFFFF);
const Color _defaultLightTertiaryContainer = Color(0xFFEAF2FF);
const Color _defaultLightOnTertiaryContainer = Color(0xFF0F172A);
const Color _snowWhiteLightSurface = Color(0xFFFFFFFF);
const Color _snowWhiteLightSurfaceDim = Color(0xFFFFFFFF);
const Color _snowWhiteLightSurfaceBright = Color(0xFFFFFFFF);
const Color _snowWhiteLightSurfaceContainerLowest = Color(0xFFFFFFFF);
const Color _snowWhiteLightSurfaceContainerLow = Color(0xFFFFFFFF);
const Color _snowWhiteLightSurfaceContainer = Color(0xFFFFFFFF);
const Color _snowWhiteLightSurfaceContainerHigh = Color(0xFFFFFFFF);
const Color _snowWhiteLightSurfaceContainerHighest = Color(0xFFFFFFFF);
const Color _snowWhiteLightOnSurface = Color(0xFF191C1D);
const Color _snowWhiteLightOnSurfaceVariant = Color(0xFF414755);
const Color _snowWhiteLightOutline = Color(0xFFD9DEE5);
const Color _snowWhiteLightOutlineVariant = Color(0xFFE6E6E6);
const Color _snowWhiteLightInverseSurface = Color(0xFF2E3132);
const Color _snowWhiteLightOnInverseSurface = Color(0xFFF0F1F2);
const Color _snowWhiteLightInversePrimary = Color(0xFFAFc6FF);
const Color _defaultDarkPrimary = Color(0xFF8EB8FF);
const Color _defaultDarkOnPrimary = Color(0xFF082A5E);
const Color _defaultDarkPrimaryContainer = Color(0xFF123B78);
const Color _defaultDarkOnPrimaryContainer = Color(0xFFE8F1FF);
const Color _defaultDarkSecondary = Color(0xFFD7DEEA);
const Color _defaultDarkOnSecondary = Color(0xFF1D2838);
const Color _defaultDarkSecondaryContainer = Color(0xFF1E293B);
const Color _defaultDarkOnSecondaryContainer = Color(0xFFE5ECF6);
const Color _defaultDarkTertiary = Color(0xFF9DC2FF);
const Color _defaultDarkOnTertiary = Color(0xFF082A5E);
const Color _defaultDarkTertiaryContainer = Color(0xFF16345F);
const Color _defaultDarkOnTertiaryContainer = Color(0xFFE7F0FF);
const Color _defaultDarkSurface = Color(0xFF111418);
const Color _defaultDarkSurfaceBright = Color(0xFF242A33);
const Color _defaultDarkSurfaceContainerLowest = Color(0xFF0B0D10);
const Color _defaultDarkSurfaceContainer = Color(0xFF181D24);
const Color _defaultDarkSurfaceContainerHigh = Color(0xFF222831);
const Color _defaultDarkSurfaceContainerHighest = Color(0xFF2B323C);
const Color _defaultDarkOutline = Color(0xFF434C59);
const Color _defaultDarkOutlineVariant = Color(0xFF313844);
const Color _seluneLightPrimary = Color(0xFFAA8552);
const Color _seluneLightOnPrimary = Color(0xFFFFFFFF);
const Color _seluneLightPrimaryContainer = Color(0xFFF2E4CC);
const Color _seluneLightOnPrimaryContainer = Color(0xFF39270B);
const Color _seluneLightSecondary = Color(0xFF6D5C45);
const Color _seluneLightOnSecondary = Color(0xFFFFFFFF);
const Color _seluneLightSecondaryContainer = Color(0xFFF1E7D8);
const Color _seluneLightOnSecondaryContainer = Color(0xFF251A0B);
const Color _seluneLightTertiary = Color(0xFF7B6A53);
const Color _seluneLightOnTertiary = Color(0xFFFFFFFF);
const Color _seluneLightTertiaryContainer = Color(0xFFF4E8D7);
const Color _seluneLightOnTertiaryContainer = Color(0xFF2A1D0C);
const Color _seluneLightSurface = Color(0xFFF7F3EC);
const Color _seluneLightSurfaceDim = Color(0xFFEEE7DB);
const Color _seluneLightSurfaceBright = Color(0xFFFFFBF5);
const Color _seluneLightSurfaceContainerLowest = Color(0xFFFFFBF6);
const Color _seluneLightSurfaceContainerLow = Color(0xFFFBF7F0);
const Color _seluneLightSurfaceContainer = Color(0xFFF2ECE1);
const Color _seluneLightSurfaceContainerHigh = Color(0xFFEBE3D7);
const Color _seluneLightSurfaceContainerHighest = Color(0xFFE1D8C9);
const Color _seluneLightOnSurface = Color(0xFF1E1A16);
const Color _seluneLightOnSurfaceVariant = Color(0xFF645A4E);
const Color _seluneLightOutline = Color(0xFFD4C8B6);
const Color _seluneLightOutlineVariant = Color(0xFFE8DFD2);
const Color _seluneLightInverseSurface = Color(0xFF242228);
const Color _seluneLightOnInverseSurface = Color(0xFFF7F1E8);
const Color _seluneLightInversePrimary = Color(0xFFF0D7A7);
const Color _seluneDarkPrimary = Color(0xFFE6CCA0);
const Color _seluneDarkOnPrimary = Color(0xFF402E13);
const Color _seluneDarkPrimaryContainer = Color(0xFF6B5230);
const Color _seluneDarkOnPrimaryContainer = Color(0xFFFCEFD6);
const Color _seluneDarkSecondary = Color(0xFFD6C8B1);
const Color _seluneDarkOnSecondary = Color(0xFF3A2E1C);
const Color _seluneDarkSecondaryContainer = Color(0xFF514331);
const Color _seluneDarkOnSecondaryContainer = Color(0xFFF2E5D0);
const Color _seluneDarkTertiary = Color(0xFFE7CFA6);
const Color _seluneDarkOnTertiary = Color(0xFF433017);
const Color _seluneDarkTertiaryContainer = Color(0xFF5B4630);
const Color _seluneDarkOnTertiaryContainer = Color(0xFFFBE8CB);
const Color _seluneDarkSurface = Color(0xFF17171C);
const Color _seluneDarkSurfaceDim = Color(0xFF111116);
const Color _seluneDarkSurfaceBright = Color(0xFF2A2A31);
const Color _seluneDarkSurfaceContainerLowest = Color(0xFF0E0F13);
const Color _seluneDarkSurfaceContainerLow = Color(0xFF1A1A20);
const Color _seluneDarkSurfaceContainer = Color(0xFF202028);
const Color _seluneDarkSurfaceContainerHigh = Color(0xFF2A2A32);
const Color _seluneDarkSurfaceContainerHighest = Color(0xFF32323B);
const Color _seluneDarkOnSurface = Color(0xFFF5EEE4);
const Color _seluneDarkOnSurfaceVariant = Color(0xFFD1C5B7);
const Color _seluneDarkOutline = Color(0xFF4C453B);
const Color _seluneDarkOutlineVariant = Color(0xFF3A352E);
const Color _seluneDarkInverseSurface = Color(0xFFF7F2E9);
const Color _seluneDarkOnInverseSurface = Color(0xFF1B1814);
const Color _seluneDarkInversePrimary = Color(0xFFA78654);

bool isPureWhiteThemeSeed(Color seedColor) {
  return seedColor.toARGB32() == _pureWhiteSeed.toARGB32();
}

bool isSeluneThemeSeed(Color seedColor) {
  return seedColor.toARGB32() == _seluneSeed.toARGB32();
}

AppBaseColorSchemeId appBaseColorSchemeIdFromString(String? raw) {
  final normalized = raw?.trim();
  for (final id in AppBaseColorSchemeId.values) {
    if (id.id == normalized) {
      return id;
    }
  }
  return AppBaseColorSchemeId.luminaNeutral;
}

AppBaseColorSchemeId appBaseColorSchemeIdFromSeed(Color seedColor) {
  final value = seedColor.toARGB32();
  if (value == appThemeSeaBlueOption.color.toARGB32() ||
      value == appThemeNightPurpleOption.color.toARGB32()) {
    return AppBaseColorSchemeId.monoBlue;
  }
  if (value == appThemePineGreenOption.color.toARGB32() ||
      value == appThemeMistTealOption.color.toARGB32()) {
    return AppBaseColorSchemeId.inkGreen;
  }
  if (value == appThemeSeluneOption.color.toARGB32() ||
      value == appThemeAmberGoldOption.color.toARGB32() ||
      value == appThemeFlameOrangeOption.color.toARGB32()) {
    return AppBaseColorSchemeId.seluneWarm;
  }
  return AppBaseColorSchemeId.luminaNeutral;
}

ColorScheme buildAppBaseLightColorScheme(AppBaseColorSchemeId id) {
  return switch (id) {
    AppBaseColorSchemeId.luminaNeutral => _buildLuminaLightColorScheme(),
    AppBaseColorSchemeId.monoBlue => _buildNeutralLightColorScheme(
      primary: const Color(0xFF2F5F8F),
      primaryContainer: const Color(0xFFE7EEF7),
      secondary: const Color(0xFF526171),
      secondaryContainer: const Color(0xFFE6ECF3),
      tertiary: const Color(0xFF4C6C82),
      tertiaryContainer: const Color(0xFFE4EEF5),
    ),
    AppBaseColorSchemeId.inkGreen => _buildNeutralLightColorScheme(
      primary: const Color(0xFF4D705E),
      primaryContainer: const Color(0xFFE5EFE8),
      secondary: const Color(0xFF59675E),
      secondaryContainer: const Color(0xFFE7EEE9),
      tertiary: const Color(0xFF60756B),
      tertiaryContainer: const Color(0xFFE6F0EC),
    ),
    AppBaseColorSchemeId.seluneWarm => buildAppLightColorScheme(
      appThemeSeluneOption.color,
    ),
  };
}

ColorScheme buildAppBaseDarkColorScheme(AppBaseColorSchemeId id) {
  return switch (id) {
    AppBaseColorSchemeId.luminaNeutral => _buildLuminaDarkColorScheme(),
    AppBaseColorSchemeId.monoBlue => _buildNeutralDarkColorScheme(
      primary: const Color(0xFFB7CEE8),
      primaryContainer: const Color(0xFF26384D),
      secondary: const Color(0xFFC3CBD6),
      secondaryContainer: const Color(0xFF303946),
      tertiary: const Color(0xFFAFCFE3),
      tertiaryContainer: const Color(0xFF253B4A),
    ),
    AppBaseColorSchemeId.inkGreen => _buildNeutralDarkColorScheme(
      primary: const Color(0xFFB8D4C3),
      primaryContainer: const Color(0xFF2A4233),
      secondary: const Color(0xFFC4D0C8),
      secondaryContainer: const Color(0xFF303C34),
      tertiary: const Color(0xFFAED7C8),
      tertiaryContainer: const Color(0xFF25443A),
    ),
    AppBaseColorSchemeId.seluneWarm => buildAppDarkColorScheme(
      appThemeSeluneOption.color,
    ),
  };
}

ColorScheme _buildLuminaLightColorScheme() {
  final neutral = ColorScheme.fromSeed(
    seedColor: _neutralSeed,
    dynamicSchemeVariant: DynamicSchemeVariant.neutral,
    brightness: Brightness.light,
  );
  return neutral.copyWith(
    primary: _luminaLightPrimary,
    onPrimary: _luminaLightOnPrimary,
    primaryContainer: _luminaLightPrimaryContainer,
    onPrimaryContainer: _luminaLightOnPrimaryContainer,
    secondary: _luminaLightSecondary,
    onSecondary: _luminaLightOnSecondary,
    secondaryContainer: _luminaLightSecondaryContainer,
    onSecondaryContainer: _luminaLightOnSecondaryContainer,
    tertiary: _luminaLightTertiary,
    onTertiary: _luminaLightOnTertiary,
    tertiaryContainer: _luminaLightTertiaryContainer,
    onTertiaryContainer: _luminaLightOnTertiaryContainer,
    surface: _luminaLightSurface,
    surfaceDim: _luminaLightSurfaceDim,
    surfaceBright: _luminaLightSurfaceBright,
    surfaceContainerLowest: _luminaLightSurfaceContainerLowest,
    surfaceContainerLow: _luminaLightSurfaceContainerLow,
    surfaceContainer: _luminaLightSurfaceContainer,
    surfaceContainerHigh: _luminaLightSurfaceContainerHigh,
    surfaceContainerHighest: _luminaLightSurfaceContainerHighest,
    onSurface: _luminaLightOnSurface,
    onSurfaceVariant: _luminaLightOnSurfaceVariant,
    surfaceTint: Colors.transparent,
    outline: _luminaLightOutline,
    outlineVariant: _luminaLightOutlineVariant,
    inverseSurface: const Color(0xFF313030),
    onInverseSurface: const Color(0xFFF4F0EF),
    inversePrimary: const Color(0xFFC8C6C5),
  );
}

ColorScheme _buildLuminaDarkColorScheme() {
  final neutral = ColorScheme.fromSeed(
    seedColor: _neutralSeed,
    dynamicSchemeVariant: DynamicSchemeVariant.neutral,
    brightness: Brightness.dark,
  );
  return neutral.copyWith(
    primary: _luminaDarkPrimary,
    onPrimary: _luminaDarkOnPrimary,
    primaryContainer: _luminaDarkPrimaryContainer,
    onPrimaryContainer: _luminaDarkOnPrimaryContainer,
    secondary: _luminaDarkSecondary,
    onSecondary: _luminaDarkOnSecondary,
    secondaryContainer: _luminaDarkSecondaryContainer,
    onSecondaryContainer: _luminaDarkOnSecondaryContainer,
    tertiary: _luminaDarkTertiary,
    onTertiary: _luminaDarkOnTertiary,
    tertiaryContainer: _luminaDarkTertiaryContainer,
    onTertiaryContainer: _luminaDarkOnTertiaryContainer,
    surface: _luminaDarkSurface,
    surfaceDim: _luminaDarkSurfaceDim,
    surfaceBright: _luminaDarkSurfaceBright,
    surfaceContainerLowest: _luminaDarkSurfaceContainerLowest,
    surfaceContainerLow: _luminaDarkSurfaceContainerLow,
    surfaceContainer: _luminaDarkSurfaceContainer,
    surfaceContainerHigh: _luminaDarkSurfaceContainerHigh,
    surfaceContainerHighest: _luminaDarkSurfaceContainerHighest,
    onSurface: _luminaDarkOnSurface,
    onSurfaceVariant: _luminaDarkOnSurfaceVariant,
    surfaceTint: Colors.transparent,
    outline: _luminaDarkOutline,
    outlineVariant: _luminaDarkOutlineVariant,
    inverseSurface: const Color(0xFFF5F7FA),
    onInverseSurface: const Color(0xFF111827),
    inversePrimary: _luminaLightPrimary,
  );
}

ColorScheme _buildNeutralLightColorScheme({
  required Color primary,
  required Color primaryContainer,
  required Color secondary,
  required Color secondaryContainer,
  required Color tertiary,
  required Color tertiaryContainer,
}) {
  return _buildLuminaLightColorScheme().copyWith(
    primary: primary,
    onPrimary: Colors.white,
    primaryContainer: primaryContainer,
    onPrimaryContainer: const Color(0xFF1C1B1B),
    secondary: secondary,
    onSecondary: Colors.white,
    secondaryContainer: secondaryContainer,
    onSecondaryContainer: const Color(0xFF2D3540),
    tertiary: tertiary,
    onTertiary: Colors.white,
    tertiaryContainer: tertiaryContainer,
    onTertiaryContainer: const Color(0xFF243139),
    inversePrimary: primary,
  );
}

ColorScheme _buildNeutralDarkColorScheme({
  required Color primary,
  required Color primaryContainer,
  required Color secondary,
  required Color secondaryContainer,
  required Color tertiary,
  required Color tertiaryContainer,
}) {
  return _buildLuminaDarkColorScheme().copyWith(
    primary: primary,
    onPrimary: const Color(0xFF111418),
    primaryContainer: primaryContainer,
    onPrimaryContainer: const Color(0xFFF4F0EF),
    secondary: secondary,
    onSecondary: const Color(0xFF1E2630),
    secondaryContainer: secondaryContainer,
    onSecondaryContainer: const Color(0xFFE6EBF2),
    tertiary: tertiary,
    onTertiary: const Color(0xFF19342D),
    tertiaryContainer: tertiaryContainer,
    onTertiaryContainer: const Color(0xFFD5EFE6),
    inversePrimary: primary,
  );
}

ColorScheme buildAppLightColorScheme(Color seedColor) {
  final neutralSurfaceScheme = ColorScheme.fromSeed(
    seedColor: _neutralSeed,
    dynamicSchemeVariant: DynamicSchemeVariant.neutral,
    brightness: Brightness.light,
  );

  if (isSeluneThemeSeed(seedColor)) {
    return neutralSurfaceScheme.copyWith(
      primary: _seluneLightPrimary,
      onPrimary: _seluneLightOnPrimary,
      primaryContainer: _seluneLightPrimaryContainer,
      onPrimaryContainer: _seluneLightOnPrimaryContainer,
      secondary: _seluneLightSecondary,
      onSecondary: _seluneLightOnSecondary,
      secondaryContainer: _seluneLightSecondaryContainer,
      onSecondaryContainer: _seluneLightOnSecondaryContainer,
      tertiary: _seluneLightTertiary,
      onTertiary: _seluneLightOnTertiary,
      tertiaryContainer: _seluneLightTertiaryContainer,
      onTertiaryContainer: _seluneLightOnTertiaryContainer,
      surface: _seluneLightSurface,
      surfaceDim: _seluneLightSurfaceDim,
      surfaceBright: _seluneLightSurfaceBright,
      surfaceContainerLowest: _seluneLightSurfaceContainerLowest,
      surfaceContainerLow: _seluneLightSurfaceContainerLow,
      surfaceContainer: _seluneLightSurfaceContainer,
      surfaceContainerHigh: _seluneLightSurfaceContainerHigh,
      surfaceContainerHighest: _seluneLightSurfaceContainerHighest,
      onSurface: _seluneLightOnSurface,
      onSurfaceVariant: _seluneLightOnSurfaceVariant,
      surfaceTint: Colors.transparent,
      outline: _seluneLightOutline,
      outlineVariant: _seluneLightOutlineVariant,
      inverseSurface: _seluneLightInverseSurface,
      onInverseSurface: _seluneLightOnInverseSurface,
      inversePrimary: _seluneLightInversePrimary,
    );
  }

  if (isPureWhiteThemeSeed(seedColor)) {
    return neutralSurfaceScheme.copyWith(
      primary: _defaultLightPrimary,
      onPrimary: _defaultLightOnPrimary,
      primaryContainer: _defaultLightPrimaryContainer,
      onPrimaryContainer: _defaultLightOnPrimaryContainer,
      secondary: _defaultLightSecondary,
      onSecondary: _defaultLightOnSecondary,
      secondaryContainer: _defaultLightSecondaryContainer,
      onSecondaryContainer: _defaultLightOnSecondaryContainer,
      tertiary: _defaultLightTertiary,
      onTertiary: _defaultLightOnTertiary,
      tertiaryContainer: _defaultLightTertiaryContainer,
      onTertiaryContainer: _defaultLightOnTertiaryContainer,
      surface: _snowWhiteLightSurface,
      surfaceDim: _snowWhiteLightSurfaceDim,
      surfaceBright: _snowWhiteLightSurfaceBright,
      surfaceContainerLowest: _snowWhiteLightSurfaceContainerLowest,
      surfaceContainerLow: _snowWhiteLightSurfaceContainerLow,
      surfaceContainer: _snowWhiteLightSurfaceContainer,
      surfaceContainerHigh: _snowWhiteLightSurfaceContainerHigh,
      surfaceContainerHighest: _snowWhiteLightSurfaceContainerHighest,
      onSurface: _snowWhiteLightOnSurface,
      onSurfaceVariant: _snowWhiteLightOnSurfaceVariant,
      surfaceTint: Colors.transparent,
      outline: _snowWhiteLightOutline,
      outlineVariant: _snowWhiteLightOutlineVariant,
      inverseSurface: _snowWhiteLightInverseSurface,
      onInverseSurface: _snowWhiteLightOnInverseSurface,
      inversePrimary: _snowWhiteLightInversePrimary,
    );
  }

  final seededScheme = ColorScheme.fromSeed(
    seedColor: seedColor,
    dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
    brightness: Brightness.light,
  );

  return seededScheme.copyWith(
    surface: neutralSurfaceScheme.surface,
    surfaceDim: neutralSurfaceScheme.surfaceDim,
    surfaceBright: neutralSurfaceScheme.surfaceBright,
    surfaceContainerLowest: neutralSurfaceScheme.surfaceContainerLowest,
    surfaceContainerLow: neutralSurfaceScheme.surfaceContainerLow,
    surfaceContainer: neutralSurfaceScheme.surfaceContainer,
    surfaceContainerHigh: neutralSurfaceScheme.surfaceContainerHigh,
    surfaceContainerHighest: neutralSurfaceScheme.surfaceContainerHighest,
    surfaceTint: Colors.transparent,
    outlineVariant: neutralSurfaceScheme.outlineVariant,
  );
}

ColorScheme buildAppDarkColorScheme(Color seedColor) {
  if (isSeluneThemeSeed(seedColor)) {
    return ColorScheme.fromSeed(
      seedColor: seedColor,
      dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
      brightness: Brightness.dark,
    ).copyWith(
      primary: _seluneDarkPrimary,
      onPrimary: _seluneDarkOnPrimary,
      primaryContainer: _seluneDarkPrimaryContainer,
      onPrimaryContainer: _seluneDarkOnPrimaryContainer,
      secondary: _seluneDarkSecondary,
      onSecondary: _seluneDarkOnSecondary,
      secondaryContainer: _seluneDarkSecondaryContainer,
      onSecondaryContainer: _seluneDarkOnSecondaryContainer,
      tertiary: _seluneDarkTertiary,
      onTertiary: _seluneDarkOnTertiary,
      tertiaryContainer: _seluneDarkTertiaryContainer,
      onTertiaryContainer: _seluneDarkOnTertiaryContainer,
      surface: _seluneDarkSurface,
      surfaceDim: _seluneDarkSurfaceDim,
      surfaceBright: _seluneDarkSurfaceBright,
      surfaceContainerLowest: _seluneDarkSurfaceContainerLowest,
      surfaceContainerLow: _seluneDarkSurfaceContainerLow,
      surfaceContainer: _seluneDarkSurfaceContainer,
      surfaceContainerHigh: _seluneDarkSurfaceContainerHigh,
      surfaceContainerHighest: _seluneDarkSurfaceContainerHighest,
      onSurface: _seluneDarkOnSurface,
      onSurfaceVariant: _seluneDarkOnSurfaceVariant,
      surfaceTint: Colors.transparent,
      outline: _seluneDarkOutline,
      outlineVariant: _seluneDarkOutlineVariant,
      inverseSurface: _seluneDarkInverseSurface,
      onInverseSurface: _seluneDarkOnInverseSurface,
      inversePrimary: _seluneDarkInversePrimary,
    );
  }

  if (isPureWhiteThemeSeed(seedColor)) {
    final neutralDarkScheme = ColorScheme.fromSeed(
      seedColor: _neutralSeed,
      dynamicSchemeVariant: DynamicSchemeVariant.neutral,
      brightness: Brightness.dark,
    );

    return neutralDarkScheme.copyWith(
      primary: _defaultDarkPrimary,
      onPrimary: _defaultDarkOnPrimary,
      primaryContainer: _defaultDarkPrimaryContainer,
      onPrimaryContainer: _defaultDarkOnPrimaryContainer,
      secondary: _defaultDarkSecondary,
      onSecondary: _defaultDarkOnSecondary,
      secondaryContainer: _defaultDarkSecondaryContainer,
      onSecondaryContainer: _defaultDarkOnSecondaryContainer,
      tertiary: _defaultDarkTertiary,
      onTertiary: _defaultDarkOnTertiary,
      tertiaryContainer: _defaultDarkTertiaryContainer,
      onTertiaryContainer: _defaultDarkOnTertiaryContainer,
      surface: _defaultDarkSurface,
      surfaceDim: _defaultDarkSurface,
      surfaceBright: _defaultDarkSurfaceBright,
      surfaceContainerLowest: _defaultDarkSurfaceContainerLowest,
      surfaceContainerLow: _defaultDarkSurface,
      surfaceContainer: _defaultDarkSurfaceContainer,
      surfaceContainerHigh: _defaultDarkSurfaceContainerHigh,
      surfaceContainerHighest: _defaultDarkSurfaceContainerHighest,
      surfaceTint: Colors.transparent,
      outline: _defaultDarkOutline,
      outlineVariant: _defaultDarkOutlineVariant,
      inverseSurface: const Color(0xFFF5F7FA),
      onInverseSurface: const Color(0xFF111827),
      inversePrimary: _defaultLightPrimary,
    );
  }

  return ColorScheme.fromSeed(
    seedColor: seedColor,
    dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
    brightness: Brightness.dark,
  );
}

Color appThemeDisplayColor(
  Color seedColor, {
  Brightness brightness = Brightness.light,
}) {
  if (!isPureWhiteThemeSeed(seedColor) && !isSeluneThemeSeed(seedColor)) {
    return seedColor;
  }

  final scheme =
      brightness == Brightness.dark
          ? buildAppDarkColorScheme(seedColor)
          : buildAppLightColorScheme(seedColor);
  return scheme.primary;
}

String appThemeSeedLabel(Color selectedSeedColor) {
  for (final option in appThemeSeedOptions) {
    if (option.color.toARGB32() == selectedSeedColor.toARGB32()) {
      return option.label;
    }
  }
  return '自定义颜色';
}

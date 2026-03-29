import 'package:flutter/material.dart';

class AppThemeSeedOption {
  const AppThemeSeedOption(this.label, this.color);

  final String label;
  final Color color;
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
  appThemeSnowWhiteOption,
];

const Color _pureWhiteSeed = Color(0xFFFFFFFF);
const Color _neutralSeed = Color(0xFF9E9E9E);

bool isPureWhiteThemeSeed(Color seedColor) {
  return seedColor.toARGB32() == _pureWhiteSeed.toARGB32();
}

ColorScheme buildAppLightColorScheme(Color seedColor) {
  if (isPureWhiteThemeSeed(seedColor)) {
    final neutralBase = ColorScheme.fromSeed(
      seedColor: _neutralSeed,
      dynamicSchemeVariant: DynamicSchemeVariant.neutral,
      brightness: Brightness.light,
    );

    const pureWhite = Color(0xFFFFFFFF);
    const subtleOutline = Color(0xFFE6E6E6);
    return neutralBase.copyWith(
      surface: pureWhite,
      surfaceDim: pureWhite,
      surfaceBright: pureWhite,
      surfaceContainerLowest: pureWhite,
      surfaceContainerLow: pureWhite,
      surfaceContainer: pureWhite,
      surfaceContainerHigh: pureWhite,
      surfaceContainerHighest: pureWhite,
      surfaceTint: Colors.transparent,
      outlineVariant: subtleOutline,
    );
  }

  return ColorScheme.fromSeed(
    seedColor: seedColor,
    dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
    brightness: Brightness.light,
  );
}

ColorScheme buildAppDarkColorScheme(Color seedColor) {
  if (isPureWhiteThemeSeed(seedColor)) {
    return ColorScheme.fromSeed(
      seedColor: _neutralSeed,
      dynamicSchemeVariant: DynamicSchemeVariant.neutral,
      brightness: Brightness.dark,
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
  if (!isPureWhiteThemeSeed(seedColor)) {
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

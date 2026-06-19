import 'package:flutter/material.dart';

import '../../domain/entities/app_advanced_theme.dart';
import '../../features/mine/application/active_theme_appearance_snapshot.dart';
import 'app_advanced_theme_tokens.dart';
import 'app_theme_palette.dart';

enum AppOfficialThemePresetId {
  lumina('lumina', 'Lumina', AppBaseColorSchemeId.luminaNeutral),
  monoBlue('mono-blue', 'Mono Blue', AppBaseColorSchemeId.monoBlue),
  inkGreen('ink-green', 'Ink Green', AppBaseColorSchemeId.inkGreen),
  seluneWarm('selune-warm', 'Selune Warm', AppBaseColorSchemeId.seluneWarm);

  const AppOfficialThemePresetId(
    this.id,
    this.label,
    this.defaultBaseColorSchemeId,
  );

  final String id;
  final String label;
  final AppBaseColorSchemeId defaultBaseColorSchemeId;

  String get themeId => 'official:$id';
}

class AppOfficialThemePreset {
  const AppOfficialThemePreset({
    required this.id,
    required this.description,
    required this.previewSwatches,
    required this.lightConfig,
    required this.darkConfig,
  });

  final AppOfficialThemePresetId id;
  final String description;
  final List<Color> previewSwatches;
  final AppAdvancedThemeModeConfig lightConfig;
  final AppAdvancedThemeModeConfig darkConfig;

  ActiveThemeAppearanceSnapshot toAppearanceSnapshot() {
    return ActiveThemeAppearanceSnapshot(
      lightConfig: lightConfig,
      darkConfig: darkConfig,
    );
  }
}

const String appDefaultOfficialThemeId = 'official:lumina';

List<AppOfficialThemePreset> get appOfficialThemePresets {
  return AppOfficialThemePresetId.values
      .map(appOfficialThemePresetById)
      .toList(growable: false);
}

bool isOfficialThemeId(String? themeId) {
  return appOfficialThemePresetIdFromThemeId(themeId) != null;
}

AppOfficialThemePresetId? appOfficialThemePresetIdFromThemeId(String? themeId) {
  final normalized = themeId?.trim();
  if (normalized == null || !normalized.startsWith('official:')) {
    return null;
  }
  final id = normalized.substring('official:'.length);
  return appOfficialThemePresetIdFromString(id);
}

AppOfficialThemePresetId appOfficialThemePresetIdFromString(String? raw) {
  final normalized = raw?.trim();
  for (final id in AppOfficialThemePresetId.values) {
    if (id.id == normalized) {
      return id;
    }
  }
  return AppOfficialThemePresetId.lumina;
}

AppOfficialThemePreset appOfficialThemePresetByThemeId(String? themeId) {
  return appOfficialThemePresetById(
    appOfficialThemePresetIdFromThemeId(themeId) ??
        AppOfficialThemePresetId.lumina,
  );
}

AppOfficialThemePreset appOfficialThemePresetById(AppOfficialThemePresetId id) {
  final lightScheme = buildAppBaseLightColorScheme(id.defaultBaseColorSchemeId);
  final darkScheme = buildAppBaseDarkColorScheme(id.defaultBaseColorSchemeId);
  return AppOfficialThemePreset(
    id: id,
    description: switch (id) {
      AppOfficialThemePresetId.lumina => '黑白灰阅读 App 基线',
      AppOfficialThemePresetId.monoBlue => '黑白蓝工具感预设',
      AppOfficialThemePresetId.inkGreen => '黑白绿阅读状态预设',
      AppOfficialThemePresetId.seluneWarm => '暖灰金品牌预设',
    },
    previewSwatches: <Color>[
      lightScheme.surface,
      lightScheme.primary,
      lightScheme.secondary,
      darkScheme.surface,
    ],
    lightConfig: _officialModeConfig(lightScheme),
    darkConfig: _officialModeConfig(darkScheme),
  );
}

AppAdvancedThemeModeConfig _officialModeConfig(ColorScheme scheme) {
  return buildDefaultAdvancedThemeModeConfig(
    scheme,
  ).copyWith(componentStyle: _componentStyleFor(scheme));
}

AppAdvancedThemeComponentStyle _componentStyleFor(ColorScheme scheme) {
  final isSelune =
      scheme.primary.toARGB32() == const Color(0xFFAA8552).toARGB32() ||
      scheme.primary.toARGB32() == const Color(0xFFE6CCA0).toARGB32();
  return AppAdvancedThemeComponentStyle(
    globalRadiusScale: isSelune ? 1.08 : 1,
    shadowStrength: isSelune ? 0.42 : 0.34,
    cardStyle: AppAdvancedThemeCardStyle.soft,
    buttonStyle: AppAdvancedThemeButtonStyle.rounded,
    inputStyle: AppAdvancedThemeInputStyle.soft,
    overlayStyle: AppAdvancedThemeOverlayStyle.comfortable,
    navigationStyle: AppAdvancedThemeNavigationStyle.soft,
    switchStyle: AppAdvancedThemeSwitchStyle.soft,
  );
}

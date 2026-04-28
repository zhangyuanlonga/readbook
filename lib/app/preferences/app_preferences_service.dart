import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String appThemeModePreferenceKey = 'app.themeMode';
const String appSeedColorPreferenceKey = 'app.seedColor';
const String appInterfaceFontSourcePreferenceKey = 'app.interfaceFont.source';
const String appInterfaceSystemFontPresetPreferenceKey =
    'app.interfaceFont.systemPreset';
const String appInterfaceFontFamilyKeyPreferenceKey =
    'app.interfaceFont.familyKey';
const String appInterfaceCustomFontPathPreferenceKey =
    'app.interfaceFont.customPath';
const String appInterfaceTextScalePreferenceKey = 'app.interfaceTextScale';
const String appInterfaceFontWeightPreferenceKey = 'app.interfaceFontWeight';
const String appNavigationStylePreferenceKey = 'app.navigationStyle';
const String appNavigationLabelVisibilityPreferenceKey =
    'app.navigation.showLabels';
const String appNavigationStandardFloatingBarPreferenceKey =
    'app.navigation.standard.floatingBar';
const String appNavigationStandardFrostedEffectPreferenceKey =
    'app.navigation.standard.frostedEffect';
const String appNavigationCupertinoDockFrostedEffectPreferenceKey =
    'app.navigation.cupertinoDock.frostedEffect';
const String appShellNavigationHomePreferenceKey = 'app.shell.navigation.home';
const String appShellNavigationBookshelfPreferenceKey =
    'app.shell.navigation.bookshelf';
const String appShellNavigationDiscoverPreferenceKey =
    'app.shell.navigation.discover';
const String appShellNavigationStatsPreferenceKey =
    'app.shell.navigation.stats';
const String appShellNavigationSourcePreferenceKey =
    'app.shell.navigation.source';

final appThemePreferencesServiceProvider = Provider<AppThemePreferencesService>(
  (ref) {
    return AppThemePreferencesService();
  },
);

final appInterfaceTypographyPreferencesServiceProvider =
    Provider<AppInterfaceTypographyPreferencesService>((ref) {
      return AppInterfaceTypographyPreferencesService();
    });

final appNavigationPreferencesServiceProvider =
    Provider<AppNavigationPreferencesService>((ref) {
      return AppNavigationPreferencesService();
    });

final appShellNavigationPreferencesServiceProvider =
    Provider<AppShellNavigationPreferencesService>((ref) {
      return AppShellNavigationPreferencesService();
    });

class AppThemePreferencesService {
  AppThemePreferencesService({SharedPreferences? preferences})
    : _preferencesFuture =
          preferences == null
              ? SharedPreferences.getInstance()
              : Future.value(preferences);

  final Future<SharedPreferences> _preferencesFuture;

  Future<String?> loadThemeModeRaw() async {
    final prefs = await _preferencesFuture;
    return prefs.getString(appThemeModePreferenceKey);
  }

  Future<void> saveThemeModeRaw(String raw) async {
    final prefs = await _preferencesFuture;
    await prefs.setString(appThemeModePreferenceKey, raw);
  }

  Future<int?> loadSeedColorValue() async {
    final prefs = await _preferencesFuture;
    return prefs.getInt(appSeedColorPreferenceKey);
  }

  Future<void> saveSeedColorValue(int value) async {
    final prefs = await _preferencesFuture;
    await prefs.setInt(appSeedColorPreferenceKey, value);
  }
}

class AppInterfaceFontSettingsSnapshot {
  const AppInterfaceFontSettingsSnapshot({
    this.fontSourceName,
    this.systemFontPresetName,
    this.fontFamilyKey,
    this.customFontPath,
  });

  final String? fontSourceName;
  final String? systemFontPresetName;
  final String? fontFamilyKey;
  final String? customFontPath;
}

class AppInterfaceTypographyPreferencesService {
  AppInterfaceTypographyPreferencesService({SharedPreferences? preferences})
    : _preferencesFuture =
          preferences == null
              ? SharedPreferences.getInstance()
              : Future.value(preferences);

  final Future<SharedPreferences> _preferencesFuture;

  Future<AppInterfaceFontSettingsSnapshot> loadFontSettings() async {
    final prefs = await _preferencesFuture;
    return AppInterfaceFontSettingsSnapshot(
      fontSourceName: prefs.getString(appInterfaceFontSourcePreferenceKey),
      systemFontPresetName: prefs.getString(
        appInterfaceSystemFontPresetPreferenceKey,
      ),
      fontFamilyKey: prefs.getString(appInterfaceFontFamilyKeyPreferenceKey),
      customFontPath: prefs.getString(appInterfaceCustomFontPathPreferenceKey),
    );
  }

  Future<void> saveFontSettings(
    AppInterfaceFontSettingsSnapshot settings,
  ) async {
    final prefs = await _preferencesFuture;
    if (settings.fontSourceName == null || settings.fontSourceName!.isEmpty) {
      await prefs.remove(appInterfaceFontSourcePreferenceKey);
    } else {
      await prefs.setString(
        appInterfaceFontSourcePreferenceKey,
        settings.fontSourceName!,
      );
    }
    if (settings.systemFontPresetName == null ||
        settings.systemFontPresetName!.isEmpty) {
      await prefs.remove(appInterfaceSystemFontPresetPreferenceKey);
    } else {
      await prefs.setString(
        appInterfaceSystemFontPresetPreferenceKey,
        settings.systemFontPresetName!,
      );
    }
    if (settings.fontFamilyKey == null || settings.fontFamilyKey!.isEmpty) {
      await prefs.remove(appInterfaceFontFamilyKeyPreferenceKey);
    } else {
      await prefs.setString(
        appInterfaceFontFamilyKeyPreferenceKey,
        settings.fontFamilyKey!,
      );
    }
    if (settings.customFontPath == null || settings.customFontPath!.isEmpty) {
      await prefs.remove(appInterfaceCustomFontPathPreferenceKey);
    } else {
      await prefs.setString(
        appInterfaceCustomFontPathPreferenceKey,
        settings.customFontPath!,
      );
    }
  }

  Future<double?> loadTextScale() async {
    final prefs = await _preferencesFuture;
    return prefs.getDouble(appInterfaceTextScalePreferenceKey);
  }

  Future<void> saveTextScale(double scale) async {
    final prefs = await _preferencesFuture;
    await prefs.setDouble(appInterfaceTextScalePreferenceKey, scale);
  }

  Future<int?> loadFontWeight() async {
    final prefs = await _preferencesFuture;
    return prefs.getInt(appInterfaceFontWeightPreferenceKey);
  }

  Future<void> saveFontWeight(int weight) async {
    final prefs = await _preferencesFuture;
    await prefs.setInt(appInterfaceFontWeightPreferenceKey, weight);
  }
}

class AppStandardNavigationBarAppearanceSnapshot {
  const AppStandardNavigationBarAppearanceSnapshot({
    required this.floatingBar,
    required this.frostedEffect,
  });

  final bool floatingBar;
  final bool frostedEffect;
}

class AppCupertinoDockAppearanceSnapshot {
  const AppCupertinoDockAppearanceSnapshot({required this.frostedEffect});

  final bool frostedEffect;
}

class AppNavigationPreferencesService {
  AppNavigationPreferencesService({SharedPreferences? preferences})
    : _preferencesFuture =
          preferences == null
              ? SharedPreferences.getInstance()
              : Future.value(preferences);

  final Future<SharedPreferences> _preferencesFuture;

  Future<String?> loadNavigationStyleRaw() async {
    final prefs = await _preferencesFuture;
    return prefs.getString(appNavigationStylePreferenceKey);
  }

  Future<void> saveNavigationStyleRaw(String raw) async {
    final prefs = await _preferencesFuture;
    await prefs.setString(appNavigationStylePreferenceKey, raw);
  }

  Future<bool?> loadLabelVisibility() async {
    final prefs = await _preferencesFuture;
    return prefs.getBool(appNavigationLabelVisibilityPreferenceKey);
  }

  Future<void> saveLabelVisibility(bool visible) async {
    final prefs = await _preferencesFuture;
    await prefs.setBool(appNavigationLabelVisibilityPreferenceKey, visible);
  }

  Future<AppStandardNavigationBarAppearanceSnapshot>
  loadStandardNavigationBarAppearance() async {
    final prefs = await _preferencesFuture;
    return AppStandardNavigationBarAppearanceSnapshot(
      floatingBar:
          prefs.getBool(appNavigationStandardFloatingBarPreferenceKey) ?? false,
      frostedEffect:
          prefs.getBool(appNavigationStandardFrostedEffectPreferenceKey) ??
          false,
    );
  }

  Future<void> saveStandardNavigationBarAppearance(
    AppStandardNavigationBarAppearanceSnapshot appearance,
  ) async {
    final prefs = await _preferencesFuture;
    await prefs.setBool(
      appNavigationStandardFloatingBarPreferenceKey,
      appearance.floatingBar,
    );
    await prefs.setBool(
      appNavigationStandardFrostedEffectPreferenceKey,
      appearance.frostedEffect,
    );
  }

  Future<AppCupertinoDockAppearanceSnapshot>
  loadCupertinoDockAppearance() async {
    final prefs = await _preferencesFuture;
    return AppCupertinoDockAppearanceSnapshot(
      frostedEffect:
          prefs.getBool(appNavigationCupertinoDockFrostedEffectPreferenceKey) ??
          false,
    );
  }

  Future<void> saveCupertinoDockAppearance(
    AppCupertinoDockAppearanceSnapshot appearance,
  ) async {
    final prefs = await _preferencesFuture;
    await prefs.setBool(
      appNavigationCupertinoDockFrostedEffectPreferenceKey,
      appearance.frostedEffect,
    );
  }
}

class AppShellNavigationSnapshot {
  const AppShellNavigationSnapshot({
    required this.showHome,
    required this.showBookshelf,
    required this.showDiscover,
    required this.showStats,
  });

  final bool showHome;
  final bool showBookshelf;
  final bool showDiscover;
  final bool showStats;
}

class AppShellNavigationPreferencesService {
  AppShellNavigationPreferencesService({SharedPreferences? preferences})
    : _preferencesFuture =
          preferences == null
              ? SharedPreferences.getInstance()
              : Future.value(preferences);

  final Future<SharedPreferences> _preferencesFuture;

  Future<AppShellNavigationSnapshot> loadShellNavigation() async {
    final prefs = await _preferencesFuture;
    await prefs.remove(appShellNavigationSourcePreferenceKey);
    return AppShellNavigationSnapshot(
      showHome: prefs.getBool(appShellNavigationHomePreferenceKey) ?? true,
      showBookshelf:
          prefs.getBool(appShellNavigationBookshelfPreferenceKey) ?? true,
      showDiscover:
          prefs.getBool(appShellNavigationDiscoverPreferenceKey) ?? false,
      showStats: prefs.getBool(appShellNavigationStatsPreferenceKey) ?? true,
    );
  }

  Future<void> saveShellNavigation(AppShellNavigationSnapshot snapshot) async {
    final prefs = await _preferencesFuture;
    await prefs.setBool(appShellNavigationHomePreferenceKey, snapshot.showHome);
    await prefs.setBool(
      appShellNavigationBookshelfPreferenceKey,
      snapshot.showBookshelf,
    );
    await prefs.setBool(
      appShellNavigationDiscoverPreferenceKey,
      snapshot.showDiscover,
    );
    await prefs.setBool(
      appShellNavigationStatsPreferenceKey,
      snapshot.showStats,
    );
    await prefs.remove(appShellNavigationSourcePreferenceKey);
  }
}

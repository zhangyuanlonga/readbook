import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/mine/application/advanced_theme_provider.dart';
import '../preferences/app_preferences_service.dart';
import 'app_official_theme_presets.dart';
import 'app_theme_palette.dart';

final appBaseColorSchemeProvider =
    NotifierProvider<AppBaseColorSchemeNotifier, AppBaseColorSchemeId>(
      AppBaseColorSchemeNotifier.new,
    );

final appThemeSourceProvider = Provider<AppThemeSource>((ref) {
  final activeThemeId = ref.watch(activeAdvancedThemeIdProvider);
  final baseColorSchemeId = ref.watch(appBaseColorSchemeProvider);
  final normalized = activeThemeId?.trim();
  if (normalized != null && normalized.isNotEmpty) {
    final officialPreset = appOfficialThemePresetIdFromThemeId(normalized);
    if (officialPreset != null) {
      return AppThemeSource.official(officialPresetId: officialPreset);
    }
    return AppThemeSource.custom(
      customAdvancedThemeId: normalized,
      baseColorSchemeId: baseColorSchemeId,
    );
  }
  return AppThemeSource.base(baseColorSchemeId);
});

class AppThemeSource {
  const AppThemeSource._({
    required this.kind,
    required this.baseColorSchemeId,
    this.officialPresetId,
    this.customAdvancedThemeId,
  });

  factory AppThemeSource.official({
    required AppOfficialThemePresetId officialPresetId,
  }) {
    return AppThemeSource._(
      kind: AppThemeSourceKind.official,
      officialPresetId: officialPresetId,
      baseColorSchemeId: officialPresetId.defaultBaseColorSchemeId,
    );
  }

  factory AppThemeSource.custom({
    required String customAdvancedThemeId,
    required AppBaseColorSchemeId baseColorSchemeId,
  }) {
    return AppThemeSource._(
      kind: AppThemeSourceKind.customAdvancedTheme,
      customAdvancedThemeId: customAdvancedThemeId,
      baseColorSchemeId: baseColorSchemeId,
    );
  }

  factory AppThemeSource.base(AppBaseColorSchemeId baseColorSchemeId) {
    return AppThemeSource._(
      kind: AppThemeSourceKind.baseColorScheme,
      baseColorSchemeId: baseColorSchemeId,
    );
  }

  final AppThemeSourceKind kind;
  final AppBaseColorSchemeId baseColorSchemeId;
  final AppOfficialThemePresetId? officialPresetId;
  final String? customAdvancedThemeId;

  ColorScheme get lightScheme {
    return buildAppBaseLightColorScheme(baseColorSchemeId);
  }

  ColorScheme get darkScheme {
    return buildAppBaseDarkColorScheme(baseColorSchemeId);
  }
}

enum AppThemeSourceKind { official, customAdvancedTheme, baseColorScheme }

class AppBaseColorSchemeNotifier extends Notifier<AppBaseColorSchemeId> {
  static AppBaseColorSchemeId? _primedBaseColorSchemeId;

  bool _loadTriggered = false;
  bool _hasExplicitSet = false;

  static void prime(SharedPreferences prefs) {
    final stored = prefs.getString(appBaseColorSchemePreferenceKey);
    if (stored != null && stored.trim().isNotEmpty) {
      _primedBaseColorSchemeId = appBaseColorSchemeIdFromString(stored);
      return;
    }
    final legacySeed = prefs.getInt(appSeedColorPreferenceKey);
    _primedBaseColorSchemeId =
        legacySeed == null
            ? AppBaseColorSchemeId.luminaNeutral
            : appBaseColorSchemeIdFromSeed(Color(legacySeed));
  }

  @override
  AppBaseColorSchemeId build() {
    final primed = _primedBaseColorSchemeId;
    if (primed != null) {
      return primed;
    }
    if (!_loadTriggered) {
      _loadTriggered = true;
      _load();
    }
    return AppBaseColorSchemeId.luminaNeutral;
  }

  Future<void> _load() async {
    final service = ref.read(appThemePreferencesServiceProvider);
    final stored = await service.loadBaseColorSchemeId();
    if (_hasExplicitSet) {
      return;
    }
    if (stored != null && stored.trim().isNotEmpty) {
      final next = appBaseColorSchemeIdFromString(stored);
      _setStateIfChanged(next);
      return;
    }
    final legacySeed = await service.loadSeedColorValue();
    final next =
        legacySeed == null
            ? AppBaseColorSchemeId.luminaNeutral
            : appBaseColorSchemeIdFromSeed(Color(legacySeed));
    _setStateIfChanged(next);
  }

  Future<void> setBaseColorScheme(AppBaseColorSchemeId id) async {
    _hasExplicitSet = true;
    _primedBaseColorSchemeId = id;
    _setStateIfChanged(id);
    await ref
        .read(appThemePreferencesServiceProvider)
        .saveBaseColorSchemeId(id.id);
  }

  void _setStateIfChanged(AppBaseColorSchemeId id) {
    if (state != id) {
      state = id;
    }
  }
}

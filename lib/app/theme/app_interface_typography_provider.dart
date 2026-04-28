import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/reader/application/reader_font_registry_service.dart';
import 'dart:io';

enum AppInterfaceFontSource { system, custom }

enum AppInterfaceSystemFontPreset { defaultSans, serif, monospace }

String appInterfaceSystemFontPresetLabel(AppInterfaceSystemFontPreset preset) {
  return switch (preset) {
    AppInterfaceSystemFontPreset.defaultSans => '系统默认',
    AppInterfaceSystemFontPreset.serif => '衬线体',
    AppInterfaceSystemFontPreset.monospace => '等宽体',
  };
}

FontWeight appInterfaceFontWeightValue(int weight) {
  return FontWeight.values.firstWhere(
    (item) => item.value == weight,
    orElse: () => FontWeight.w400,
  );
}

class AppInterfaceFontSettings {
  const AppInterfaceFontSettings({
    this.fontSource = AppInterfaceFontSource.system,
    this.systemFontPreset = AppInterfaceSystemFontPreset.defaultSans,
    this.fontFamilyKey,
    this.customFontPath,
  });

  final AppInterfaceFontSource fontSource;
  final AppInterfaceSystemFontPreset systemFontPreset;
  final String? fontFamilyKey;
  final String? customFontPath;

  AppInterfaceFontSettings copyWith({
    AppInterfaceFontSource? fontSource,
    AppInterfaceSystemFontPreset? systemFontPreset,
    String? fontFamilyKey,
    String? customFontPath,
    bool clearFontFamilyKey = false,
    bool clearCustomFontPath = false,
  }) {
    return AppInterfaceFontSettings(
      fontSource: fontSource ?? this.fontSource,
      systemFontPreset: systemFontPreset ?? this.systemFontPreset,
      fontFamilyKey:
          clearFontFamilyKey ? null : fontFamilyKey ?? this.fontFamilyKey,
      customFontPath:
          clearCustomFontPath ? null : customFontPath ?? this.customFontPath,
    );
  }
}

String? resolveAppInterfaceFontFamily(AppInterfaceFontSettings settings) {
  if (settings.fontSource == AppInterfaceFontSource.custom) {
    final family = settings.fontFamilyKey?.trim();
    if (family == null || family.isEmpty) {
      return null;
    }
    return family;
  }

  return switch (settings.systemFontPreset) {
    AppInterfaceSystemFontPreset.defaultSans => null,
    AppInterfaceSystemFontPreset.serif => 'serif',
    AppInterfaceSystemFontPreset.monospace => 'monospace',
  };
}

final appInterfaceFontSettingsProvider = NotifierProvider<
  AppInterfaceFontSettingsNotifier,
  AppInterfaceFontSettings
>(AppInterfaceFontSettingsNotifier.new);

final appInterfaceTextScaleProvider =
    NotifierProvider<AppInterfaceTextScaleNotifier, double>(
      AppInterfaceTextScaleNotifier.new,
    );

final appInterfaceFontWeightProvider =
    NotifierProvider<AppInterfaceFontWeightNotifier, int>(
      AppInterfaceFontWeightNotifier.new,
    );

class AppInterfaceFontSettingsNotifier
    extends Notifier<AppInterfaceFontSettings> {
  static const String _fontSourceKey = 'app.interfaceFont.source';
  static const String _systemFontPresetKey = 'app.interfaceFont.systemPreset';
  static const String _fontFamilyKeyKey = 'app.interfaceFont.familyKey';
  static const String _customFontPathKey = 'app.interfaceFont.customPath';
  static AppInterfaceFontSettings? _primedValue;

  bool _loadTriggered = false;
  bool _hasExplicitSet = false;

  static void prime(SharedPreferences prefs) {
    final sourceRaw = prefs.getString(_fontSourceKey);
    final systemPresetRaw = prefs.getString(_systemFontPresetKey);
    final fontFamilyKey = prefs.getString(_fontFamilyKeyKey);
    final customFontPath = prefs.getString(_customFontPathKey);

    _primedValue = AppInterfaceFontSettings(
      fontSource: AppInterfaceFontSource.values.firstWhere(
        (item) => item.name == sourceRaw,
        orElse: () => AppInterfaceFontSource.system,
      ),
      systemFontPreset: AppInterfaceSystemFontPreset.values.firstWhere(
        (item) => item.name == systemPresetRaw,
        orElse: () => AppInterfaceSystemFontPreset.defaultSans,
      ),
      fontFamilyKey: fontFamilyKey,
      customFontPath: customFontPath,
    );
  }

  @override
  AppInterfaceFontSettings build() {
    final primedValue = _primedValue;
    if (primedValue != null) {
      return primedValue;
    }
    if (!_loadTriggered) {
      _loadTriggered = true;
      _load();
    }
    return const AppInterfaceFontSettings();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final sourceRaw = prefs.getString(_fontSourceKey);
    final systemPresetRaw = prefs.getString(_systemFontPresetKey);
    final loaded = await _normalizeSettings(
      AppInterfaceFontSettings(
        fontSource: AppInterfaceFontSource.values.firstWhere(
          (item) => item.name == sourceRaw,
          orElse: () => AppInterfaceFontSource.system,
        ),
        systemFontPreset: AppInterfaceSystemFontPreset.values.firstWhere(
          (item) => item.name == systemPresetRaw,
          orElse: () => AppInterfaceSystemFontPreset.defaultSans,
        ),
        fontFamilyKey: prefs.getString(_fontFamilyKeyKey),
        customFontPath: prefs.getString(_customFontPathKey),
      ),
    );
    if (_hasExplicitSet || loaded == state) {
      return;
    }
    state = loaded;
  }

  Future<void> setSystemFont(AppInterfaceSystemFontPreset preset) async {
    await setSettings(
      AppInterfaceFontSettings(
        fontSource: AppInterfaceFontSource.system,
        systemFontPreset: preset,
      ),
    );
  }

  Future<void> setCustomFont(ReaderCustomFontEntry entry) async {
    await setSettings(
      AppInterfaceFontSettings(
        fontSource: AppInterfaceFontSource.custom,
        systemFontPreset: AppInterfaceSystemFontPreset.defaultSans,
        fontFamilyKey: entry.fontFamilyKey,
        customFontPath: entry.filePath,
      ),
    );
  }

  Future<void> setSettings(AppInterfaceFontSettings settings) async {
    final normalized = await _normalizeSettings(settings);
    _hasExplicitSet = true;
    _primedValue = normalized;
    if (normalized != state) {
      state = normalized;
    }
    await _persist(normalized);
  }

  Future<AppInterfaceFontSettings> _normalizeSettings(
    AppInterfaceFontSettings settings,
  ) async {
    if (settings.fontSource != AppInterfaceFontSource.custom) {
      return settings.copyWith(
        clearFontFamilyKey: true,
        clearCustomFontPath: true,
      );
    }

    final familyKey = settings.fontFamilyKey?.trim() ?? '';
    var customPath = settings.customFontPath?.trim() ?? '';
    if (familyKey.isEmpty) {
      return const AppInterfaceFontSettings();
    }

    if (customPath.isEmpty || !await File(customPath).exists()) {
      final fonts = await ReaderFontRegistryService().listRegisteredFonts();
      for (final entry in fonts) {
        if (entry.fontFamilyKey == familyKey) {
          customPath = entry.filePath;
          break;
        }
      }
    }

    if (customPath.isEmpty) {
      return const AppInterfaceFontSettings();
    }

    return settings.copyWith(customFontPath: customPath);
  }

  Future<void> _persist(AppInterfaceFontSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_fontSourceKey, settings.fontSource.name);
    await prefs.setString(_systemFontPresetKey, settings.systemFontPreset.name);

    final familyKey = settings.fontFamilyKey?.trim() ?? '';
    if (familyKey.isEmpty) {
      await prefs.remove(_fontFamilyKeyKey);
    } else {
      await prefs.setString(_fontFamilyKeyKey, familyKey);
    }

    final customPath = settings.customFontPath?.trim() ?? '';
    if (customPath.isEmpty) {
      await prefs.remove(_customFontPathKey);
    } else {
      await prefs.setString(_customFontPathKey, customPath);
    }
  }
}

class AppInterfaceTextScaleNotifier extends Notifier<double> {
  static const String _key = 'app.interfaceTextScale';
  static const double minScale = 0.6;
  static const double maxScale = 1.5;
  static const double defaultScale = 1.0;
  static double? _primedValue;

  bool _loadTriggered = false;
  bool _hasExplicitSet = false;

  static void prime(SharedPreferences prefs) {
    final stored = prefs.getDouble(_key);
    _primedValue = stored == null ? null : _normalize(stored);
  }

  @override
  double build() {
    final primedValue = _primedValue;
    if (primedValue != null) {
      return primedValue;
    }
    if (!_loadTriggered) {
      _loadTriggered = true;
      _load();
    }
    return defaultScale;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getDouble(_key);
    if (stored == null || _hasExplicitSet) {
      return;
    }
    final loaded = _normalize(stored);
    if (loaded != state) {
      state = loaded;
    }
  }

  Future<void> setScale(double scale) async {
    final normalized = _normalize(scale);
    _hasExplicitSet = true;
    _primedValue = normalized;
    if (normalized != state) {
      state = normalized;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_key, normalized);
  }

  static double _normalize(double value) {
    return value.clamp(minScale, maxScale).toDouble();
  }
}

class AppInterfaceFontWeightNotifier extends Notifier<int> {
  static const String _key = 'app.interfaceFontWeight';
  static const int minWeight = 100;
  static const int maxWeight = 900;
  static const int defaultWeight = 400;
  static int? _primedValue;

  bool _loadTriggered = false;
  bool _hasExplicitSet = false;

  static void prime(SharedPreferences prefs) {
    final stored = prefs.getInt(_key);
    _primedValue = stored == null ? null : _normalize(stored);
  }

  @override
  int build() {
    final primedValue = _primedValue;
    if (primedValue != null) {
      return primedValue;
    }
    if (!_loadTriggered) {
      _loadTriggered = true;
      _load();
    }
    return defaultWeight;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getInt(_key);
    if (stored == null || _hasExplicitSet) {
      return;
    }
    final loaded = _normalize(stored);
    if (loaded != state) {
      state = loaded;
    }
  }

  Future<void> setWeight(int weight) async {
    final normalized = _normalize(weight);
    _hasExplicitSet = true;
    _primedValue = normalized;
    if (normalized != state) {
      state = normalized;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, normalized);
  }

  static int _normalize(int value) {
    const supportedWeights = <int>{100, 200, 300, 400, 500, 600, 700, 800, 900};
    if (supportedWeights.contains(value)) {
      return value;
    }
    final clamped = value.clamp(minWeight, maxWeight);
    final steps = <int>[100, 200, 300, 400, 500, 600, 700, 800, 900];
    return steps.reduce(
      (best, candidate) =>
          (candidate - clamped).abs() < (best - clamped).abs()
              ? candidate
              : best,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../preferences/app_preferences_service.dart';

final appSeedColorProvider = NotifierProvider<AppSeedColorNotifier, Color>(
  AppSeedColorNotifier.new,
);

class AppSeedColorNotifier extends Notifier<Color> {
  static const Color _defaultSeedColor = Color(0xFFFFFFFF);
  static Color? _primedSeedColor;

  bool _loadTriggered = false;
  bool _hasExplicitSet = false;

  static void prime(SharedPreferences prefs) {
    final stored = prefs.getInt(appSeedColorPreferenceKey);
    _primedSeedColor = stored == null ? null : Color(stored);
  }

  @override
  Color build() {
    final primedSeedColor = _primedSeedColor;
    if (primedSeedColor != null) {
      return primedSeedColor;
    }
    if (!_loadTriggered) {
      _loadTriggered = true;
      _load();
    }

    return _defaultSeedColor;
  }

  Future<void> _load() async {
    final stored =
        await ref.read(appThemePreferencesServiceProvider).loadSeedColorValue();
    if (stored == null) {
      return;
    }

    if (_hasExplicitSet) {
      return;
    }

    final color = Color(stored);
    if (color != state) {
      state = color;
    }
  }

  Future<void> setSeedColor(Color color) async {
    _hasExplicitSet = true;
    _primedSeedColor = color;
    if (color != state) {
      state = color;
    }

    await ref
        .read(appThemePreferencesServiceProvider)
        .saveSeedColorValue(color.toARGB32());
  }
}

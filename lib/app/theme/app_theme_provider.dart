import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final appThemeModeProvider = NotifierProvider<AppThemeModeNotifier, ThemeMode>(
  AppThemeModeNotifier.new,
);

class AppThemeModeNotifier extends Notifier<ThemeMode> {
  static const String _themeModeKey = 'app.themeMode';
  static ThemeMode? _primedThemeMode;

  bool _loadTriggered = false;
  bool _hasExplicitSet = false;

  static void prime(SharedPreferences prefs) {
    final raw = prefs.getString(_themeModeKey);
    _primedThemeMode = switch (raw) {
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => ThemeMode.light,
    };
  }

  @override
  ThemeMode build() {
    final primedThemeMode = _primedThemeMode;
    if (primedThemeMode != null) {
      return primedThemeMode;
    }
    if (!_loadTriggered) {
      _loadTriggered = true;
      _load();
    }
    return ThemeMode.light;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_themeModeKey);

    final loaded = switch (raw) {
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => ThemeMode.light,
    };

    if (_hasExplicitSet) {
      return;
    }

    if (loaded != state) {
      state = loaded;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _hasExplicitSet = true;
    _primedThemeMode = mode;
    if (state != mode) {
      state = mode;
    }

    final prefs = await SharedPreferences.getInstance();
    final raw = switch (mode) {
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
      ThemeMode.light => 'light',
    };
    await prefs.setString(_themeModeKey, raw);
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final appSeedColorProvider = NotifierProvider<AppSeedColorNotifier, Color>(
  AppSeedColorNotifier.new,
);

class AppSeedColorNotifier extends Notifier<Color> {
  static const String _seedColorKey = 'app.seedColor';
  static const Color _defaultSeedColor = Color(0xFFFFFFFF);
  static Color? _primedSeedColor;

  bool _loadTriggered = false;
  bool _hasExplicitSet = false;

  static void prime(SharedPreferences prefs) {
    final stored = prefs.getInt(_seedColorKey);
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
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getInt(_seedColorKey);
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

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_seedColorKey, color.toARGB32());
  }
}

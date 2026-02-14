import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final appSeedColorProvider = NotifierProvider<AppSeedColorNotifier, Color>(
  AppSeedColorNotifier.new,
);

class AppSeedColorNotifier extends Notifier<Color> {
  static const String _seedColorKey = 'app.seedColor';

  bool _loadTriggered = false;
  bool _hasExplicitSet = false;

  @override
  Color build() {
    if (!_loadTriggered) {
      _loadTriggered = true;
      _load();
    }

    return const Color(0xFF6750A4);
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
    if (color != state) {
      state = color;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_seedColorKey, color.toARGB32());
  }
}

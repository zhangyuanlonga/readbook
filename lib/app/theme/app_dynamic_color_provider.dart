import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final appDynamicColorEnabledProvider =
    NotifierProvider<AppDynamicColorEnabledNotifier, bool>(
  AppDynamicColorEnabledNotifier.new,
);

class AppDynamicColorEnabledNotifier extends Notifier<bool> {
  static const String _key = 'app.dynamicColor.enabled';

  bool _loadTriggered = false;
  bool _hasExplicitSet = false;

  @override
  bool build() {
    if (!_loadTriggered) {
      _loadTriggered = true;
      _load();
    }

    return false;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getBool(_key);
    if (stored == null) {
      return;
    }

    if (_hasExplicitSet) {
      return;
    }

    if (stored != state) {
      state = stored;
    }
  }

  Future<void> setEnabled(bool enabled) async {
    _hasExplicitSet = true;
    if (enabled != state) {
      state = enabled;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, enabled);
  }
}

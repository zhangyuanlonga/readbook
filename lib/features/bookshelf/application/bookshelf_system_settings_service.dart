import 'package:shared_preferences/shared_preferences.dart';

class BookshelfSystemSettingsService {
  BookshelfSystemSettingsService({SharedPreferences? preferences})
    : _preferencesFuture =
          preferences == null
              ? SharedPreferences.getInstance()
              : Future.value(preferences);

  final Future<SharedPreferences> _preferencesFuture;

  static const String _autoRefreshOnTabActiveEnabledKey =
      'bookshelf.system.autoRefreshOnTabActiveEnabled';

  Future<bool> loadAutoRefreshOnTabActiveEnabled() async {
    final prefs = await _preferencesFuture;
    return prefs.getBool(_autoRefreshOnTabActiveEnabledKey) ?? true;
  }

  Future<void> saveAutoRefreshOnTabActiveEnabled(bool enabled) async {
    final prefs = await _preferencesFuture;
    await prefs.setBool(_autoRefreshOnTabActiveEnabledKey, enabled);
  }
}

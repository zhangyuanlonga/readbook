import 'package:shared_preferences/shared_preferences.dart';

class SearchSystemSettingsService {
  SearchSystemSettingsService({SharedPreferences? preferences})
    : _preferencesFuture =
          preferences == null
              ? SharedPreferences.getInstance()
              : Future.value(preferences);

  final Future<SharedPreferences> _preferencesFuture;

  static const String _aggregateByTitleAuthorEnabledKey =
      'search.system.aggregateByTitleAuthorEnabled';

  Future<bool> loadAggregateByTitleAuthorEnabled() async {
    final prefs = await _preferencesFuture;
    return prefs.getBool(_aggregateByTitleAuthorEnabledKey) ?? true;
  }

  Future<void> saveAggregateByTitleAuthorEnabled(bool enabled) async {
    final prefs = await _preferencesFuture;
    await prefs.setBool(_aggregateByTitleAuthorEnabledKey, enabled);
  }
}

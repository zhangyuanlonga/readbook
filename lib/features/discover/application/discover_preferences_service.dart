import 'package:shared_preferences/shared_preferences.dart';

class DiscoverPreferencesService {
  DiscoverPreferencesService({SharedPreferences? preferences})
    : _preferencesFuture =
          preferences == null
              ? SharedPreferences.getInstance()
              : Future.value(preferences);

  static const String _selectedSourceIdKey = 'discover.selectedSourceId';

  final Future<SharedPreferences> _preferencesFuture;

  Future<String?> loadSelectedSourceId() async {
    final prefs = await _preferencesFuture;
    final raw = prefs.getString(_selectedSourceIdKey);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    return raw.trim();
  }

  Future<void> saveSelectedSourceId(String? sourceId) async {
    final prefs = await _preferencesFuture;
    final normalized = sourceId?.trim() ?? '';
    if (normalized.isEmpty) {
      await prefs.remove(_selectedSourceIdKey);
      return;
    }
    await prefs.setString(_selectedSourceIdKey, normalized);
  }
}

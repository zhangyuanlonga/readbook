import 'package:shared_preferences/shared_preferences.dart';

const String appDataVersionPreferenceKey = 'app.data_version';
const int currentAppDataVersion = 3;

class AppDataVersionStore {
  AppDataVersionStore({SharedPreferences? preferences})
    : _preferencesFuture =
          preferences == null
              ? SharedPreferences.getInstance()
              : Future.value(preferences);

  final Future<SharedPreferences> _preferencesFuture;

  Future<int> read() async {
    final prefs = await _preferencesFuture;
    return prefs.getInt(appDataVersionPreferenceKey) ?? 0;
  }

  Future<void> write(int version) async {
    final prefs = await _preferencesFuture;
    await prefs.setInt(appDataVersionPreferenceKey, version);
  }
}

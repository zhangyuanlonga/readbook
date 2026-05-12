import 'package:shared_preferences/shared_preferences.dart';

class SourceHealthSystemSettingsService {
  SourceHealthSystemSettingsService({SharedPreferences? preferences})
    : _preferencesFuture =
          preferences == null
              ? SharedPreferences.getInstance()
              : Future.value(preferences);

  static const String _autoDisableHighRiskSourcesEnabledKey =
      'source.health.autoDisableHighRiskSourcesEnabled';

  final Future<SharedPreferences> _preferencesFuture;

  Future<bool> loadAutoDisableHighRiskSourcesEnabled() async {
    final prefs = await _preferencesFuture;
    return prefs.getBool(_autoDisableHighRiskSourcesEnabledKey) ?? false;
  }

  Future<void> saveAutoDisableHighRiskSourcesEnabled(bool enabled) async {
    final prefs = await _preferencesFuture;
    await prefs.setBool(_autoDisableHighRiskSourcesEnabledKey, enabled);
  }
}

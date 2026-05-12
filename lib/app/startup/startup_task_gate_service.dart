import 'package:shared_preferences/shared_preferences.dart';

class StartupTaskGateService {
  StartupTaskGateService({SharedPreferences? preferences})
    : _preferencesFuture =
          preferences == null
              ? SharedPreferences.getInstance()
              : Future.value(preferences);

  final Future<SharedPreferences> _preferencesFuture;

  Future<bool> claimDailyRun(String key, {DateTime? now}) async {
    final normalizedKey = key.trim();
    if (normalizedKey.isEmpty) {
      return true;
    }
    final prefs = await _preferencesFuture;
    final todayKey = _dayKey(now ?? DateTime.now());
    final storageKey = 'startup.taskGate.$normalizedKey';
    final lastRun = prefs.getString(storageKey)?.trim();
    if (lastRun == todayKey) {
      return false;
    }
    await prefs.setString(storageKey, todayKey);
    return true;
  }

  String _dayKey(DateTime dateTime) {
    final local = dateTime.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }
}

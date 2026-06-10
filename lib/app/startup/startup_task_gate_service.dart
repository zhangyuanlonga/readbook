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

  Future<bool> claimIntervalRun(
    String key, {
    required Duration minInterval,
    DateTime? now,
  }) async {
    final normalizedKey = key.trim();
    if (normalizedKey.isEmpty || minInterval <= Duration.zero) {
      return true;
    }
    final prefs = await _preferencesFuture;
    final storageKey = 'startup.taskGateAt.$normalizedKey';
    final currentTime = (now ?? DateTime.now()).toUtc();
    final lastRunRaw = prefs.getString(storageKey)?.trim();
    final lastRun =
        lastRunRaw == null || lastRunRaw.isEmpty
            ? null
            : DateTime.tryParse(lastRunRaw)?.toUtc();
    if (lastRun != null && currentTime.difference(lastRun) < minInterval) {
      return false;
    }
    await prefs.setString(storageKey, currentTime.toIso8601String());
    return true;
  }

  String _dayKey(DateTime dateTime) {
    final local = dateTime.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }
}

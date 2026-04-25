import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeEngagementState {
  const HomeEngagementState({
    this.dailyGoalMinutes = HomeEngagementService.defaultDailyGoalMinutes,
    this.checkInDateKeys = const <String>[],
  });

  final int dailyGoalMinutes;
  final List<String> checkInDateKeys;

  bool isCheckedInOn(DateTime time) {
    return checkInDateKeys.contains(_dateKeyFor(time));
  }

  int streakDays({DateTime? anchor}) {
    if (checkInDateKeys.isEmpty) {
      return 0;
    }

    final today = _dateOnly(anchor ?? DateTime.now());
    final dates = checkInDateKeys
      .map(DateTime.tryParse)
      .whereType<DateTime>()
      .map(_dateOnly)
      .toSet()
      .toList(growable: false)..sort((a, b) => b.compareTo(a));

    if (dates.isEmpty) {
      return 0;
    }

    final firstGap = today.difference(dates.first).inDays;
    if (firstGap > 1) {
      return 0;
    }

    var streak = 0;
    var cursor = dates.first;
    for (final date in dates) {
      if (date == cursor) {
        streak += 1;
        cursor = cursor.subtract(const Duration(days: 1));
        continue;
      }
      break;
    }
    return streak;
  }

  int recentCheckInCount(int days, {DateTime? anchor}) {
    if (days <= 0 || checkInDateKeys.isEmpty) {
      return 0;
    }

    final end = _dateOnly(anchor ?? DateTime.now());
    return checkInDateKeys
        .map(DateTime.tryParse)
        .whereType<DateTime>()
        .map(_dateOnly)
        .where((date) {
          final diff = end.difference(date).inDays;
          return diff >= 0 && diff < days;
        })
        .length;
  }

  HomeEngagementState copyWith({
    int? dailyGoalMinutes,
    List<String>? checkInDateKeys,
  }) {
    return HomeEngagementState(
      dailyGoalMinutes: dailyGoalMinutes ?? this.dailyGoalMinutes,
      checkInDateKeys:
          checkInDateKeys == null
              ? this.checkInDateKeys
              : List<String>.unmodifiable(checkInDateKeys),
    );
  }
}

class HomeEngagementService {
  HomeEngagementService({SharedPreferences? preferences})
    : _preferencesFuture =
          preferences == null
              ? SharedPreferences.getInstance()
              : Future.value(preferences);

  static const int defaultDailyGoalMinutes = 5;
  static const int _maxStoredCheckInDays = 400;
  static const String _checkInDateKeysKey = 'home.engagement.check_in_dates.v1';
  static const String _dailyGoalMinutesKey = 'home.engagement.goal_minutes.v1';

  final Future<SharedPreferences> _preferencesFuture;

  Future<HomeEngagementState> loadState() async {
    final prefs = await _preferencesFuture;
    final normalizedGoalMinutes = _normalizeDailyGoalMinutes(
      prefs.getInt(_dailyGoalMinutesKey),
    );
    final rawDateKeys = prefs.getStringList(_checkInDateKeysKey) ?? const [];
    final normalizedDateKeys = _normalizeDateKeys(rawDateKeys);

    if (prefs.getInt(_dailyGoalMinutesKey) != normalizedGoalMinutes) {
      await prefs.setInt(_dailyGoalMinutesKey, normalizedGoalMinutes);
    }
    if (!listEquals(rawDateKeys, normalizedDateKeys)) {
      await prefs.setStringList(_checkInDateKeysKey, normalizedDateKeys);
    }

    return HomeEngagementState(
      dailyGoalMinutes: normalizedGoalMinutes,
      checkInDateKeys: List<String>.unmodifiable(normalizedDateKeys),
    );
  }

  Future<HomeEngagementState> checkInToday({DateTime? now}) async {
    final prefs = await _preferencesFuture;
    final current = await loadState();
    final dateKey = _dateKeyFor(now ?? DateTime.now());
    if (current.checkInDateKeys.contains(dateKey)) {
      return current;
    }

    final updatedDateKeys = _normalizeDateKeys(<String>[
      ...current.checkInDateKeys,
      dateKey,
    ]);
    await prefs.setStringList(_checkInDateKeysKey, updatedDateKeys);

    return current.copyWith(checkInDateKeys: updatedDateKeys);
  }

  Future<HomeEngagementState> saveDailyGoalMinutes(int minutes) async {
    final prefs = await _preferencesFuture;
    final normalized = _normalizeDailyGoalMinutes(minutes);
    await prefs.setInt(_dailyGoalMinutesKey, normalized);
    final current = await loadState();
    return current.copyWith(dailyGoalMinutes: normalized);
  }

  int _normalizeDailyGoalMinutes(int? input) {
    final value = input ?? defaultDailyGoalMinutes;
    return value.clamp(1, 720);
  }

  List<String> _normalizeDateKeys(List<String> rawDateKeys) {
    final normalized = rawDateKeys
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .map((item) => DateTime.tryParse(item))
      .whereType<DateTime>()
      .map(_dateKeyFor)
      .toSet()
      .toList(growable: false)..sort();

    if (normalized.length <= _maxStoredCheckInDays) {
      return normalized;
    }
    return normalized.sublist(normalized.length - _maxStoredCheckInDays);
  }
}

DateTime _dateOnly(DateTime time) {
  final local = time.toLocal();
  return DateTime(local.year, local.month, local.day);
}

String _dateKeyFor(DateTime time) {
  final local = time.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}

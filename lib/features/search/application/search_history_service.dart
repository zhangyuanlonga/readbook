import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class SearchHistoryService {
  SearchHistoryService({SharedPreferences? preferences})
    : _preferencesFuture =
          preferences == null
              ? SharedPreferences.getInstance()
              : Future.value(preferences);

  final Future<SharedPreferences> _preferencesFuture;

  static const String _storageKey = 'search.history';
  static const int _maxHistoryCount = 15;

  Future<List<String>> getAll() async {
    final prefs = await _preferencesFuture;
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <String>[];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <String>[];
      }

      return decoded
          .whereType<String>()
          .where((s) => s.trim().isNotEmpty)
          .toList(growable: false);
    } on FormatException {
      return const <String>[];
    }
  }

  Future<void> add(String keyword) async {
    final trimmed = keyword.trim();
    if (trimmed.isEmpty) {
      return;
    }

    final all = (await getAll()).toList(growable: true);
    all.remove(trimmed);
    all.insert(0, trimmed);

    if (all.length > _maxHistoryCount) {
      all.removeRange(_maxHistoryCount, all.length);
    }

    await _save(all);
  }

  Future<void> remove(String keyword) async {
    final all = (await getAll())
        .where((item) => item != keyword.trim())
        .toList(growable: false);
    await _save(all);
  }

  Future<void> clear() async {
    final prefs = await _preferencesFuture;
    await prefs.remove(_storageKey);
  }

  Future<void> _save(List<String> history) async {
    final prefs = await _preferencesFuture;
    await prefs.setString(_storageKey, jsonEncode(history));
  }
}

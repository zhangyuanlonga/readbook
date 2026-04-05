import 'package:flutter/foundation.dart';
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
  static const String _searchDebugLogEnabledKey =
      'search.system.debugLogEnabled';
  static const String _maxConcurrentSourcesKey =
      'search.system.maxConcurrentSources';
  static const int minMaxConcurrentSources = 1;
  static int get defaultMaxConcurrentSources => _isDesktopPlatform ? 8 : 4;
  static int get maxMaxConcurrentSources => _isDesktopPlatform ? 12 : 6;

  static bool get _isDesktopPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux);

  Future<bool> loadAggregateByTitleAuthorEnabled() async => true;

  Future<void> saveAggregateByTitleAuthorEnabled(bool enabled) async {
    final prefs = await _preferencesFuture;
    await prefs.remove(_aggregateByTitleAuthorEnabledKey);
  }

  Future<bool> loadSearchDebugLogEnabled() async {
    final prefs = await _preferencesFuture;
    return prefs.getBool(_searchDebugLogEnabledKey) ?? false;
  }

  Future<void> saveSearchDebugLogEnabled(bool enabled) async {
    final prefs = await _preferencesFuture;
    await prefs.setBool(_searchDebugLogEnabledKey, enabled);
  }

  Future<int> loadMaxConcurrentSources() async {
    final prefs = await _preferencesFuture;
    final raw = prefs.getInt(_maxConcurrentSourcesKey);
    if (raw == null) {
      return defaultMaxConcurrentSources;
    }
    return raw.clamp(minMaxConcurrentSources, maxMaxConcurrentSources);
  }

  Future<void> saveMaxConcurrentSources(int value) async {
    final prefs = await _preferencesFuture;
    final normalized = value.clamp(
      minMaxConcurrentSources,
      maxMaxConcurrentSources,
    );
    await prefs.setInt(_maxConcurrentSourcesKey, normalized);
  }
}

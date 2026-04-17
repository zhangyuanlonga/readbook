import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

class ReaderSystemSettingsService {
  ReaderSystemSettingsService({SharedPreferences? preferences})
    : _preferencesFuture =
          preferences == null
              ? SharedPreferences.getInstance()
              : Future.value(preferences);

  final Future<SharedPreferences> _preferencesFuture;

  static const String _autoSwitchSourceOnFailureKey =
      'reader.system.autoSwitchSourceOnFailure';
  static const String _readRecordEnabledKey = 'reader.system.readRecordEnabled';
  static const String _localTxtSplitLongChapterEnabledKey =
      'reader.system.localTxtSplitLongChapterEnabled';

  Future<bool> loadAutoSwitchSourceOnFailureEnabled() async => true;

  Future<void> saveAutoSwitchSourceOnFailureEnabled(bool enabled) async {
    final prefs = await _preferencesFuture;
    await prefs.remove(_autoSwitchSourceOnFailureKey);
  }

  Future<bool> loadReadRecordEnabled() async => true;

  Future<bool> loadLocalTxtSplitLongChapterEnabled() async {
    final prefs = await _preferencesFuture;
    return prefs.getBool(_localTxtSplitLongChapterEnabledKey) ?? true;
  }

  Stream<bool> watchReadRecordEnabled() {
    return Stream<bool>.value(true).asBroadcastStream();
  }

  Future<void> saveReadRecordEnabled(bool enabled) async {
    final prefs = await _preferencesFuture;
    await prefs.remove(_readRecordEnabledKey);
  }

  Future<void> saveLocalTxtSplitLongChapterEnabled(bool enabled) async {
    final prefs = await _preferencesFuture;
    await prefs.setBool(_localTxtSplitLongChapterEnabledKey, enabled);
  }
}

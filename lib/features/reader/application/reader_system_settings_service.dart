import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

class ReaderSystemSettingsService {
  ReaderSystemSettingsService({SharedPreferences? preferences})
    : _preferencesFuture =
          preferences == null
              ? SharedPreferences.getInstance()
              : Future.value(preferences);

  final Future<SharedPreferences> _preferencesFuture;

  static final StreamController<bool> _readRecordEnabledController =
      StreamController<bool>.broadcast();

  static const String _autoSwitchSourceOnFailureKey =
      'reader.system.autoSwitchSourceOnFailure';
  static const String _readRecordEnabledKey = 'reader.system.readRecordEnabled';
  static const String _localTxtSplitLongChapterEnabledKey =
      'reader.system.localTxtSplitLongChapterEnabled';

  Future<bool> loadAutoSwitchSourceOnFailureEnabled() async {
    final prefs = await _preferencesFuture;
    return prefs.getBool(_autoSwitchSourceOnFailureKey) ?? true;
  }

  Future<void> saveAutoSwitchSourceOnFailureEnabled(bool enabled) async {
    final prefs = await _preferencesFuture;
    await prefs.setBool(_autoSwitchSourceOnFailureKey, enabled);
  }

  Future<bool> loadReadRecordEnabled() async {
    final prefs = await _preferencesFuture;
    return prefs.getBool(_readRecordEnabledKey) ?? true;
  }

  Future<bool> loadLocalTxtSplitLongChapterEnabled() async {
    final prefs = await _preferencesFuture;
    return prefs.getBool(_localTxtSplitLongChapterEnabledKey) ?? true;
  }

  Stream<bool> watchReadRecordEnabled() {
    return (() async* {
      yield await loadReadRecordEnabled();
      yield* _readRecordEnabledController.stream.distinct();
    }()).asBroadcastStream();
  }

  Future<void> saveReadRecordEnabled(bool enabled) async {
    final prefs = await _preferencesFuture;
    await prefs.setBool(_readRecordEnabledKey, enabled);
    _readRecordEnabledController.add(enabled);
  }

  Future<void> saveLocalTxtSplitLongChapterEnabled(bool enabled) async {
    final prefs = await _preferencesFuture;
    await prefs.setBool(_localTxtSplitLongChapterEnabledKey, enabled);
  }
}

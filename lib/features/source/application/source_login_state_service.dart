import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../domain/entities/book_custom_state.dart';
import '../../../domain/entities/source_login_state.dart';

class SourceLoginStateService {
  SourceLoginStateService({SharedPreferences? preferences})
    : _preferencesFuture =
          preferences == null
              ? SharedPreferences.getInstance()
              : Future.value(preferences);

  static const String _sourceLoginStateStorageKey = 'source.login.states.v1';
  static const String _bookCustomStateStorageKey =
      'source.book.custom.states.v1';

  final Future<SharedPreferences> _preferencesFuture;

  Future<Map<String, SourceLoginState>> loadSourceLoginStates() async {
    final prefs = await _preferencesFuture;
    return _decodeSourceLoginStates(
      prefs.getString(_sourceLoginStateStorageKey),
    );
  }

  Future<SourceLoginState?> loadSourceLoginState(String sourceId) async {
    final normalizedSourceId = sourceId.trim();
    if (normalizedSourceId.isEmpty) {
      return null;
    }
    final states = await loadSourceLoginStates();
    return states[normalizedSourceId];
  }

  Future<void> saveSourceLoginState(SourceLoginState state) async {
    final normalizedSourceId = state.sourceId.trim();
    if (normalizedSourceId.isEmpty) {
      return;
    }

    final prefs = await _preferencesFuture;
    final states = _decodeSourceLoginStates(
      prefs.getString(_sourceLoginStateStorageKey),
    );

    if (state.isEmpty) {
      states.remove(normalizedSourceId);
    } else {
      states[normalizedSourceId] = state.copyWith(sourceId: normalizedSourceId);
    }

    await _saveSourceLoginStates(prefs, states);
  }

  Future<void> removeSourceLoginState(String sourceId) async {
    final normalizedSourceId = sourceId.trim();
    if (normalizedSourceId.isEmpty) {
      return;
    }

    final prefs = await _preferencesFuture;
    final states = _decodeSourceLoginStates(
      prefs.getString(_sourceLoginStateStorageKey),
    );
    states.remove(normalizedSourceId);
    await _saveSourceLoginStates(prefs, states);
  }

  Future<Map<String, BookCustomState>> loadBookCustomStates() async {
    final prefs = await _preferencesFuture;
    return _decodeBookCustomStates(prefs.getString(_bookCustomStateStorageKey));
  }

  Future<BookCustomState?> loadBookCustomState({
    required String bookId,
    required String sourceId,
    required String detailUrl,
  }) async {
    final lookupKey = _resolveBookCustomStorageKey(
      bookId: bookId,
      sourceId: sourceId,
      detailUrl: detailUrl,
    );
    if (lookupKey == null) {
      return null;
    }

    final states = await loadBookCustomStates();
    return states[lookupKey];
  }

  Future<void> saveBookCustomState(BookCustomState state) async {
    final lookupKey = _resolveBookCustomStorageKey(
      bookId: state.bookId,
      sourceId: state.sourceId,
      detailUrl: state.detailUrl,
    );
    if (lookupKey == null) {
      return;
    }

    final prefs = await _preferencesFuture;
    final states = _decodeBookCustomStates(
      prefs.getString(_bookCustomStateStorageKey),
    );

    if (state.isEmpty) {
      states.remove(lookupKey);
    } else {
      states[lookupKey] = state;
    }

    await _saveBookCustomStates(prefs, states);
  }

  Future<void> removeBookCustomState({
    required String bookId,
    required String sourceId,
    required String detailUrl,
  }) async {
    final lookupKey = _resolveBookCustomStorageKey(
      bookId: bookId,
      sourceId: sourceId,
      detailUrl: detailUrl,
    );
    if (lookupKey == null) {
      return;
    }

    final prefs = await _preferencesFuture;
    final states = _decodeBookCustomStates(
      prefs.getString(_bookCustomStateStorageKey),
    );
    states.remove(lookupKey);
    await _saveBookCustomStates(prefs, states);
  }

  Future<void> removeBookCustomStatesForSource(String sourceId) async {
    final normalizedSourceId = sourceId.trim();
    if (normalizedSourceId.isEmpty) {
      return;
    }

    final prefs = await _preferencesFuture;
    final states = _decodeBookCustomStates(
      prefs.getString(_bookCustomStateStorageKey),
    );
    states.removeWhere(
      (_, value) => value.sourceId.trim() == normalizedSourceId,
    );
    await _saveBookCustomStates(prefs, states);
  }

  Future<void> removeBookCustomStatesForBook(String bookId) async {
    final normalizedBookId = bookId.trim();
    if (normalizedBookId.isEmpty) {
      return;
    }

    final prefs = await _preferencesFuture;
    final states = _decodeBookCustomStates(
      prefs.getString(_bookCustomStateStorageKey),
    );
    states.removeWhere((_, value) => value.bookId.trim() == normalizedBookId);
    await _saveBookCustomStates(prefs, states);
  }

  Future<void> clearAllStates() async {
    final prefs = await _preferencesFuture;
    await prefs.remove(_sourceLoginStateStorageKey);
    await prefs.remove(_bookCustomStateStorageKey);
  }

  Future<void> _saveSourceLoginStates(
    SharedPreferences prefs,
    Map<String, SourceLoginState> states,
  ) async {
    if (states.isEmpty) {
      await prefs.remove(_sourceLoginStateStorageKey);
      return;
    }

    final payload = <String, Object?>{
      for (final entry in states.entries) entry.key: entry.value.toJson(),
    };
    await prefs.setString(_sourceLoginStateStorageKey, jsonEncode(payload));
  }

  Future<void> _saveBookCustomStates(
    SharedPreferences prefs,
    Map<String, BookCustomState> states,
  ) async {
    if (states.isEmpty) {
      await prefs.remove(_bookCustomStateStorageKey);
      return;
    }

    final payload = <String, Object?>{
      for (final entry in states.entries) entry.key: entry.value.toJson(),
    };
    await prefs.setString(_bookCustomStateStorageKey, jsonEncode(payload));
  }

  Map<String, SourceLoginState> _decodeSourceLoginStates(String? raw) {
    final normalized = (raw ?? '').trim();
    if (normalized.isEmpty) {
      return <String, SourceLoginState>{};
    }

    try {
      final decoded = jsonDecode(normalized);
      if (decoded is! Map) {
        return <String, SourceLoginState>{};
      }
      final states = <String, SourceLoginState>{};
      for (final entry in decoded.entries) {
        final key = entry.key.toString().trim();
        final value = entry.value;
        if (key.isEmpty || value is! Map) {
          continue;
        }
        states[key] = SourceLoginState.fromJson(
          Map<String, dynamic>.from(
            value.map((mapKey, item) => MapEntry(mapKey.toString(), item)),
          ),
        );
      }
      return states;
    } catch (_) {
      return <String, SourceLoginState>{};
    }
  }

  Map<String, BookCustomState> _decodeBookCustomStates(String? raw) {
    final normalized = (raw ?? '').trim();
    if (normalized.isEmpty) {
      return <String, BookCustomState>{};
    }

    try {
      final decoded = jsonDecode(normalized);
      if (decoded is! Map) {
        return <String, BookCustomState>{};
      }
      final states = <String, BookCustomState>{};
      for (final entry in decoded.entries) {
        final key = entry.key.toString().trim();
        final value = entry.value;
        if (key.isEmpty || value is! Map) {
          continue;
        }
        states[key] = BookCustomState.fromJson(
          Map<String, dynamic>.from(
            value.map((mapKey, item) => MapEntry(mapKey.toString(), item)),
          ),
        );
      }
      return states;
    } catch (_) {
      return <String, BookCustomState>{};
    }
  }

  String? _resolveBookCustomStorageKey({
    required String bookId,
    required String sourceId,
    required String detailUrl,
  }) {
    final normalizedSourceId = sourceId.trim();
    final normalizedBookId = bookId.trim();
    final normalizedDetailUrl = detailUrl.trim();
    if (normalizedSourceId.isEmpty ||
        (normalizedBookId.isEmpty && normalizedDetailUrl.isEmpty)) {
      return null;
    }

    if (normalizedDetailUrl.isNotEmpty) {
      return '$normalizedSourceId::$normalizedDetailUrl';
    }
    return '$normalizedSourceId::$normalizedBookId';
  }
}

import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

class SourceSwitchScoreStore {
  SourceSwitchScoreStore({
    required this.sourceScores,
    required this.bookScores,
  });

  final Map<String, int> sourceScores;
  final Map<String, int> bookScores;
}

class SourceSwitchScoreUpdate {
  const SourceSwitchScoreUpdate({
    required this.bookScoreKey,
    required this.bookScore,
    required this.sourceScore,
  });

  final String bookScoreKey;
  final int bookScore;
  final int sourceScore;
}

class SourceSwitchScoreService {
  SourceSwitchScoreService({SharedPreferences? preferences})
    : _preferencesFuture =
          preferences == null
              ? SharedPreferences.getInstance()
              : Future.value(preferences);

  final Future<SharedPreferences> _preferencesFuture;

  static const String _sourcePrefix = 'reader.switch_source.source_score.';
  static const String _bookPrefix = 'reader.switch_source.book_score.';
  static final RegExp _spacePattern = RegExp(r'[\u3000\s]+');
  static final RegExp _symbolPattern = RegExp(
    r'''[·•\-_:：|/\\\(\)\[\]【】<>《》"'‘’,.，。!?！？]''',
  );
  static const int _minScore = -999;
  static const int _maxScore = 999;

  Future<SourceSwitchScoreStore> loadStore() async {
    final prefs = await _preferencesFuture;
    final sourceScores = <String, int>{};
    final bookScores = <String, int>{};

    for (final key in prefs.getKeys()) {
      if (key.startsWith(_sourcePrefix)) {
        final sourceId = key.substring(_sourcePrefix.length).trim();
        if (sourceId.isEmpty) {
          continue;
        }
        final value = prefs.getInt(key) ?? 0;
        if (value != 0) {
          sourceScores[sourceId] = value;
        }
        continue;
      }
      if (key.startsWith(_bookPrefix)) {
        final scoreKey = key.substring(_bookPrefix.length).trim();
        if (scoreKey.isEmpty) {
          continue;
        }
        final value = prefs.getInt(key) ?? 0;
        if (value != 0) {
          bookScores[scoreKey] = value;
        }
      }
    }

    return SourceSwitchScoreStore(
      sourceScores: sourceScores,
      bookScores: bookScores,
    );
  }

  String buildBookScoreKey({
    required String sourceId,
    required String title,
    String? author,
  }) {
    final normalizedSourceId = sourceId.trim();
    final normalizedTitle = _normalizeText(title);
    final normalizedAuthor = _normalizeText(author ?? '');
    return '$normalizedSourceId|$normalizedTitle|$normalizedAuthor';
  }

  Future<SourceSwitchScoreUpdate> adjustBookScore({
    required String sourceId,
    required String title,
    String? author,
    required int delta,
  }) async {
    if (delta == 0) {
      return _loadCurrentScore(
        sourceId: sourceId,
        title: title,
        author: author,
      );
    }

    final normalizedSourceId = sourceId.trim();
    if (normalizedSourceId.isEmpty) {
      throw ArgumentError('sourceId must not be empty');
    }

    final prefs = await _preferencesFuture;
    final bookScoreKey = buildBookScoreKey(
      sourceId: normalizedSourceId,
      title: title,
      author: author,
    );
    final fullBookKey = '$_bookPrefix$bookScoreKey';
    final fullSourceKey = '$_sourcePrefix$normalizedSourceId';

    final oldBookScore = prefs.getInt(fullBookKey) ?? 0;
    final oldSourceScore = prefs.getInt(fullSourceKey) ?? 0;

    final nextBookScore = _clampScore(oldBookScore + delta);
    final appliedDelta = nextBookScore - oldBookScore;
    final nextSourceScore = _clampScore(oldSourceScore + appliedDelta);

    if (nextBookScore == 0) {
      await prefs.remove(fullBookKey);
    } else {
      await prefs.setInt(fullBookKey, nextBookScore);
    }

    if (nextSourceScore == 0) {
      await prefs.remove(fullSourceKey);
    } else {
      await prefs.setInt(fullSourceKey, nextSourceScore);
    }

    return SourceSwitchScoreUpdate(
      bookScoreKey: bookScoreKey,
      bookScore: nextBookScore,
      sourceScore: nextSourceScore,
    );
  }

  Future<SourceSwitchScoreUpdate> resetBookScore({
    required String sourceId,
    required String title,
    String? author,
  }) async {
    final normalizedSourceId = sourceId.trim();
    if (normalizedSourceId.isEmpty) {
      throw ArgumentError('sourceId must not be empty');
    }

    final prefs = await _preferencesFuture;
    final bookScoreKey = buildBookScoreKey(
      sourceId: normalizedSourceId,
      title: title,
      author: author,
    );
    final fullBookKey = '$_bookPrefix$bookScoreKey';
    final fullSourceKey = '$_sourcePrefix$normalizedSourceId';

    final oldBookScore = prefs.getInt(fullBookKey) ?? 0;
    final oldSourceScore = prefs.getInt(fullSourceKey) ?? 0;
    final nextSourceScore = _clampScore(oldSourceScore - oldBookScore);

    await prefs.remove(fullBookKey);
    if (nextSourceScore == 0) {
      await prefs.remove(fullSourceKey);
    } else {
      await prefs.setInt(fullSourceKey, nextSourceScore);
    }

    return SourceSwitchScoreUpdate(
      bookScoreKey: bookScoreKey,
      bookScore: 0,
      sourceScore: nextSourceScore,
    );
  }

  Future<SourceSwitchScoreUpdate> _loadCurrentScore({
    required String sourceId,
    required String title,
    String? author,
  }) async {
    final normalizedSourceId = sourceId.trim();
    final prefs = await _preferencesFuture;
    final bookScoreKey = buildBookScoreKey(
      sourceId: normalizedSourceId,
      title: title,
      author: author,
    );
    final fullBookKey = '$_bookPrefix$bookScoreKey';
    final fullSourceKey = '$_sourcePrefix$normalizedSourceId';

    return SourceSwitchScoreUpdate(
      bookScoreKey: bookScoreKey,
      bookScore: prefs.getInt(fullBookKey) ?? 0,
      sourceScore: prefs.getInt(fullSourceKey) ?? 0,
    );
  }

  String _normalizeText(String text) {
    return text
        .trim()
        .toLowerCase()
        .replaceAll(_spacePattern, '')
        .replaceAll(_symbolPattern, '');
  }

  int _clampScore(int value) {
    return min(_maxScore, max(_minScore, value));
  }
}

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../domain/entities/bookshelf_book.dart';

class BookshelfService {
  BookshelfService({SharedPreferences? preferences})
    : _preferencesFuture =
          preferences == null
              ? SharedPreferences.getInstance()
              : Future.value(preferences);

  final Future<SharedPreferences> _preferencesFuture;

  static const String _storageKey = 'bookshelf.books';
  static const String _tagStorageKey = 'bookshelf.book_tags';
  static const String _viewModeGridKey = 'bookshelf.view.useGrid';

  Future<List<BookshelfBook>> getAll() async {
    final prefs = await _preferencesFuture;
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <BookshelfBook>[];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <BookshelfBook>[];
      }

      final items = decoded
          .whereType<Map>()
          .map(
            (item) => BookshelfBook.fromJson(
              item.map((key, value) => MapEntry(key.toString(), value)),
            ),
          )
          .toList(growable: false);

      return items.reversed.toList(growable: false);
    } on FormatException {
      return const <BookshelfBook>[];
    }
  }

  Future<void> upsert(BookshelfBook item) async {
    final all = (await getAll()).toList(growable: true);
    final index = all.indexWhere(
      (entry) =>
          entry.sourceId == item.sourceId && entry.detailUrl == item.detailUrl,
    );

    final value = item.copyWith(addedAt: DateTime.now());
    if (index >= 0) {
      all.removeAt(index);
    }
    all.insert(0, value);

    await _save(all);
  }

  Future<void> remove({
    required String sourceId,
    required String detailUrl,
  }) async {
    final all = (await getAll())
        .where(
          (item) => !(item.sourceId == sourceId && item.detailUrl == detailUrl),
        )
        .toList(growable: false);
    await _save(all);
    await removeBookTags(sourceId: sourceId, detailUrl: detailUrl);
  }

  Future<bool> contains({
    required String sourceId,
    required String detailUrl,
  }) async {
    final all = await getAll();
    return all.any(
      (item) => item.sourceId == sourceId && item.detailUrl == detailUrl,
    );
  }

  Future<bool> loadUseGridView() async {
    final prefs = await _preferencesFuture;
    return prefs.getBool(_viewModeGridKey) ?? false;
  }

  Future<void> saveUseGridView(bool useGridView) async {
    final prefs = await _preferencesFuture;
    await prefs.setBool(_viewModeGridKey, useGridView);
  }

  Future<Map<String, List<String>>> getTagMap() async {
    final prefs = await _preferencesFuture;
    final raw = prefs.getString(_tagStorageKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <String, List<String>>{};
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return const <String, List<String>>{};
      }

      final result = <String, List<String>>{};
      for (final entry in decoded.entries) {
        final key = entry.key.toString().trim();
        if (key.isEmpty) {
          continue;
        }
        if (entry.value is! List) {
          continue;
        }
        final tags = _normalizeTags((entry.value as List).map((e) => '$e'));
        if (tags.isEmpty) {
          continue;
        }
        result[key] = tags;
      }
      return result;
    } catch (_) {
      return const <String, List<String>>{};
    }
  }

  Future<void> setBookTags({
    required String sourceId,
    required String detailUrl,
    required List<String> tags,
  }) async {
    final key = _bookKey(sourceId: sourceId, detailUrl: detailUrl);
    if (key.isEmpty) {
      return;
    }

    final normalized = _normalizeTags(tags);
    final map = Map<String, List<String>>.from(await getTagMap());
    if (normalized.isEmpty) {
      map.remove(key);
    } else {
      map[key] = normalized;
    }

    await _saveTagMap(map);
  }

  Future<void> removeBookTags({
    required String sourceId,
    required String detailUrl,
  }) async {
    await setBookTags(sourceId: sourceId, detailUrl: detailUrl, tags: const []);
  }

  Future<int> renameTag({
    required String fromTag,
    required String toTag,
  }) async {
    final fromValues = _normalizeTags([fromTag]);
    final toValues = _normalizeTags([toTag]);
    if (fromValues.isEmpty || toValues.isEmpty) {
      return 0;
    }

    final from = fromValues.first;
    final to = toValues.first;
    if (from == to) {
      return 0;
    }

    final map = Map<String, List<String>>.from(await getTagMap());
    var affectedCount = 0;
    for (final entry in map.entries.toList(growable: false)) {
      final tags = _normalizeTags(entry.value);
      if (!tags.contains(from)) {
        continue;
      }
      affectedCount += 1;
      final updated = _normalizeTags(tags.map((tag) => tag == from ? to : tag));
      if (updated.isEmpty) {
        map.remove(entry.key);
      } else {
        map[entry.key] = updated;
      }
    }

    if (affectedCount <= 0) {
      return 0;
    }

    await _saveTagMap(map);
    return affectedCount;
  }

  Future<int> deleteTag(String tagName) async {
    final values = _normalizeTags([tagName]);
    if (values.isEmpty) {
      return 0;
    }
    final target = values.first;

    final map = Map<String, List<String>>.from(await getTagMap());
    var affectedCount = 0;
    for (final entry in map.entries.toList(growable: false)) {
      final tags = _normalizeTags(entry.value);
      if (!tags.contains(target)) {
        continue;
      }
      affectedCount += 1;
      final updated = tags
          .where((tag) => tag != target)
          .toList(growable: false);
      if (updated.isEmpty) {
        map.remove(entry.key);
      } else {
        map[entry.key] = updated;
      }
    }

    if (affectedCount <= 0) {
      return 0;
    }

    await _saveTagMap(map);
    return affectedCount;
  }

  Future<void> _save(List<BookshelfBook> books) async {
    final prefs = await _preferencesFuture;
    final encoded = jsonEncode(books.map((item) => item.toJson()).toList());
    await prefs.setString(_storageKey, encoded);
  }

  Future<void> _saveTagMap(Map<String, List<String>> map) async {
    final prefs = await _preferencesFuture;
    await prefs.setString(_tagStorageKey, jsonEncode(map));
  }

  static String _bookKey({
    required String sourceId,
    required String detailUrl,
  }) {
    final source = sourceId.trim();
    final detail = detailUrl.trim();
    if (source.isEmpty || detail.isEmpty) {
      return '';
    }
    return '$source::$detail';
  }

  static List<String> _normalizeTags(Iterable<String> values) {
    final result = <String>[];
    for (final raw in values) {
      final value = raw.trim();
      if (value.isEmpty) {
        continue;
      }
      if (!result.contains(value)) {
        result.add(value);
      }
    }
    return result;
  }
}

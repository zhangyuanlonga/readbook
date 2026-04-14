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
  static const String _tagOrderStorageKey = 'bookshelf.tag_order';
  static const String _baseFilterOrderStorageKey =
      'bookshelf.base_filter_order';
  static const String _viewModeGridKey = 'bookshelf.view.useGrid';
  static const String _sortModeKey = 'bookshelf.sort.mode';
  static const String _gridAdaptiveColumnsKey =
      'bookshelf.grid.adaptiveColumns';
  static const String _gridColumnCountKey = 'bookshelf.grid.columnCount';
  static const String _gridCrossSpacingKey = 'bookshelf.grid.crossSpacing';
  static const String _gridMainSpacingKey = 'bookshelf.grid.mainSpacing';
  static const String _gridShowTitleKey = 'bookshelf.grid.showTitle';
  static const String _gridShowAuthorKey = 'bookshelf.grid.showAuthor';
  static const String _gridShowLatestChapterKey =
      'bookshelf.grid.showLatestChapter';
  static const String _gridShowProgressBarKey =
      'bookshelf.grid.showProgressBar';
  static const String _listShowTitleKey = 'bookshelf.list.showTitle';
  static const String _listShowAuthorKey = 'bookshelf.list.showAuthor';
  static const String _listShowLatestChapterKey =
      'bookshelf.list.showLatestChapter';
  static const String _listShowProgressBarKey =
      'bookshelf.list.showProgressBar';

  static const String defaultSortMode = 'default';
  static const String recentReadSortMode = 'recentRead';
  static const String readingProgressSortMode = 'readingProgress';
  static const String createdAtSortMode = 'createdAt';
  static const String authorSortMode = 'author';
  static const String titleSortMode = 'title';
  static const bool defaultGridAdaptiveColumns = true;
  static const int defaultGridColumnCount = 3;
  static const double defaultGridCrossSpacing = 8;
  static const double defaultGridMainSpacing = 12;
  static const bool defaultGridShowTitle = true;
  static const bool defaultGridShowAuthor = true;
  static const bool defaultGridShowLatestChapter = true;
  static const bool defaultGridShowProgressBar = true;
  static const bool defaultListShowTitle = true;
  static const bool defaultListShowAuthor = true;
  static const bool defaultListShowLatestChapter = true;
  static const bool defaultListShowProgressBar = true;

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

  Future<void> replace({
    required String previousSourceId,
    required String previousDetailUrl,
    required BookshelfBook nextBook,
    bool preserveTags = true,
  }) async {
    final previousKey = _bookKey(
      sourceId: previousSourceId,
      detailUrl: previousDetailUrl,
    );
    final nextKey = _bookKey(
      sourceId: nextBook.sourceId,
      detailUrl: nextBook.detailUrl,
    );

    final all = (await getAll()).toList(growable: true);
    all.removeWhere((entry) {
      final entryKey = _bookKey(
        sourceId: entry.sourceId,
        detailUrl: entry.detailUrl,
      );
      if (entryKey.isEmpty) {
        return false;
      }
      return entryKey == previousKey || entryKey == nextKey;
    });
    all.insert(0, nextBook.copyWith(addedAt: DateTime.now()));
    await _save(all);

    final tagMap = Map<String, List<String>>.from(await getTagMap());
    final previousTags =
        previousKey.isEmpty
            ? const <String>[]
            : List<String>.from(tagMap[previousKey] ?? const <String>[]);
    if (previousKey.isNotEmpty) {
      tagMap.remove(previousKey);
    }

    if (nextKey.isNotEmpty) {
      final existingTags = List<String>.from(
        tagMap[nextKey] ?? const <String>[],
      );
      final merged =
          preserveTags
              ? _normalizeTags(<String>[...existingTags, ...previousTags])
              : _normalizeTags(existingTags);
      if (merged.isEmpty) {
        tagMap.remove(nextKey);
      } else {
        tagMap[nextKey] = merged;
      }
    }

    await _saveTagMap(tagMap);
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

  Future<bool> loadGridAdaptiveColumns() async {
    final prefs = await _preferencesFuture;
    return prefs.getBool(_gridAdaptiveColumnsKey) ?? defaultGridAdaptiveColumns;
  }

  Future<void> saveGridAdaptiveColumns(bool adaptive) async {
    final prefs = await _preferencesFuture;
    await prefs.setBool(_gridAdaptiveColumnsKey, adaptive);
  }

  Future<int> loadGridColumnCount() async {
    final prefs = await _preferencesFuture;
    final value = prefs.getInt(_gridColumnCountKey);
    return _normalizeGridColumnCount(value);
  }

  Future<void> saveGridColumnCount(int count) async {
    final prefs = await _preferencesFuture;
    await prefs.setInt(_gridColumnCountKey, _normalizeGridColumnCount(count));
  }

  Future<double> loadGridCrossSpacing() async {
    final prefs = await _preferencesFuture;
    final raw = prefs.getDouble(_gridCrossSpacingKey);
    return _normalizeGridSpacing(raw, fallback: defaultGridCrossSpacing);
  }

  Future<void> saveGridCrossSpacing(double spacing) async {
    final prefs = await _preferencesFuture;
    await prefs.setDouble(
      _gridCrossSpacingKey,
      _normalizeGridSpacing(spacing, fallback: defaultGridCrossSpacing),
    );
  }

  Future<double> loadGridMainSpacing() async {
    final prefs = await _preferencesFuture;
    final raw = prefs.getDouble(_gridMainSpacingKey);
    return _normalizeGridSpacing(raw, fallback: defaultGridMainSpacing);
  }

  Future<void> saveGridMainSpacing(double spacing) async {
    final prefs = await _preferencesFuture;
    await prefs.setDouble(
      _gridMainSpacingKey,
      _normalizeGridSpacing(spacing, fallback: defaultGridMainSpacing),
    );
  }

  Future<bool> loadGridShowTitle() async {
    final prefs = await _preferencesFuture;
    return prefs.getBool(_gridShowTitleKey) ?? defaultGridShowTitle;
  }

  Future<void> saveGridShowTitle(bool visible) async {
    final prefs = await _preferencesFuture;
    await prefs.setBool(_gridShowTitleKey, visible);
  }

  Future<bool> loadGridShowAuthor() async {
    final prefs = await _preferencesFuture;
    return prefs.getBool(_gridShowAuthorKey) ?? defaultGridShowAuthor;
  }

  Future<void> saveGridShowAuthor(bool visible) async {
    final prefs = await _preferencesFuture;
    await prefs.setBool(_gridShowAuthorKey, visible);
  }

  Future<bool> loadGridShowLatestChapter() async {
    final prefs = await _preferencesFuture;
    return prefs.getBool(_gridShowLatestChapterKey) ??
        defaultGridShowLatestChapter;
  }

  Future<void> saveGridShowLatestChapter(bool visible) async {
    final prefs = await _preferencesFuture;
    await prefs.setBool(_gridShowLatestChapterKey, visible);
  }

  Future<bool> loadGridShowProgressBar() async {
    final prefs = await _preferencesFuture;
    return prefs.getBool(_gridShowProgressBarKey) ?? defaultGridShowProgressBar;
  }

  Future<void> saveGridShowProgressBar(bool visible) async {
    final prefs = await _preferencesFuture;
    await prefs.setBool(_gridShowProgressBarKey, visible);
  }

  Future<bool> loadListShowTitle() async {
    final prefs = await _preferencesFuture;
    return prefs.getBool(_listShowTitleKey) ?? defaultListShowTitle;
  }

  Future<void> saveListShowTitle(bool visible) async {
    final prefs = await _preferencesFuture;
    await prefs.setBool(_listShowTitleKey, visible);
  }

  Future<bool> loadListShowAuthor() async {
    final prefs = await _preferencesFuture;
    return prefs.getBool(_listShowAuthorKey) ?? defaultListShowAuthor;
  }

  Future<void> saveListShowAuthor(bool visible) async {
    final prefs = await _preferencesFuture;
    await prefs.setBool(_listShowAuthorKey, visible);
  }

  Future<bool> loadListShowLatestChapter() async {
    final prefs = await _preferencesFuture;
    return prefs.getBool(_listShowLatestChapterKey) ??
        defaultListShowLatestChapter;
  }

  Future<void> saveListShowLatestChapter(bool visible) async {
    final prefs = await _preferencesFuture;
    await prefs.setBool(_listShowLatestChapterKey, visible);
  }

  Future<bool> loadListShowProgressBar() async {
    final prefs = await _preferencesFuture;
    return prefs.getBool(_listShowProgressBarKey) ?? defaultListShowProgressBar;
  }

  Future<void> saveListShowProgressBar(bool visible) async {
    final prefs = await _preferencesFuture;
    await prefs.setBool(_listShowProgressBarKey, visible);
  }

  Future<String> loadSortMode() async {
    final prefs = await _preferencesFuture;
    return _normalizeSortMode(prefs.getString(_sortModeKey));
  }

  Future<void> saveSortMode(String mode) async {
    final prefs = await _preferencesFuture;
    await prefs.setString(_sortModeKey, _normalizeSortMode(mode));
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

  Future<List<String>> getTagOrder() async {
    final prefs = await _preferencesFuture;
    final raw = prefs.getString(_tagOrderStorageKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <String>[];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <String>[];
      }
      return _normalizeTags(decoded.map((value) => '$value'));
    } catch (_) {
      return const <String>[];
    }
  }

  Future<void> saveTagOrder(List<String> orderedTags) async {
    final prefs = await _preferencesFuture;
    final normalized = _normalizeTags(orderedTags);
    if (normalized.isEmpty) {
      await prefs.remove(_tagOrderStorageKey);
      return;
    }
    await prefs.setString(_tagOrderStorageKey, jsonEncode(normalized));
  }

  Future<List<String>> getBaseFilterOrder() async {
    final prefs = await _preferencesFuture;
    final raw = prefs.getString(_baseFilterOrderStorageKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <String>[];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <String>[];
      }
      return _normalizeTags(decoded.map((value) => '$value'));
    } catch (_) {
      return const <String>[];
    }
  }

  Future<void> saveBaseFilterOrder(List<String> orderedFilters) async {
    final prefs = await _preferencesFuture;
    final normalized = _normalizeTags(orderedFilters);
    if (normalized.isEmpty) {
      await prefs.remove(_baseFilterOrderStorageKey);
      return;
    }
    await prefs.setString(_baseFilterOrderStorageKey, jsonEncode(normalized));
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
    final tagOrder = List<String>.from(await getTagOrder());
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
    await saveTagOrder(tagOrder.map((tag) => tag == from ? to : tag).toList());
    return affectedCount;
  }

  Future<int> deleteTag(String tagName) async {
    final values = _normalizeTags([tagName]);
    if (values.isEmpty) {
      return 0;
    }
    final target = values.first;

    final map = Map<String, List<String>>.from(await getTagMap());
    final tagOrder = List<String>.from(await getTagOrder());
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
    await saveTagOrder(
      tagOrder.where((tag) => tag != target).toList(growable: false),
    );
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

  static String _normalizeSortMode(String? value) {
    return switch (value?.trim()) {
      recentReadSortMode => recentReadSortMode,
      readingProgressSortMode => readingProgressSortMode,
      createdAtSortMode => createdAtSortMode,
      authorSortMode => authorSortMode,
      titleSortMode => titleSortMode,
      _ => defaultSortMode,
    };
  }

  static int _normalizeGridColumnCount(int? value) {
    return (value ?? defaultGridColumnCount).clamp(2, 6);
  }

  static double _normalizeGridSpacing(
    double? value, {
    required double fallback,
  }) {
    return (value ?? fallback).clamp(4.0, 24.0).toDouble();
  }
}

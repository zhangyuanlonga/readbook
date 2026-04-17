import 'dart:async';
import 'dart:isolate';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../domain/entities/bookshelf_book.dart';

enum BookshelfTaxonomyKind { tag, category }

enum BookshelfTaxonomyAction {
  create,
  rename,
  delete,
  orderChanged,
  assignmentChanged,
}

class BookshelfTaxonomyChange {
  const BookshelfTaxonomyChange({
    required this.kind,
    required this.action,
    this.previousName,
    this.currentName,
  });

  final BookshelfTaxonomyKind kind;
  final BookshelfTaxonomyAction action;
  final String? previousName;
  final String? currentName;
}

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
  static const String _categoryOrderStorageKey = 'bookshelf.category_order';
  static const String _baseFilterOrderStorageKey =
      'bookshelf.base_filter_order';
  static const String _viewSelectionKindKey = 'bookshelf.view.selection.kind';
  static const String _viewSelectionValueKey = 'bookshelf.view.selection.value';
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
  static final StreamController<BookshelfTaxonomyChange>
  _taxonomyChangeController =
      StreamController<BookshelfTaxonomyChange>.broadcast();

  static Stream<BookshelfTaxonomyChange> get watchTaxonomyChanges =>
      _taxonomyChangeController.stream;

  Future<List<BookshelfBook>> getAll() async {
    final prefs = await _preferencesFuture;
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <BookshelfBook>[];
    }

    try {
      final decoded = await Isolate.run<List<Map<String, Object?>>?>(
        () => _decodeBookshelfBookJsonMaps(raw),
      );
      if (decoded == null) {
        return const <BookshelfBook>[];
      }

      final items = decoded
          .map((item) => BookshelfBook.fromJson(item))
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
    String? previousCategory;
    for (final entry in all) {
      final entryKey = _bookKey(
        sourceId: entry.sourceId,
        detailUrl: entry.detailUrl,
      );
      if (entryKey == previousKey) {
        previousCategory = entry.category?.trim();
        break;
      }
    }
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
    all.insert(
      0,
      nextBook.copyWith(
        addedAt: DateTime.now(),
        category:
            preserveTags &&
                    (nextBook.category?.trim().isEmpty ?? true) &&
                    (previousCategory?.isNotEmpty ?? false)
                ? previousCategory
                : nextBook.category,
      ),
    );
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
    await removeBookCategory(sourceId: sourceId, detailUrl: detailUrl);
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
      return await Isolate.run<Map<String, List<String>>>(
        () => _decodeBookshelfTagMap(raw),
      );
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
      _emitTaxonomyChange(
        const BookshelfTaxonomyChange(
          kind: BookshelfTaxonomyKind.tag,
          action: BookshelfTaxonomyAction.orderChanged,
        ),
      );
      return;
    }
    await prefs.setString(_tagOrderStorageKey, jsonEncode(normalized));
    _emitTaxonomyChange(
      const BookshelfTaxonomyChange(
        kind: BookshelfTaxonomyKind.tag,
        action: BookshelfTaxonomyAction.orderChanged,
      ),
    );
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

  Future<Map<String, String>> getCategoryMap() async {
    final all = await getAll();
    final result = <String, String>{};
    for (final book in all) {
      final key = _bookKey(sourceId: book.sourceId, detailUrl: book.detailUrl);
      final category = book.category?.trim() ?? '';
      if (key.isEmpty || category.isEmpty) {
        continue;
      }
      result[key] = category;
    }
    return result;
  }

  Future<List<String>> getCategoryOrder() async {
    final prefs = await _preferencesFuture;
    final raw = prefs.getString(_categoryOrderStorageKey);
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

  Future<void> saveCategoryOrder(List<String> orderedCategories) async {
    final prefs = await _preferencesFuture;
    final normalized = _normalizeTags(orderedCategories);
    if (normalized.isEmpty) {
      await prefs.remove(_categoryOrderStorageKey);
      _emitTaxonomyChange(
        const BookshelfTaxonomyChange(
          kind: BookshelfTaxonomyKind.category,
          action: BookshelfTaxonomyAction.orderChanged,
        ),
      );
      return;
    }
    await prefs.setString(_categoryOrderStorageKey, jsonEncode(normalized));
    _emitTaxonomyChange(
      const BookshelfTaxonomyChange(
        kind: BookshelfTaxonomyKind.category,
        action: BookshelfTaxonomyAction.orderChanged,
      ),
    );
  }

  Future<void> setBookCategory({
    required String sourceId,
    required String detailUrl,
    String? category,
  }) async {
    final key = _bookKey(sourceId: sourceId, detailUrl: detailUrl);
    if (key.isEmpty) {
      return;
    }

    final all = (await getAll()).toList(growable: true);
    final index = all.indexWhere(
      (entry) => entry.sourceId == sourceId && entry.detailUrl == detailUrl,
    );
    if (index < 0) {
      return;
    }

    final normalized = _normalizeTags([category ?? '']);
    final nextCategory = normalized.isEmpty ? null : normalized.first;
    all[index] = all[index].copyWith(
      category: nextCategory,
      clearCategory: nextCategory == null,
    );
    await _save(all);
    _emitTaxonomyChange(
      const BookshelfTaxonomyChange(
        kind: BookshelfTaxonomyKind.category,
        action: BookshelfTaxonomyAction.assignmentChanged,
      ),
    );
  }

  Future<void> removeBookCategory({
    required String sourceId,
    required String detailUrl,
  }) async {
    await setBookCategory(sourceId: sourceId, detailUrl: detailUrl);
  }

  Future<int> renameCategory({
    required String fromCategory,
    required String toCategory,
  }) async {
    final fromValues = _normalizeTags([fromCategory]);
    final toValues = _normalizeTags([toCategory]);
    if (fromValues.isEmpty || toValues.isEmpty) {
      return 0;
    }

    final from = fromValues.first;
    final to = toValues.first;
    if (from == to) {
      return 0;
    }

    final all = (await getAll()).toList(growable: true);
    var affectedCount = 0;
    for (var index = 0; index < all.length; index += 1) {
      final current = all[index].category?.trim() ?? '';
      if (current != from) {
        continue;
      }
      affectedCount += 1;
      all[index] = all[index].copyWith(category: to);
    }

    final categoryOrder = List<String>.from(await getCategoryOrder());
    final orderContains = categoryOrder.contains(from);
    if (affectedCount <= 0 && !orderContains) {
      return 0;
    }

    await _save(all);
    await saveCategoryOrder(
      categoryOrder
          .map((category) => category == from ? to : category)
          .toList(growable: false),
    );
    _emitTaxonomyChange(
      BookshelfTaxonomyChange(
        kind: BookshelfTaxonomyKind.category,
        action: BookshelfTaxonomyAction.rename,
        previousName: from,
        currentName: to,
      ),
    );
    return affectedCount > 0 || orderContains ? 1 : 0;
  }

  Future<int> deleteCategory(String categoryName) async {
    final values = _normalizeTags([categoryName]);
    if (values.isEmpty) {
      return 0;
    }
    final target = values.first;

    final all = (await getAll()).toList(growable: true);
    var affectedCount = 0;
    for (var index = 0; index < all.length; index += 1) {
      final current = all[index].category?.trim() ?? '';
      if (current != target) {
        continue;
      }
      affectedCount += 1;
      all[index] = all[index].copyWith(clearCategory: true);
    }

    final categoryOrder = List<String>.from(await getCategoryOrder());
    final orderContains = categoryOrder.contains(target);
    if (affectedCount <= 0 && !orderContains) {
      return 0;
    }

    await _save(all);
    await saveCategoryOrder(
      categoryOrder
          .where((category) => category != target)
          .toList(growable: false),
    );
    _emitTaxonomyChange(
      BookshelfTaxonomyChange(
        kind: BookshelfTaxonomyKind.category,
        action: BookshelfTaxonomyAction.delete,
        previousName: target,
      ),
    );
    return affectedCount > 0 || orderContains ? 1 : 0;
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

  Future<Map<String, String>?> loadViewSelection() async {
    final prefs = await _preferencesFuture;
    final kind = prefs.getString(_viewSelectionKindKey)?.trim();
    final value = prefs.getString(_viewSelectionValueKey)?.trim();
    if (kind == null || kind.isEmpty) {
      return null;
    }
    return <String, String>{
      'kind': kind,
      if (value != null && value.isNotEmpty) 'value': value,
    };
  }

  Future<void> saveViewSelection({
    required String kind,
    String? value,
  }) async {
    final prefs = await _preferencesFuture;
    await prefs.setString(_viewSelectionKindKey, kind.trim());
    final normalizedValue = value?.trim() ?? '';
    if (normalizedValue.isEmpty) {
      await prefs.remove(_viewSelectionValueKey);
    } else {
      await prefs.setString(_viewSelectionValueKey, normalizedValue);
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
    _emitTaxonomyChange(
      const BookshelfTaxonomyChange(
        kind: BookshelfTaxonomyKind.tag,
        action: BookshelfTaxonomyAction.assignmentChanged,
      ),
    );
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

    final orderContains = tagOrder.contains(from);
    if (affectedCount <= 0 && !orderContains) {
      return 0;
    }

    await _saveTagMap(map);
    await saveTagOrder(tagOrder.map((tag) => tag == from ? to : tag).toList());
    _emitTaxonomyChange(
      BookshelfTaxonomyChange(
        kind: BookshelfTaxonomyKind.tag,
        action: BookshelfTaxonomyAction.rename,
        previousName: from,
        currentName: to,
      ),
    );
    return affectedCount > 0 || orderContains ? 1 : 0;
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

    final orderContains = tagOrder.contains(target);
    if (affectedCount <= 0 && !orderContains) {
      return 0;
    }

    await _saveTagMap(map);
    await saveTagOrder(
      tagOrder.where((tag) => tag != target).toList(growable: false),
    );
    _emitTaxonomyChange(
      BookshelfTaxonomyChange(
        kind: BookshelfTaxonomyKind.tag,
        action: BookshelfTaxonomyAction.delete,
        previousName: target,
      ),
    );
    return affectedCount > 0 || orderContains ? 1 : 0;
  }

  Future<void> _save(List<BookshelfBook> books) async {
    final prefs = await _preferencesFuture;
    final payload = books
        .map((item) => Map<String, Object?>.from(item.toJson()))
        .toList(growable: false);
    final encoded = await Isolate.run<String>(
      () => _encodeBookshelfBookJsonMaps(payload),
    );
    await prefs.setString(_storageKey, encoded);
  }

  Future<void> _saveTagMap(Map<String, List<String>> map) async {
    final prefs = await _preferencesFuture;
    final encoded = await Isolate.run<String>(
      () => _encodeBookshelfTagMap(map),
    );
    await prefs.setString(_tagStorageKey, encoded);
  }

  void _emitTaxonomyChange(BookshelfTaxonomyChange change) {
    if (_taxonomyChangeController.isClosed) {
      return;
    }
    _taxonomyChangeController.add(change);
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

List<Map<String, Object?>>? _decodeBookshelfBookJsonMaps(String raw) {
  final decoded = jsonDecode(raw);
  if (decoded is! List) {
    return null;
  }
  return decoded
      .whereType<Map>()
      .map(
        (item) => <String, Object?>{
          for (final entry in item.entries) entry.key.toString(): entry.value,
        },
      )
      .toList(growable: false);
}

Map<String, List<String>> _decodeBookshelfTagMap(String raw) {
  final decoded = jsonDecode(raw);
  if (decoded is! Map) {
    return const <String, List<String>>{};
  }

  final result = <String, List<String>>{};
  for (final entry in decoded.entries) {
    final key = entry.key.toString().trim();
    if (key.isEmpty || entry.value is! List) {
      continue;
    }
    final tags = BookshelfService._normalizeTags(
      (entry.value as List).map((value) => '$value'),
    );
    if (tags.isEmpty) {
      continue;
    }
    result[key] = tags;
  }
  return result;
}

String _encodeBookshelfBookJsonMaps(List<Map<String, Object?>> payload) {
  return jsonEncode(payload);
}

String _encodeBookshelfTagMap(Map<String, List<String>> map) {
  return jsonEncode(map);
}

import 'dart:isolate';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../data/datasources/local/app_database.dart';
import '../../../domain/entities/bookshelf_book.dart';
import 'bookshelf_event_bus.dart';
import 'bookshelf_events.dart';
import 'bookshelf_legacy_migration_service.dart';
import 'bookshelf_taxonomy_service.dart';

export 'bookshelf_events.dart';
export 'bookshelf_taxonomy_service.dart' show BookshelfTaxonomyItem;

class BookshelfService {
  BookshelfService({SharedPreferences? preferences, AppDatabase? database})
    : _preferencesFuture =
          preferences == null
              ? SharedPreferences.getInstance()
              : Future.value(preferences),
      _database = database ?? AppDatabase.instance;

  final Future<SharedPreferences> _preferencesFuture;
  final AppDatabase _database;

  static const String _storageKey = 'bookshelf.books';
  static const String _tagStorageKey = 'bookshelf.book_tags';
  static const String _tagOrderStorageKey = 'bookshelf.tag_order';
  static const String _tagMetadataStorageKey = 'bookshelf.tag_metadata.v1';
  static const String _categoryOrderStorageKey = 'bookshelf.category_order';
  static const String _categoryMetadataStorageKey =
      'bookshelf.category_metadata.v1';
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
  static const String _gridVisualStyleKey = 'bookshelf.grid.visualStyle';
  static const String _gridShowTitleKey = 'bookshelf.grid.showTitle';
  static const String _gridTitleCenterKey = 'bookshelf.grid.titleCenter';
  static const String _gridTitleMaxLinesKey = 'bookshelf.grid.titleMaxLines';
  static const String _gridCoverShadowKey = 'bookshelf.grid.coverShadow';
  static const String _gridShowAuthorKey = 'bookshelf.grid.showAuthor';
  static const String _gridShowLatestChapterKey =
      'bookshelf.grid.showLatestChapter';
  static const String _gridShowProgressBarKey =
      'bookshelf.grid.showProgressBar';
  static const String _gridProgressInfoModeKey =
      'bookshelf.grid.progressInfoMode';
  static const String _gridShowSourceBadgeKey =
      'bookshelf.grid.showSourceBadge';
  static const String _gridShowTaxonomyBadgesKey =
      'bookshelf.grid.showTaxonomyBadges';
  static const String _gridAlwaysShowSearchBarKey =
      'bookshelf.grid.search.alwaysVisible';
  static const String _gridPinSearchBarKey = 'bookshelf.grid.search.pinned';
  static const String _gridQuickFilterContentKey =
      'bookshelf.grid.search.quickFilterContent';
  static const String _listShowTitleKey = 'bookshelf.list.showTitle';
  static const String _listShowAuthorKey = 'bookshelf.list.showAuthor';
  static const String _listShowLatestChapterKey =
      'bookshelf.list.showLatestChapter';
  static const String _listShowProgressBarKey =
      'bookshelf.list.showProgressBar';
  static const String _listProgressInfoModeKey =
      'bookshelf.list.progressInfoMode';
  static const String _listShowSourceBadgeKey =
      'bookshelf.list.showSourceBadge';
  static const String _listShowTaxonomyBadgesKey =
      'bookshelf.list.showTaxonomyBadges';
  static const String _listShowCoverKey = 'bookshelf.list.showCover';
  static const String _listAlwaysShowSearchBarKey =
      'bookshelf.list.search.alwaysVisible';
  static const String _listPinSearchBarKey = 'bookshelf.list.search.pinned';
  static const String _listQuickFilterContentKey =
      'bookshelf.list.search.quickFilterContent';
  static const String _listCompactModeKey = 'bookshelf.list.compactMode';
  static const String _listTwoColumnModeKey = 'bookshelf.list.twoColumnMode';
  static const String _listShowRecentReadTimeKey =
      'bookshelf.list.showRecentReadTime';

  static const String gridStandardVisualStyle = 'standard';
  static const String gridOverlayTitleVisualStyle = 'overlayTitle';
  static const String gridCoverOnlyVisualStyle = 'coverOnly';
  static const String defaultSortMode = 'default';
  static const String recentReadSortMode = 'recentRead';
  static const String readingProgressSortMode = 'readingProgress';
  static const String createdAtSortMode = 'createdAt';
  static const String authorSortMode = 'author';
  static const String titleSortMode = 'title';
  static const String progressInfoModeProgressBar = 'progressBar';
  static const String progressInfoModeUnreadChapters = 'unreadChapters';
  static const bool defaultGridAdaptiveColumns = true;
  static const int defaultGridColumnCount = 3;
  static const double defaultGridCrossSpacing = 8;
  static const double defaultGridMainSpacing = 12;
  static const String defaultGridVisualStyle = gridStandardVisualStyle;
  static const bool defaultGridShowTitle = true;
  static const bool defaultGridTitleCenter = false;
  static const int defaultGridTitleMaxLines = 1;
  static const bool defaultGridCoverShadow = true;
  static const bool defaultGridShowAuthor = true;
  static const bool defaultGridShowLatestChapter = true;
  static const bool defaultGridShowProgressBar = true;
  static const String defaultGridProgressInfoMode = progressInfoModeProgressBar;
  static const bool defaultGridShowSourceBadge = false;
  static const bool defaultGridShowTaxonomyBadges = false;
  static const bool defaultGridAlwaysShowSearchBar = true;
  static const bool defaultGridPinSearchBar = false;
  static const String defaultGridQuickFilterContent = 'none';
  static const bool defaultListShowTitle = true;
  static const bool defaultListShowAuthor = true;
  static const bool defaultListShowLatestChapter = true;
  static const bool defaultListShowProgressBar = true;
  static const String defaultListProgressInfoMode = progressInfoModeProgressBar;
  static const bool defaultListShowSourceBadge = false;
  static const bool defaultListShowTaxonomyBadges = true;
  static const bool defaultListShowCover = true;
  static const bool defaultListAlwaysShowSearchBar = true;
  static const bool defaultListPinSearchBar = false;
  static const String defaultListQuickFilterContent = 'none';
  static const bool defaultListCompactMode = false;
  static const bool defaultListTwoColumnMode = false;
  static const bool defaultListShowRecentReadTime = false;
  static const BookshelfTaxonomyService _taxonomyService =
      BookshelfTaxonomyService();
  static final BookshelfEventBus _eventBus = BookshelfEventBus();

  static Stream<BookshelfTaxonomyChange> get watchTaxonomyChanges =>
      _eventBus.watchTaxonomyChanges;
  static Stream<BookshelfCollectionChange> get watchCollectionChanges =>
      _eventBus.watchCollectionChanges;

  Future<List<BookshelfBook>> getAll() async {
    final storedBooks = await _database.listBookshelfBooks();
    if (storedBooks.isNotEmpty) {
      return storedBooks
          .map(
            (item) => BookshelfBook(
              bookId: item.bookId,
              sourceId: item.sourceId,
              title: item.title,
              detailUrl: item.detailUrl,
              addedAt: item.addedAt,
              author: item.author,
              category: item.category,
              coverUrl: item.coverUrl,
              latestChapter: item.latestChapter,
              inReadingQueue: item.inReadingQueue,
            ),
          )
          .toList(growable: false);
    }

    await migrateLegacySnapshotToDatabase();
    final migratedBooks = await _database.listBookshelfBooks();
    if (migratedBooks.isNotEmpty) {
      return migratedBooks
          .map(
            (item) => BookshelfBook(
              bookId: item.bookId,
              sourceId: item.sourceId,
              title: item.title,
              detailUrl: item.detailUrl,
              addedAt: item.addedAt,
              author: item.author,
              category: item.category,
              coverUrl: item.coverUrl,
              latestChapter: item.latestChapter,
              inReadingQueue: item.inReadingQueue,
            ),
          )
          .toList(growable: false);
    }

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
    bool previousInReadingQueue = false;
    final index = all.indexWhere(
      (entry) =>
          entry.sourceId == item.sourceId && entry.detailUrl == item.detailUrl,
    );

    if (index >= 0) {
      previousInReadingQueue = all[index].inReadingQueue;
      all.removeAt(index);
    }
    final value = item.copyWith(
      addedAt: DateTime.now(),
      inReadingQueue: item.inReadingQueue || previousInReadingQueue,
    );
    all.insert(0, value);

    await _save(all);
    _emitCollectionChange(
      BookshelfCollectionChange(
        action: BookshelfCollectionAction.upsert,
        sourceId: value.sourceId,
        detailUrl: value.detailUrl,
        bookId: value.bookId,
      ),
    );
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
    bool previousInReadingQueue = false;
    for (final entry in all) {
      final entryKey = _bookKey(
        sourceId: entry.sourceId,
        detailUrl: entry.detailUrl,
      );
      if (entryKey == previousKey) {
        previousCategory = entry.category?.trim();
        previousInReadingQueue = entry.inReadingQueue;
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
        inReadingQueue: nextBook.inReadingQueue || previousInReadingQueue,
      ),
    );
    await _save(all);
    _emitCollectionChange(
      BookshelfCollectionChange(
        action: BookshelfCollectionAction.replace,
        sourceId: nextBook.sourceId,
        detailUrl: nextBook.detailUrl,
        bookId: nextBook.bookId,
      ),
    );

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
    _emitCollectionChange(
      BookshelfCollectionChange(
        action: BookshelfCollectionAction.remove,
        sourceId: sourceId,
        detailUrl: detailUrl,
      ),
    );
    await removeBookTags(sourceId: sourceId, detailUrl: detailUrl);
    await removeBookCategory(sourceId: sourceId, detailUrl: detailUrl);
  }

  Future<bool> isInReadingQueue({
    required String sourceId,
    required String detailUrl,
  }) async {
    final normalizedSourceId = sourceId.trim();
    final normalizedDetailUrl = detailUrl.trim();
    if (normalizedSourceId.isEmpty || normalizedDetailUrl.isEmpty) {
      return false;
    }
    final all = await getAll();
    for (final book in all) {
      if (book.sourceId == normalizedSourceId &&
          book.detailUrl == normalizedDetailUrl) {
        return book.inReadingQueue;
      }
    }
    return false;
  }

  Future<void> setInReadingQueue({
    required String sourceId,
    required String detailUrl,
    required bool inReadingQueue,
  }) async {
    final normalizedSourceId = sourceId.trim();
    final normalizedDetailUrl = detailUrl.trim();
    if (normalizedSourceId.isEmpty || normalizedDetailUrl.isEmpty) {
      return;
    }

    final all = (await getAll()).toList(growable: true);
    final index = all.indexWhere(
      (book) =>
          book.sourceId == normalizedSourceId &&
          book.detailUrl == normalizedDetailUrl,
    );
    if (index < 0 || all[index].inReadingQueue == inReadingQueue) {
      return;
    }

    final updated = all[index].copyWith(inReadingQueue: inReadingQueue);
    all[index] = updated;
    await _save(all);
    _emitCollectionChange(
      BookshelfCollectionChange(
        action: BookshelfCollectionAction.upsert,
        sourceId: normalizedSourceId,
        detailUrl: normalizedDetailUrl,
        bookId: updated.bookId,
      ),
    );
  }

  Future<void> replaceAllForSync(List<BookshelfBook> books) async {
    await _save(books);
  }

  Future<void> replaceTagMapForSync(Map<String, List<String>> tagMap) async {
    final normalized = <String, List<String>>{};
    for (final entry in tagMap.entries) {
      final key = entry.key.trim();
      if (key.isEmpty) {
        continue;
      }
      final tags = _normalizeTags(entry.value);
      if (tags.isEmpty) {
        continue;
      }
      normalized[key] = tags;
    }
    await _saveTagMap(normalized);
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

  Future<String> loadGridVisualStyle() async {
    final prefs = await _preferencesFuture;
    return _normalizeGridVisualStyle(prefs.getString(_gridVisualStyleKey));
  }

  Future<void> saveGridVisualStyle(String value) async {
    final prefs = await _preferencesFuture;
    await prefs.setString(
      _gridVisualStyleKey,
      _normalizeGridVisualStyle(value),
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

  Future<bool> loadGridTitleCenter() async {
    final prefs = await _preferencesFuture;
    return prefs.getBool(_gridTitleCenterKey) ?? defaultGridTitleCenter;
  }

  Future<void> saveGridTitleCenter(bool centered) async {
    final prefs = await _preferencesFuture;
    await prefs.setBool(_gridTitleCenterKey, centered);
  }

  Future<int> loadGridTitleMaxLines() async {
    final prefs = await _preferencesFuture;
    return _normalizeGridTitleMaxLines(prefs.getInt(_gridTitleMaxLinesKey));
  }

  Future<void> saveGridTitleMaxLines(int lines) async {
    final prefs = await _preferencesFuture;
    await prefs.setInt(
      _gridTitleMaxLinesKey,
      _normalizeGridTitleMaxLines(lines),
    );
  }

  Future<bool> loadGridCoverShadow() async {
    final prefs = await _preferencesFuture;
    return prefs.getBool(_gridCoverShadowKey) ?? defaultGridCoverShadow;
  }

  Future<void> saveGridCoverShadow(bool visible) async {
    final prefs = await _preferencesFuture;
    await prefs.setBool(_gridCoverShadowKey, visible);
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

  Future<String> loadGridProgressInfoMode() async {
    final prefs = await _preferencesFuture;
    return _normalizeProgressInfoMode(
      prefs.getString(_gridProgressInfoModeKey),
      fallback: defaultGridProgressInfoMode,
    );
  }

  Future<void> saveGridProgressInfoMode(String mode) async {
    final prefs = await _preferencesFuture;
    await prefs.setString(
      _gridProgressInfoModeKey,
      _normalizeProgressInfoMode(mode, fallback: defaultGridProgressInfoMode),
    );
  }

  Future<bool> loadGridShowSourceBadge() async {
    final prefs = await _preferencesFuture;
    return prefs.getBool(_gridShowSourceBadgeKey) ?? defaultGridShowSourceBadge;
  }

  Future<void> saveGridShowSourceBadge(bool visible) async {
    final prefs = await _preferencesFuture;
    await prefs.setBool(_gridShowSourceBadgeKey, visible);
  }

  Future<bool> loadGridShowTaxonomyBadges() async {
    final prefs = await _preferencesFuture;
    return prefs.getBool(_gridShowTaxonomyBadgesKey) ??
        defaultGridShowTaxonomyBadges;
  }

  Future<void> saveGridShowTaxonomyBadges(bool visible) async {
    final prefs = await _preferencesFuture;
    await prefs.setBool(_gridShowTaxonomyBadgesKey, visible);
  }

  Future<bool> loadGridAlwaysShowSearchBar() async {
    final prefs = await _preferencesFuture;
    return prefs.getBool(_gridAlwaysShowSearchBarKey) ??
        defaultGridAlwaysShowSearchBar;
  }

  Future<void> saveGridAlwaysShowSearchBar(bool visible) async {
    final prefs = await _preferencesFuture;
    await prefs.setBool(_gridAlwaysShowSearchBarKey, visible);
  }

  Future<bool> loadGridPinSearchBar() async {
    final prefs = await _preferencesFuture;
    return prefs.getBool(_gridPinSearchBarKey) ?? defaultGridPinSearchBar;
  }

  Future<void> saveGridPinSearchBar(bool pinned) async {
    final prefs = await _preferencesFuture;
    await prefs.setBool(_gridPinSearchBarKey, pinned);
  }

  Future<String> loadGridQuickFilterContent() async {
    final prefs = await _preferencesFuture;
    return _normalizeSearchQuickFilterContent(
      prefs.getString(_gridQuickFilterContentKey),
      fallback: defaultGridQuickFilterContent,
    );
  }

  Future<void> saveGridQuickFilterContent(String value) async {
    final prefs = await _preferencesFuture;
    await prefs.setString(
      _gridQuickFilterContentKey,
      _normalizeSearchQuickFilterContent(
        value,
        fallback: defaultGridQuickFilterContent,
      ),
    );
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

  Future<String> loadListProgressInfoMode() async {
    final prefs = await _preferencesFuture;
    return _normalizeProgressInfoMode(
      prefs.getString(_listProgressInfoModeKey),
      fallback: defaultListProgressInfoMode,
    );
  }

  Future<void> saveListProgressInfoMode(String mode) async {
    final prefs = await _preferencesFuture;
    await prefs.setString(
      _listProgressInfoModeKey,
      _normalizeProgressInfoMode(mode, fallback: defaultListProgressInfoMode),
    );
  }

  Future<bool> loadListShowSourceBadge() async {
    final prefs = await _preferencesFuture;
    return prefs.getBool(_listShowSourceBadgeKey) ?? defaultListShowSourceBadge;
  }

  Future<void> saveListShowSourceBadge(bool visible) async {
    final prefs = await _preferencesFuture;
    await prefs.setBool(_listShowSourceBadgeKey, visible);
  }

  Future<bool> loadListShowTaxonomyBadges() async {
    final prefs = await _preferencesFuture;
    return prefs.getBool(_listShowTaxonomyBadgesKey) ??
        defaultListShowTaxonomyBadges;
  }

  Future<void> saveListShowTaxonomyBadges(bool visible) async {
    final prefs = await _preferencesFuture;
    await prefs.setBool(_listShowTaxonomyBadgesKey, visible);
  }

  Future<bool> loadListShowCover() async {
    final prefs = await _preferencesFuture;
    return prefs.getBool(_listShowCoverKey) ?? defaultListShowCover;
  }

  Future<void> saveListShowCover(bool visible) async {
    final prefs = await _preferencesFuture;
    await prefs.setBool(_listShowCoverKey, visible);
  }

  Future<bool> loadListAlwaysShowSearchBar() async {
    final prefs = await _preferencesFuture;
    return prefs.getBool(_listAlwaysShowSearchBarKey) ??
        defaultListAlwaysShowSearchBar;
  }

  Future<void> saveListAlwaysShowSearchBar(bool visible) async {
    final prefs = await _preferencesFuture;
    await prefs.setBool(_listAlwaysShowSearchBarKey, visible);
  }

  Future<bool> loadListPinSearchBar() async {
    final prefs = await _preferencesFuture;
    return prefs.getBool(_listPinSearchBarKey) ?? defaultListPinSearchBar;
  }

  Future<void> saveListPinSearchBar(bool pinned) async {
    final prefs = await _preferencesFuture;
    await prefs.setBool(_listPinSearchBarKey, pinned);
  }

  Future<String> loadListQuickFilterContent() async {
    final prefs = await _preferencesFuture;
    return _normalizeSearchQuickFilterContent(
      prefs.getString(_listQuickFilterContentKey),
      fallback: defaultListQuickFilterContent,
    );
  }

  Future<void> saveListQuickFilterContent(String value) async {
    final prefs = await _preferencesFuture;
    await prefs.setString(
      _listQuickFilterContentKey,
      _normalizeSearchQuickFilterContent(
        value,
        fallback: defaultListQuickFilterContent,
      ),
    );
  }

  Future<bool> loadListCompactMode() async {
    final prefs = await _preferencesFuture;
    return prefs.getBool(_listCompactModeKey) ?? defaultListCompactMode;
  }

  Future<void> saveListCompactMode(bool compact) async {
    final prefs = await _preferencesFuture;
    await prefs.setBool(_listCompactModeKey, compact);
  }

  Future<bool> loadListTwoColumnMode() async {
    final prefs = await _preferencesFuture;
    return prefs.getBool(_listTwoColumnModeKey) ?? defaultListTwoColumnMode;
  }

  Future<void> saveListTwoColumnMode(bool enabled) async {
    final prefs = await _preferencesFuture;
    await prefs.setBool(_listTwoColumnModeKey, enabled);
  }

  Future<bool> loadListShowRecentReadTime() async {
    final prefs = await _preferencesFuture;
    return prefs.getBool(_listShowRecentReadTimeKey) ??
        defaultListShowRecentReadTime;
  }

  Future<void> saveListShowRecentReadTime(bool visible) async {
    final prefs = await _preferencesFuture;
    await prefs.setBool(_listShowRecentReadTimeKey, visible);
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
    final storedAssignments = await _database.listBookshelfTagAssignments();
    if (storedAssignments.isNotEmpty) {
      final result = <String, List<String>>{};
      for (final item in storedAssignments) {
        final key = _bookKey(
          sourceId: item.sourceId,
          detailUrl: item.detailUrl,
        );
        final tags = result.putIfAbsent(key, () => <String>[]);
        tags.add(item.tagName);
      }
      return result;
    }

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
    final stored = await _database.listBookshelfTagMetadata();
    if (stored.isNotEmpty) {
      return stored.map((item) => item.name).toList(growable: false);
    }

    final prefs = await _preferencesFuture;
    final raw = prefs.getString(_tagOrderStorageKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <String>[];
    }

    try {
      return _taxonomyService.decodeStringList(raw);
    } catch (_) {
      return const <String>[];
    }
  }

  Future<List<BookshelfTaxonomyItem>> getTagItems() async {
    final stored = await _database.listBookshelfTagMetadata();
    if (stored.isNotEmpty) {
      return stored
          .map(
            (item) => BookshelfTaxonomyItem(
              name: item.name,
              colorValue: item.colorValue,
            ),
          )
          .toList(growable: false);
    }

    return _loadTaxonomyItems(
      metadataKey: _tagMetadataStorageKey,
      orderKey: _tagOrderStorageKey,
    );
  }

  Future<void> saveTagItems(List<BookshelfTaxonomyItem> items) async {
    await _saveTagItemsToDatabase(items);
    await _clearLegacyTaxonomyPrefs(
      metadataKey: _tagMetadataStorageKey,
      orderKey: _tagOrderStorageKey,
    );
    _emitTaxonomyChange(
      const BookshelfTaxonomyChange(
        kind: BookshelfTaxonomyKind.tag,
        action: BookshelfTaxonomyAction.metadataChanged,
      ),
    );
  }

  Future<void> saveTagOrder(List<String> orderedTags) async {
    final current = await getTagItems();
    final currentByName = <String, BookshelfTaxonomyItem>{
      for (final item in current) item.name: item,
    };
    final normalizedOrder = _normalizeTags(orderedTags);
    final remaining = current
        .where((item) => !normalizedOrder.contains(item.name))
        .map((item) => item.name)
        .toList(growable: false);
    final orderedNames = <String>[...normalizedOrder, ...remaining];
    final next = orderedNames
        .map(
          (name) =>
              currentByName[name] ??
              BookshelfTaxonomyItem(
                name: name,
                colorValue: BookshelfTaxonomyItem.defaultColorForName(name),
              ),
        )
        .toList(growable: false);
    await _saveTagItemsToDatabase(next);
    await _clearLegacyTaxonomyPrefs(
      metadataKey: _tagMetadataStorageKey,
      orderKey: _tagOrderStorageKey,
    );
    _emitTaxonomyChange(
      const BookshelfTaxonomyChange(
        kind: BookshelfTaxonomyKind.tag,
        action: BookshelfTaxonomyAction.orderChanged,
      ),
    );
  }

  Future<void> upsertTagItem({
    required String name,
    required int colorValue,
  }) async {
    await _upsertTaxonomyItem(
      kind: BookshelfTaxonomyKind.tag,
      metadataKey: _tagMetadataStorageKey,
      orderKey: _tagOrderStorageKey,
      name: name,
      colorValue: colorValue,
    );
  }

  Future<List<String>> getBaseFilterOrder() async {
    final stored = await _database.listBookshelfBaseFilterOrders();
    if (stored.isNotEmpty) {
      return stored.map((item) => item.filterKey).toList(growable: false);
    }

    final prefs = await _preferencesFuture;
    final raw = prefs.getString(_baseFilterOrderStorageKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <String>[];
    }

    try {
      return _taxonomyService.decodeStringList(raw);
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
    final stored = await _database.listBookshelfCategoryMetadata();
    if (stored.isNotEmpty) {
      return stored.map((item) => item.name).toList(growable: false);
    }

    final prefs = await _preferencesFuture;
    final raw = prefs.getString(_categoryOrderStorageKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <String>[];
    }

    try {
      return _taxonomyService.decodeStringList(raw);
    } catch (_) {
      return const <String>[];
    }
  }

  Future<List<BookshelfTaxonomyItem>> getCategoryItems() async {
    final stored = await _database.listBookshelfCategoryMetadata();
    if (stored.isNotEmpty) {
      return stored
          .map(
            (item) => BookshelfTaxonomyItem(
              name: item.name,
              colorValue: item.colorValue,
            ),
          )
          .toList(growable: false);
    }

    return _loadTaxonomyItems(
      metadataKey: _categoryMetadataStorageKey,
      orderKey: _categoryOrderStorageKey,
    );
  }

  Future<void> saveCategoryItems(List<BookshelfTaxonomyItem> items) async {
    await _saveCategoryItemsToDatabase(items);
    await _clearLegacyTaxonomyPrefs(
      metadataKey: _categoryMetadataStorageKey,
      orderKey: _categoryOrderStorageKey,
    );
    _emitTaxonomyChange(
      const BookshelfTaxonomyChange(
        kind: BookshelfTaxonomyKind.category,
        action: BookshelfTaxonomyAction.metadataChanged,
      ),
    );
  }

  Future<void> saveCategoryOrder(List<String> orderedCategories) async {
    final current = await getCategoryItems();
    final currentByName = <String, BookshelfTaxonomyItem>{
      for (final item in current) item.name: item,
    };
    final normalizedOrder = _normalizeTags(orderedCategories);
    final remaining = current
        .where((item) => !normalizedOrder.contains(item.name))
        .map((item) => item.name)
        .toList(growable: false);
    final orderedNames = <String>[...normalizedOrder, ...remaining];
    final next = orderedNames
        .map(
          (name) =>
              currentByName[name] ??
              BookshelfTaxonomyItem(
                name: name,
                colorValue: BookshelfTaxonomyItem.defaultColorForName(name),
              ),
        )
        .toList(growable: false);
    await _saveCategoryItemsToDatabase(next);
    await _clearLegacyTaxonomyPrefs(
      metadataKey: _categoryMetadataStorageKey,
      orderKey: _categoryOrderStorageKey,
    );
    _emitTaxonomyChange(
      const BookshelfTaxonomyChange(
        kind: BookshelfTaxonomyKind.category,
        action: BookshelfTaxonomyAction.orderChanged,
      ),
    );
  }

  Future<void> upsertCategoryItem({
    required String name,
    required int colorValue,
  }) async {
    await _upsertTaxonomyItem(
      kind: BookshelfTaxonomyKind.category,
      metadataKey: _categoryMetadataStorageKey,
      orderKey: _categoryOrderStorageKey,
      name: name,
      colorValue: colorValue,
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

    final metadata = List<BookshelfTaxonomyItem>.from(await getCategoryItems());
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
    await saveCategoryItems(
      metadata
          .map((item) => item.name == from ? item.copyWith(name: to) : item)
          .toList(growable: false),
    );
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
    return affectedCount > 0 ? affectedCount : (orderContains ? 1 : 0);
  }

  Future<int> deleteCategory(String categoryName) async {
    final values = _normalizeTags([categoryName]);
    if (values.isEmpty) {
      return 0;
    }
    final target = values.first;

    final all = (await getAll()).toList(growable: true);
    final metadata = List<BookshelfTaxonomyItem>.from(await getCategoryItems());
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
    await saveCategoryItems(
      metadata.where((item) => item.name != target).toList(growable: false),
    );
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
    return affectedCount > 0 ? affectedCount : (orderContains ? 1 : 0);
  }

  Future<void> saveBaseFilterOrder(List<String> orderedFilters) async {
    final normalized = _normalizeTags(orderedFilters);
    await _saveBaseFilterOrderToDatabase(normalized);
    final prefs = await _preferencesFuture;
    await prefs.remove(_baseFilterOrderStorageKey);
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

  Future<void> saveViewSelection({required String kind, String? value}) async {
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
    final metadata = List<BookshelfTaxonomyItem>.from(await getTagItems());
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
    await saveTagItems(
      metadata
          .map((item) => item.name == from ? item.copyWith(name: to) : item)
          .toList(growable: false),
    );
    await saveTagOrder(tagOrder.map((tag) => tag == from ? to : tag).toList());
    _emitTaxonomyChange(
      BookshelfTaxonomyChange(
        kind: BookshelfTaxonomyKind.tag,
        action: BookshelfTaxonomyAction.rename,
        previousName: from,
        currentName: to,
      ),
    );
    return affectedCount > 0 ? affectedCount : (orderContains ? 1 : 0);
  }

  Future<int> deleteTag(String tagName) async {
    final values = _normalizeTags([tagName]);
    if (values.isEmpty) {
      return 0;
    }
    final target = values.first;

    final map = Map<String, List<String>>.from(await getTagMap());
    final tagOrder = List<String>.from(await getTagOrder());
    final metadata = List<BookshelfTaxonomyItem>.from(await getTagItems());
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
    await saveTagItems(
      metadata.where((item) => item.name != target).toList(growable: false),
    );
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
    return affectedCount > 0 ? affectedCount : (orderContains ? 1 : 0);
  }

  Future<void> _save(List<BookshelfBook> books) async {
    final normalized = books
        .map(
          (item) => item.copyWith(
            bookId: item.bookId.trim(),
            sourceId: item.sourceId.trim(),
            title: item.title.trim(),
            detailUrl: item.detailUrl.trim(),
            author: item.author?.trim(),
            category: item.category?.trim(),
            coverUrl: item.coverUrl?.trim(),
            latestChapter: item.latestChapter?.trim(),
          ),
        )
        .where(
          (item) =>
              item.bookId.isNotEmpty &&
              item.sourceId.isNotEmpty &&
              item.title.isNotEmpty &&
              item.detailUrl.isNotEmpty,
        )
        .toList(growable: false);
    final tagMap = await getTagMap();
    final tagItems = await getTagItems();
    final categoryItems = await getCategoryItems();
    final baseFilterOrder = await getBaseFilterOrder();
    await _database.replaceBookshelfSnapshot(
      books: normalized,
      tagMap: tagMap,
      tagItems: tagItems
          .map(
            (item) => BookshelfTaxonomySnapshotItem(
              name: item.name,
              colorValue: item.colorValue,
            ),
          )
          .toList(growable: false),
      categoryItems: categoryItems
          .map(
            (item) => BookshelfTaxonomySnapshotItem(
              name: item.name,
              colorValue: item.colorValue,
            ),
          )
          .toList(growable: false),
      baseFilterOrder: baseFilterOrder,
    );
    final prefs = await _preferencesFuture;
    await prefs.remove(_storageKey);
  }

  Future<void> _saveTagMap(Map<String, List<String>> map) async {
    final books = await getAll();
    final tagItems = await getTagItems();
    final categoryItems = await getCategoryItems();
    final baseFilterOrder = await getBaseFilterOrder();
    await _database.replaceBookshelfSnapshot(
      books: books,
      tagMap: map,
      tagItems: tagItems
          .map(
            (item) => BookshelfTaxonomySnapshotItem(
              name: item.name,
              colorValue: item.colorValue,
            ),
          )
          .toList(growable: false),
      categoryItems: categoryItems
          .map(
            (item) => BookshelfTaxonomySnapshotItem(
              name: item.name,
              colorValue: item.colorValue,
            ),
          )
          .toList(growable: false),
      baseFilterOrder: baseFilterOrder,
    );
    final prefs = await _preferencesFuture;
    await prefs.remove(_tagStorageKey);
  }

  Future<List<BookshelfTaxonomyItem>> _loadTaxonomyItems({
    required String metadataKey,
    required String orderKey,
  }) async {
    final prefs = await _preferencesFuture;
    return _taxonomyService.loadItems(
      metadataRaw: prefs.getString(metadataKey),
      orderRaw: prefs.getString(orderKey),
    );
  }

  Future<void> _saveTaxonomyItems({
    required String metadataKey,
    required String orderKey,
    required List<BookshelfTaxonomyItem> items,
    required BookshelfTaxonomyKind kind,
  }) async {
    final normalized = <BookshelfTaxonomyItem>[];
    final seen = <String>{};
    for (final item in items) {
      final name = item.name.trim();
      if (name.isEmpty || seen.contains(name)) {
        continue;
      }
      seen.add(name);
      normalized.add(item.copyWith(name: name));
    }

    if (kind == BookshelfTaxonomyKind.tag) {
      await _saveTagItemsToDatabase(normalized);
    } else {
      await _saveCategoryItemsToDatabase(normalized);
    }
    await _clearLegacyTaxonomyPrefs(
      metadataKey: metadataKey,
      orderKey: orderKey,
    );

    _emitTaxonomyChange(
      BookshelfTaxonomyChange(
        kind: kind,
        action: BookshelfTaxonomyAction.metadataChanged,
      ),
    );
  }

  Future<void> _upsertTaxonomyItem({
    required BookshelfTaxonomyKind kind,
    required String metadataKey,
    required String orderKey,
    required String name,
    required int colorValue,
  }) async {
    final normalized = _normalizeTags([name]);
    if (normalized.isEmpty) {
      return;
    }
    final itemName = normalized.first;
    final current = await _loadTaxonomyItems(
      metadataKey: metadataKey,
      orderKey: orderKey,
    );
    var found = false;
    final next = current
        .map((item) {
          if (item.name != itemName) {
            return item;
          }
          found = true;
          return item.copyWith(colorValue: colorValue);
        })
        .toList(growable: true);
    if (!found) {
      next.add(BookshelfTaxonomyItem(name: itemName, colorValue: colorValue));
    }
    await _saveTaxonomyItems(
      metadataKey: metadataKey,
      orderKey: orderKey,
      items: next,
      kind: kind,
    );
    _emitTaxonomyChange(
      BookshelfTaxonomyChange(
        kind: kind,
        action:
            found
                ? BookshelfTaxonomyAction.metadataChanged
                : BookshelfTaxonomyAction.create,
        currentName: itemName,
      ),
    );
  }

  Future<void> _saveTagItemsToDatabase(
    List<BookshelfTaxonomyItem> items,
  ) async {
    final books = await getAll();
    final tagMap = await getTagMap();
    final categoryItems = await getCategoryItems();
    final baseFilterOrder = await getBaseFilterOrder();
    await _database.replaceBookshelfSnapshot(
      books: books,
      tagMap: tagMap,
      tagItems: items
          .map(
            (item) => BookshelfTaxonomySnapshotItem(
              name: item.name,
              colorValue: item.colorValue,
            ),
          )
          .toList(growable: false),
      categoryItems: categoryItems
          .map(
            (item) => BookshelfTaxonomySnapshotItem(
              name: item.name,
              colorValue: item.colorValue,
            ),
          )
          .toList(growable: false),
      baseFilterOrder: baseFilterOrder,
    );
  }

  Future<void> _saveCategoryItemsToDatabase(
    List<BookshelfTaxonomyItem> items,
  ) async {
    final books = await getAll();
    final tagMap = await getTagMap();
    final tagItems = await getTagItems();
    final baseFilterOrder = await getBaseFilterOrder();
    await _database.replaceBookshelfSnapshot(
      books: books,
      tagMap: tagMap,
      tagItems: tagItems
          .map(
            (item) => BookshelfTaxonomySnapshotItem(
              name: item.name,
              colorValue: item.colorValue,
            ),
          )
          .toList(growable: false),
      categoryItems: items
          .map(
            (item) => BookshelfTaxonomySnapshotItem(
              name: item.name,
              colorValue: item.colorValue,
            ),
          )
          .toList(growable: false),
      baseFilterOrder: baseFilterOrder,
    );
  }

  Future<void> _saveBaseFilterOrderToDatabase(List<String> filters) async {
    final books = await getAll();
    final tagMap = await getTagMap();
    final tagItems = await getTagItems();
    final categoryItems = await getCategoryItems();
    await _database.replaceBookshelfSnapshot(
      books: books,
      tagMap: tagMap,
      tagItems: tagItems
          .map(
            (item) => BookshelfTaxonomySnapshotItem(
              name: item.name,
              colorValue: item.colorValue,
            ),
          )
          .toList(growable: false),
      categoryItems: categoryItems
          .map(
            (item) => BookshelfTaxonomySnapshotItem(
              name: item.name,
              colorValue: item.colorValue,
            ),
          )
          .toList(growable: false),
      baseFilterOrder: filters,
    );
  }

  Future<void> _clearLegacyTaxonomyPrefs({
    required String metadataKey,
    required String orderKey,
  }) async {
    final prefs = await _preferencesFuture;
    await prefs.remove(metadataKey);
    await prefs.remove(orderKey);
  }

  void _emitTaxonomyChange(BookshelfTaxonomyChange change) {
    _eventBus.emitTaxonomyChange(change);
  }

  void _emitCollectionChange(BookshelfCollectionChange change) {
    _eventBus.emitCollectionChange(change);
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
    return BookshelfTaxonomyService.normalizeNames(values);
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

  static String _normalizeGridVisualStyle(String? value) {
    return switch (value?.trim()) {
      gridOverlayTitleVisualStyle => gridOverlayTitleVisualStyle,
      gridCoverOnlyVisualStyle => gridCoverOnlyVisualStyle,
      gridStandardVisualStyle => gridStandardVisualStyle,
      _ => defaultGridVisualStyle,
    };
  }

  static String _normalizeProgressInfoMode(
    String? value, {
    required String fallback,
  }) {
    return switch (value?.trim()) {
      progressInfoModeUnreadChapters => progressInfoModeUnreadChapters,
      progressInfoModeProgressBar => progressInfoModeProgressBar,
      _ => fallback,
    };
  }

  static int _normalizeGridColumnCount(int? value) {
    return (value ?? defaultGridColumnCount).clamp(2, 6);
  }

  static int _normalizeGridTitleMaxLines(int? value) {
    return (value ?? defaultGridTitleMaxLines).clamp(1, 3);
  }

  static String _normalizeSearchQuickFilterContent(
    String? value, {
    required String fallback,
  }) {
    return switch (value?.trim()) {
      'readingStatus' => 'readingStatus',
      'tags' => 'tags',
      'categories' => 'categories',
      'none' => 'none',
      _ => fallback,
    };
  }

  static double _normalizeGridSpacing(
    double? value, {
    required double fallback,
  }) {
    return (value ?? fallback).clamp(4.0, 24.0).toDouble();
  }

  Future<void> migrateLegacySnapshotToDatabase() async {
    final prefs = await _preferencesFuture;
    await BookshelfLegacyMigrationService(
      preferences: prefs,
      database: _database,
      keys: const BookshelfLegacyMigrationKeys(
        books: _storageKey,
        tagMap: _tagStorageKey,
        tagOrder: _tagOrderStorageKey,
        tagMetadata: _tagMetadataStorageKey,
        categoryOrder: _categoryOrderStorageKey,
        categoryMetadata: _categoryMetadataStorageKey,
        baseFilterOrder: _baseFilterOrderStorageKey,
      ),
    ).migrateIfNeeded();
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
  return BookshelfTaxonomyService.decodeTagMapPayload(raw);
}

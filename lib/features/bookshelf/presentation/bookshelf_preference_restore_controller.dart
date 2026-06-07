import '../application/bookshelf_page_state.dart';
import '../application/bookshelf_service.dart';
import 'bookshelf_page_models.dart';
import 'bookshelf_preference_mappers.dart';

class BookshelfPreferenceRestoreController {
  const BookshelfPreferenceRestoreController(this._bookshelfService);

  final BookshelfService _bookshelfService;

  Future<bool> loadUseGridView() {
    return _bookshelfService.loadUseGridView();
  }

  Future<BookshelfListPreferenceSnapshot> loadListPreferences() async {
    return BookshelfListPreferenceSnapshot(
      showTitle: await _bookshelfService.loadListShowTitle(),
      showAuthor: await _bookshelfService.loadListShowAuthor(),
      showLatestChapter: await _bookshelfService.loadListShowLatestChapter(),
      showProgressBar: await _bookshelfService.loadListShowProgressBar(),
      progressInfoMode: progressInfoModeFromStorageValue(
        await _bookshelfService.loadListProgressInfoMode(),
      ),
      showSourceBadge: await _bookshelfService.loadListShowSourceBadge(),
      showTaxonomyBadges: await _bookshelfService.loadListShowTaxonomyBadges(),
      showCover: await _bookshelfService.loadListShowCover(),
      compactMode: await _bookshelfService.loadListCompactMode(),
      twoColumnMode: await _bookshelfService.loadListTwoColumnMode(),
      showRecentReadTime: await _bookshelfService.loadListShowRecentReadTime(),
      alwaysShowSearchBar:
          await _bookshelfService.loadListAlwaysShowSearchBar(),
      pinSearchBar: await _bookshelfService.loadListPinSearchBar(),
      quickFilterContent: searchQuickFilterContentFromStorageValue(
        await _bookshelfService.loadListQuickFilterContent(),
      ),
    );
  }

  Future<BookshelfSortMode> loadSortMode() async {
    return sortModeFromStorageValue(await _bookshelfService.loadSortMode());
  }

  Future<BookshelfGridPreferenceSnapshot> loadGridPreferences() async {
    return BookshelfGridPreferenceSnapshot(
      adaptiveColumns: await _bookshelfService.loadGridAdaptiveColumns(),
      columnCount: await _bookshelfService.loadGridColumnCount(),
      crossSpacing: await _bookshelfService.loadGridCrossSpacing(),
      mainSpacing: await _bookshelfService.loadGridMainSpacing(),
      visualStyle: gridVisualStyleFromStorageValue(
        await _bookshelfService.loadGridVisualStyle(),
      ),
      showTitle: await _bookshelfService.loadGridShowTitle(),
      titleCenter: await _bookshelfService.loadGridTitleCenter(),
      titleMaxLines: await _bookshelfService.loadGridTitleMaxLines(),
      coverShadow: await _bookshelfService.loadGridCoverShadow(),
      showAuthor: await _bookshelfService.loadGridShowAuthor(),
      showLatestChapter: await _bookshelfService.loadGridShowLatestChapter(),
      showProgressBar: await _bookshelfService.loadGridShowProgressBar(),
      progressInfoMode: progressInfoModeFromStorageValue(
        await _bookshelfService.loadGridProgressInfoMode(),
      ),
      showSourceBadge: await _bookshelfService.loadGridShowSourceBadge(),
      showTaxonomyBadges: await _bookshelfService.loadGridShowTaxonomyBadges(),
      alwaysShowSearchBar:
          await _bookshelfService.loadGridAlwaysShowSearchBar(),
      pinSearchBar: await _bookshelfService.loadGridPinSearchBar(),
      quickFilterContent: searchQuickFilterContentFromStorageValue(
        await _bookshelfService.loadGridQuickFilterContent(),
      ),
    );
  }

  Future<BookshelfViewSelection?> loadViewSelection() async {
    final stored = await _bookshelfService.loadViewSelection();
    if (stored == null) {
      return null;
    }

    final kind = (stored['kind'] ?? '').trim();
    final value = (stored['value'] ?? '').trim();
    return switch (kind) {
      'tag' when value.isNotEmpty => BookshelfViewSelection.tag(value),
      'category' =>
        value.isEmpty
            ? const BookshelfViewSelection.category(null)
            : BookshelfViewSelection.category(value),
      'todo' => const BookshelfViewSelection.base(BookshelfFilter.todo),
      'unread' => const BookshelfViewSelection.base(BookshelfFilter.unread),
      'reading' => const BookshelfViewSelection.base(BookshelfFilter.reading),
      'finished' => const BookshelfViewSelection.base(BookshelfFilter.finished),
      'local' => const BookshelfViewSelection.base(BookshelfFilter.local),
      'novel' => const BookshelfViewSelection.base(BookshelfFilter.novel),
      'manga' => const BookshelfViewSelection.base(BookshelfFilter.manga),
      _ => const BookshelfViewSelection.base(BookshelfFilter.all),
    };
  }
}

class BookshelfListPreferenceSnapshot {
  const BookshelfListPreferenceSnapshot({
    required this.showTitle,
    required this.showAuthor,
    required this.showLatestChapter,
    required this.showProgressBar,
    required this.progressInfoMode,
    required this.showSourceBadge,
    required this.showTaxonomyBadges,
    required this.showCover,
    required this.compactMode,
    required this.twoColumnMode,
    required this.showRecentReadTime,
    required this.alwaysShowSearchBar,
    required this.pinSearchBar,
    required this.quickFilterContent,
  });

  final bool showTitle;
  final bool showAuthor;
  final bool showLatestChapter;
  final bool showProgressBar;
  final BookshelfProgressInfoMode progressInfoMode;
  final bool showSourceBadge;
  final bool showTaxonomyBadges;
  final bool showCover;
  final bool compactMode;
  final bool twoColumnMode;
  final bool showRecentReadTime;
  final bool alwaysShowSearchBar;
  final bool pinSearchBar;
  final BookshelfSearchQuickFilterContent quickFilterContent;
}

class BookshelfGridPreferenceSnapshot {
  const BookshelfGridPreferenceSnapshot({
    required this.adaptiveColumns,
    required this.columnCount,
    required this.crossSpacing,
    required this.mainSpacing,
    required this.visualStyle,
    required this.showTitle,
    required this.titleCenter,
    required this.titleMaxLines,
    required this.coverShadow,
    required this.showAuthor,
    required this.showLatestChapter,
    required this.showProgressBar,
    required this.progressInfoMode,
    required this.showSourceBadge,
    required this.showTaxonomyBadges,
    required this.alwaysShowSearchBar,
    required this.pinSearchBar,
    required this.quickFilterContent,
  });

  final bool adaptiveColumns;
  final int columnCount;
  final double crossSpacing;
  final double mainSpacing;
  final BookshelfGridVisualStyle visualStyle;
  final bool showTitle;
  final bool titleCenter;
  final int titleMaxLines;
  final bool coverShadow;
  final bool showAuthor;
  final bool showLatestChapter;
  final bool showProgressBar;
  final BookshelfProgressInfoMode progressInfoMode;
  final bool showSourceBadge;
  final bool showTaxonomyBadges;
  final bool alwaysShowSearchBar;
  final bool pinSearchBar;
  final BookshelfSearchQuickFilterContent quickFilterContent;
}

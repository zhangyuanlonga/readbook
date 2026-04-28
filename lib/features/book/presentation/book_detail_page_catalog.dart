part of 'book_detail_page.dart';

extension on _BookDetailPageState {
  void _resetCatalogSearchCache() {
    _catalogSearchCacheFingerprint = null;
    _catalogSearchEntriesCache =
        const <String, List<ReaderCatalogSearchEntry>>{};
  }

  List<ReaderCatalogSearchEntry> _lookupCatalogSearchEntriesForDetail(
    String keyword,
    List<Chapter> chapters,
  ) {
    final result = _catalogService.lookupEntries(
      keyword: keyword,
      state: ReaderCatalogSearchCacheState(
        fingerprint: _catalogSearchCacheFingerprint,
        entriesCache: _catalogSearchEntriesCache,
      ),
      chapters: chapters,
    );
    _catalogSearchCacheFingerprint = result.state.fingerprint;
    _catalogSearchEntriesCache = result.state.entriesCache;
    return result.entries;
  }

  List<ReaderCatalogSearchEntry>? _peekCatalogSearchEntriesForDetail(
    String normalizedKeyword,
    List<Chapter> chapters,
  ) {
    return _catalogService.peekEntries(
      normalizedKeyword: normalizedKeyword,
      chapters: chapters,
      fingerprint: _catalogSearchCacheFingerprint,
      entriesCache: _catalogSearchEntriesCache,
      onFingerprintResolved:
          (fingerprint) => _catalogSearchCacheFingerprint = fingerprint,
      onCacheInvalidated: _resetCatalogSearchCache,
    );
  }

  int? _resolveCatalogSearchEntryTargetIndexForDetail(
    ReaderCatalogSearchEntry entry,
    List<Chapter> chapters,
  ) {
    return _catalogService.resolveEntryTargetIndex(entry, chapters);
  }

  Future<void> _openCatalogSheet(BookDetailLoadResult result) async {
    final chapters = _buildDisplayedChapters(result.chapters);
    if (chapters.isEmpty) {
      _showMessage('当前书籍暂无目录。');
      return;
    }

    final presentation = _resolvePresentedMetadata(result: result);
    final selected = await showReaderCatalogSheet(
      context: context,
      readerModalTheme: Theme.of(context),
      chapters: chapters,
      currentChapterIndex: null,
      bookTitle: presentation.displayTitle,
      bookAuthor: presentation.displayAuthor,
      bookCoverUrl: presentation.realCoverUrl,
      customCoverPath: presentation.customCoverPath,
      supportsContentSearch: false,
      bookmarkRepository: _bookmarkRepository,
      currentBookId: _activeBookId,
      peekCatalogSearchEntries:
          (normalizedKeyword) =>
              _peekCatalogSearchEntriesForDetail(normalizedKeyword, chapters),
      lookupCatalogSearchEntries:
          (keyword) => _lookupCatalogSearchEntriesForDetail(keyword, chapters),
      resolveCatalogSearchEntryTargetIndex:
          (entry) =>
              _resolveCatalogSearchEntryTargetIndexForDetail(entry, chapters),
      refreshChapterBookmarks: () async {},
      showMessage: _showMessage,
    );

    if (!mounted || selected == null) {
      return;
    }

    if (selected.selection != null) {
      final chapterIndex = selected.selection!.chapterIndex;
      if (chapterIndex >= 0 && chapterIndex < chapters.length) {
        _openChapter(chapters[chapterIndex]);
      }
      return;
    }

    final bookmark = selected.bookmark;
    if (bookmark == null) {
      return;
    }
    final chapter = _resolveChapterFromBookmark(chapters, bookmark);
    if (chapter != null) {
      _openChapter(chapter);
    }
  }

  Chapter? _resolveChapterFromBookmark(
    List<Chapter> chapters,
    Bookmark bookmark,
  ) {
    return _catalogService.resolveChapterFromBookmark(chapters, bookmark);
  }

}

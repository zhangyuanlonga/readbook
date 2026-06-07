part of 'book_detail_page.dart';

extension on _BookDetailPageState {
  Future<void> _handleOpenCatalogAction() async {
    final currentResult = _result;
    if (currentResult == null) {
      return;
    }

    final catalogRequestStopwatch = Stopwatch()..start();
    _logger.info(
      'Book detail catalog requested',
      context: <String, Object?>{
        'chain': 'book_detail',
        'step': 'catalog_requested',
        'bookId': currentResult.detail.id,
        'sourceId': currentResult.detail.sourceId,
        'detailUrl': currentResult.detail.detailUrl,
        'catalogLoaded': currentResult.catalogLoaded,
        'catalogAvailable': currentResult.catalogAvailable,
      },
    );
    final result = await _ensureCatalogLoaded(currentResult);
    if (!mounted || result == null) {
      return;
    }

    _logger.info(
      'Book detail catalog ready',
      context: <String, Object?>{
        'chain': 'book_detail',
        'step': 'catalog_ready',
        'bookId': result.detail.id,
        'sourceId': result.detail.sourceId,
        'detailUrl': result.detail.detailUrl,
        'catalogLoaded': result.catalogLoaded,
        'tocFromCache': result.tocFromCache,
        'chapterCount': result.chapters.length,
        'durationMs': catalogRequestStopwatch.elapsedMilliseconds,
      },
    );
    await _openCatalogSheet(result);
  }

  Future<BookDetailLoadResult?> _ensureCatalogLoaded(
    BookDetailLoadResult currentResult,
  ) async {
    if (currentResult.catalogLoaded && currentResult.catalogComplete) {
      return currentResult;
    }
    if (!_canOpenCatalogForResult(currentResult) || _isMissingParams) {
      _showMessage('当前书籍暂无目录。');
      return null;
    }
    if (_isCatalogLoading) {
      return null;
    }

    _updatePresentationState(
      _presentationState.copyWith(
        isCatalogLoading: true,
        clearTocWarningText: true,
      ),
    );

    final requestStopwatch = Stopwatch()..start();
    try {
      final detailProvider = _requireContentProvider(
        sourceId: _activeSourceId,
        stage: ErrorStage.toc,
      );
      final result = await detailProvider.loadDetail(
        sourceId: _activeSourceId!,
        bookId: _activeBookId,
        detailUrl: _activeDetailUrl!,
        initialBook: widget.initialBook,
        fallbackTitle: _displayTitle ?? widget.title,
        includeCatalog: true,
      );
      if (!mounted) {
        return result;
      }
      _activeBookId = result.detail.id.trim();
      _activeSourceId = result.detail.sourceId.trim();
      _activeDetailUrl = result.detail.detailUrl.trim();
      _displayTitle = result.detail.title.trim();
      _updatePresentationState(
        _presentationState.copyWith(
          isCatalogLoading: false,
          result: result,
          tocWarningText: _toTocWarningText(result.tocError),
        ),
      );
      unawaited(_loadSupplementaryState(result: result));
      return result;
    } on AppException catch (error) {
      if (!mounted) {
        return null;
      }
      _logger.warn(
        'Book detail catalog load failed',
        context: <String, Object?>{
          'chain': 'book_detail',
          'step': 'catalog_load_failed',
          'bookId': _activeBookId,
          'sourceId': _activeSourceId,
          'detailUrl': _activeDetailUrl,
          'code': error.code.name,
          'stage': error.stage.name,
          'durationMs': requestStopwatch.elapsedMilliseconds,
          'message': error.briefMessage,
        },
      );
      _updatePresentationState(
        _presentationState.copyWith(
          isCatalogLoading: false,
          tocWarningText: _toTocWarningText(error),
        ),
      );
      _showMessage(error.briefMessage);
      return null;
    } catch (_) {
      if (!mounted) {
        return null;
      }
      final message = _onlineSourceErrorAdapter.genericFailureForStage(
        ErrorStage.toc,
      );
      _logger.warn(
        'Book detail catalog load failed',
        context: <String, Object?>{
          'chain': 'book_detail',
          'step': 'catalog_load_failed',
          'bookId': _activeBookId,
          'sourceId': _activeSourceId,
          'detailUrl': _activeDetailUrl,
          'durationMs': requestStopwatch.elapsedMilliseconds,
          'message': message,
        },
      );
      _updatePresentationState(
        _presentationState.copyWith(
          isCatalogLoading: false,
          tocWarningText: message,
        ),
      );
      _showMessage(message);
      return null;
    }
  }

  Future<BookDetailLoadResult?> _ensureFirstReadableCatalogBatch(
    BookDetailLoadResult currentResult,
  ) async {
    if (currentResult.chapters.any(
      (chapter) => !chapter.isVolume && chapter.chapterUrl.trim().isNotEmpty,
    )) {
      return currentResult;
    }
    if (!_canOpenCatalogForResult(currentResult) || _isMissingParams) {
      _showMessage('当前书籍暂无目录。');
      return null;
    }
    if (_isCatalogLoading) {
      return null;
    }

    final sourceId = currentResult.detail.sourceId.trim();
    if (!isServerGatewaySourceId(sourceId)) {
      return _ensureCatalogLoaded(currentResult);
    }

    _updatePresentationState(
      _presentationState.copyWith(
        isCatalogLoading: true,
        clearTocWarningText: true,
      ),
    );

    final requestStopwatch = Stopwatch()..start();
    try {
      final result = await _bookDetailService.loadCatalogFirstBatch(
        currentResult: currentResult,
      );
      if (!mounted) {
        return result;
      }

      _activeBookId = result.detail.id.trim();
      _activeSourceId = result.detail.sourceId.trim();
      _activeDetailUrl = result.detail.detailUrl.trim();
      _displayTitle = result.detail.title.trim();
      _updatePresentationState(
        _presentationState.copyWith(
          isCatalogLoading: false,
          result: result,
          tocWarningText: _toTocWarningText(result.tocError),
        ),
      );
      unawaited(_loadSupplementaryState(result: result));
      _logger.info(
        'Book detail first catalog batch ready',
        context: <String, Object?>{
          'chain': 'book_detail',
          'step': 'catalog_first_batch_ready',
          'bookId': result.detail.id,
          'sourceId': result.detail.sourceId,
          'detailUrl': result.detail.detailUrl,
          'chapterCount': result.chapters.length,
          'catalogComplete': result.catalogComplete,
          'durationMs': requestStopwatch.elapsedMilliseconds,
        },
      );
      return result;
    } on AppException catch (error) {
      if (!mounted) {
        return null;
      }
      _logger.warn(
        'Book detail first catalog batch failed',
        context: <String, Object?>{
          'chain': 'book_detail',
          'step': 'catalog_first_batch_failed',
          'bookId': _activeBookId,
          'sourceId': _activeSourceId,
          'detailUrl': _activeDetailUrl,
          'code': error.code.name,
          'stage': error.stage.name,
          'durationMs': requestStopwatch.elapsedMilliseconds,
          'message': error.briefMessage,
        },
      );
      _updatePresentationState(
        _presentationState.copyWith(
          isCatalogLoading: false,
          tocWarningText: _toTocWarningText(error),
        ),
      );
      _showMessage(error.briefMessage);
      return null;
    } catch (_) {
      if (!mounted) {
        return null;
      }
      final message = _onlineSourceErrorAdapter.genericFailureForStage(
        ErrorStage.toc,
      );
      _logger.warn(
        'Book detail first catalog batch failed',
        context: <String, Object?>{
          'chain': 'book_detail',
          'step': 'catalog_first_batch_failed',
          'bookId': _activeBookId,
          'sourceId': _activeSourceId,
          'detailUrl': _activeDetailUrl,
          'durationMs': requestStopwatch.elapsedMilliseconds,
          'message': message,
        },
      );
      _updatePresentationState(
        _presentationState.copyWith(
          isCatalogLoading: false,
          tocWarningText: message,
        ),
      );
      _showMessage(message);
      return null;
    }
  }

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
    final resolvedCover = resolveBookCover(
      realCoverUrl: presentation.realCoverUrl,
      customCoverPath: presentation.customCoverPath,
      activeTheme: ref.read(activeAdvancedThemeProvider).valueOrNull,
      galleries: ref.read(coverGalleriesProvider).valueOrNull ?? const [],
      brightness: Theme.of(context).brightness,
      bookId: _activeBookId,
      sourceId: widget.sourceId,
      detailUrl: widget.detailUrl,
    );
    final selected = await showReaderCatalogSheet(
      context: context,
      readerModalTheme: Theme.of(context),
      chapters: chapters,
      currentChapterIndex: null,
      bookTitle: presentation.displayTitle,
      bookAuthor: presentation.displayAuthor,
      bookCoverUrl: presentation.realCoverUrl,
      customCoverPath: presentation.customCoverPath,
      resolvedCover: resolvedCover,
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

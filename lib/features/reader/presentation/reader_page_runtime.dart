// ignore_for_file: invalid_use_of_protected_member

part of 'reader_page.dart';

extension _ReaderPageRuntimeExtension on _ReaderPageState {
  void _markFirstPageTurnRequested() {
    if (_hasLoggedFirstPageTurn || _firstPageTurnStopwatch != null) {
      return;
    }
    _firstPageTurnStopwatch = Stopwatch()..start();
  }

  void _recordFirstPageTurnCompleted({required String mode}) {
    final stopwatch = _firstPageTurnStopwatch;
    if (_hasLoggedFirstPageTurn || stopwatch == null) {
      return;
    }
    _hasLoggedFirstPageTurn = true;
    _firstPageTurnStopwatch = null;
    _logger.info(
      'Reader first page turn completed',
      context: <String, Object?>{
        'chain': 'reader_open',
        'step': 'first_page_turn',
        'bookId': _currentBookId,
        'sourceId': _sourceId,
        'detailUrl': _detailUrl,
        'chapterId': _chapterId,
        'mode': mode,
        'durationMs': stopwatch.elapsedMilliseconds,
      },
    );
  }

  void _scheduleReadingRecordSessionStart({double? initialRatio}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isBootstrapping || _isLoadingContent) {
        return;
      }
      _maybeStartReadingRecordSession(
        initialRatio: initialRatio ?? _currentScrollRatio(),
      );
    });
  }

  void _scheduleReaderInfoMinuteTick() {
    _readerInfoClockTimer?.cancel();
    if (!mounted || !_isReaderRuntimeVisible) {
      _readerInfoClockTimer = null;
      return;
    }
    _readerInfoClockTimer = Timer(
      _runtimeWakePolicy.nextMinuteDelay(DateTime.now()),
      () {
        if (!mounted || !_isReaderRuntimeVisible) {
          return;
        }
        unawaited(
          _refreshReaderInfoSnapshot().then((_) {
            if (!mounted) {
              return;
            }
            _scheduleReaderInfoMinuteTick();
          }),
        );
      },
    );
  }

  void _setContent(
    String content, {
    List<String> imageUrls = const [],
    Map<String, String> imageHeaders = const {},
    ReaderDocument? document,
    List<String>? precomputedParagraphs,
    List<List<ReaderPagedSlice>>? precomputedPagedPages,
    int? precomputedCurrentPageIndex,
    String? precomputedPaginationSignature,
  }) {
    _setContentFlow(
      content,
      imageUrls: imageUrls,
      imageHeaders: imageHeaders,
      document: document,
      precomputedParagraphs: precomputedParagraphs,
      precomputedPagedPages: precomputedPagedPages,
      precomputedCurrentPageIndex: precomputedCurrentPageIndex,
      precomputedPaginationSignature: precomputedPaginationSignature,
    );
  }

  Future<bool> _tryHydrateVisibleContentFromCache() {
    return _tryHydrateVisibleContentFromCacheFlow();
  }

  Future<bool> _loadCurrentChapter({
    double? initialScrollRatio,
    ReaderLogicalPosition? initialLogicalPosition,
    String? sourceIdOverride,
    String? chapterIdOverride,
    String? chapterUrlOverride,
    String? chapterTitleOverride,
    int? chapterIndexOverride,
    bool commitChapterIdentity = false,
  }) {
    return _loadCurrentChapterFlow(
      initialScrollRatio: initialScrollRatio,
      initialLogicalPosition: initialLogicalPosition,
      sourceIdOverride: sourceIdOverride,
      chapterIdOverride: chapterIdOverride,
      chapterUrlOverride: chapterUrlOverride,
      chapterTitleOverride: chapterTitleOverride,
      chapterIndexOverride: chapterIndexOverride,
      commitChapterIdentity: commitChapterIdentity,
    );
  }

  GlobalKey _continuousTextChapterKey(_ContinuousTextChapter chapter) {
    final identity =
        chapter.chapterUrl.trim().isNotEmpty
            ? chapter.chapterUrl.trim()
            : '${chapter.chapterIndex}:${chapter.chapterId}';
    return _continuousTextChapterKeys.putIfAbsent(identity, () => GlobalKey());
  }

  Future<_ContinuousTextChapter?> _loadAdjacentContinuousTextChapter({
    required bool forward,
  }) {
    return _loadAdjacentContinuousTextChapterFlow(forward: forward);
  }

  bool _isContinuousTextChapterActive(_ContinuousTextChapter chapter) {
    return _isContinuousTextChapterActiveFlow(chapter);
  }

  _ContinuousTextChapter? _findCurrentContinuousTextChapter() {
    return _findCurrentContinuousTextChapterFlow();
  }

  double _continuousTextChapterScrollRatioFor(_ContinuousTextChapter chapter) {
    return _continuousTextChapterScrollRatioForFlow(chapter);
  }

  void _syncActiveContinuousTextChapterFromScroll() {
    _syncActiveContinuousTextChapterFromScrollFlow();
  }

  void _syncContinuousTextFlowAfterSettingsApplied() {
    _syncContinuousTextFlowAfterSettingsAppliedFlow();
  }

  void _resetCatalogSearchCache() {
    _catalogSearchCacheFingerprint = null;
    _catalogSearchEntriesCache =
        const <String, List<ReaderCatalogSearchEntry>>{};
  }

  void _storePrecomputedChapterLayout({
    required String sourceId,
    required String chapterUrl,
    required ReaderPrecomputedChapterLayout layout,
  }) {
    _paginationCacheService.storePrecomputedChapterLayout(
      sourceId: sourceId,
      chapterUrl: chapterUrl,
      layout: layout,
    );
  }

  Future<ReaderPrecomputedChapterLayout?> _loadPrecomputedChapterLayout({
    required String sourceId,
    required String chapterUrl,
    required String signature,
  }) {
    return _paginationCacheService.loadPrecomputedChapterLayout(
      sourceId: sourceId,
      chapterUrl: chapterUrl,
      signature: signature,
    );
  }

  bool get _isLowPriorityReaderWorkPaused =>
      _readerInteractionState == _ReaderInteractionState.dragging ||
      _readerInteractionState == _ReaderInteractionState.animating ||
      _readerInteractionState == _ReaderInteractionState.settling;

  void _setReaderInteractionState(_ReaderInteractionState state) {
    if (_readerInteractionState == state) {
      return;
    }
    _readerInteractionState = state;
    if (state == _ReaderInteractionState.idle && _deferredNeighborPreload) {
      _deferredNeighborPreload = false;
      _startNeighborPreloadNow();
    }
  }

  void _markReaderInteractionBusy(_ReaderInteractionState state) {
    _readerInteractionSettleTimer?.cancel();
    _readerInteractionSettleTimer = null;
    _setReaderInteractionState(state);
  }

  void _scheduleReaderInteractionSettle() {
    if (!mounted) {
      return;
    }
    _setReaderInteractionState(_ReaderInteractionState.settling);
    _readerInteractionSettleTimer?.cancel();
    _readerInteractionSettleTimer = Timer(
      const Duration(milliseconds: 200),
      () {
        if (!mounted) {
          return;
        }
        _readerInteractionSettleTimer = null;
        _setReaderInteractionState(_ReaderInteractionState.idle);
      },
    );
  }

  void _handlePagedScrollInteractionChanged(bool isInteracting) {
    if (isInteracting) {
      _markReaderInteractionBusy(_ReaderInteractionState.dragging);
    } else {
      _scheduleReaderInteractionSettle();
    }
  }

  void _scheduleNeighborPreload() {
    if (_isLowPriorityReaderWorkPaused) {
      _deferredNeighborPreload = true;
      return;
    }
    _startNeighborPreloadNow();
  }

  void _startNeighborPreloadNow() {
    final preloadTaskToken = _readerSessionController.nextPreloadTaskToken();
    unawaited(_preloadNeighborsFlow(taskToken: preloadTaskToken));
  }

  void _disposeMangaTransformControllers() {
    // ReaderMangaView owns zoom controllers and gesture state after stage F.
  }

  void _restoreScrollPosition(double ratio) {
    final normalized = ratio.clamp(0.0, 1.0);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      switch (_currentViewportKind) {
        case ReaderModeViewportKind.textPaged:
          final plan = _activeTextRenderer.planRestore(
            ratio: normalized,
            metrics: _currentTextRenderMetrics(),
          );
          if (plan.shouldDefer) {
            _pagedPaginationState = _pagedPaginationState.copyWith(
              pendingRestoreRatio: plan.normalizedRatio,
            );
            return;
          }
          setState(() {
            _currentPageIndex = plan.pageIndex ?? 0;
          });
          return;
        case ReaderModeViewportKind.imagePaged:
          final total = _chapterImageUrls.length;
          if (total <= 1) {
            setState(() {
              _mangaPageIndex = 0;
            });
            return;
          }

          final target = (normalized * (total - 1)).round().clamp(0, total - 1);
          if (_mangaPageController.hasClients) {
            _mangaPageController.jumpToPage(target);
          }
          setState(() {
            _mangaPageIndex = target;
          });
          return;
        case ReaderModeViewportKind.hybridPaged:
          final total = _chapterImageUrls.length;
          if (total <= 1) {
            setState(() {
              _mangaPageIndex = 0;
            });
            return;
          }
          final target = (normalized * (total - 1)).round().clamp(0, total - 1);
          if (_mangaPageController.hasClients) {
            _mangaPageController.jumpToPage(target);
          }
          setState(() {
            _mangaPageIndex = target;
          });
          return;
        case ReaderModeViewportKind.textScroll:
        case ReaderModeViewportKind.imageScroll:
          if (!_scrollController.hasClients) {
            return;
          }
          final plan = _activeTextRenderer.planRestore(
            ratio: normalized,
            metrics: _currentTextRenderMetrics(),
          );
          _scrollController.jumpTo(plan.scrollOffset ?? 0);
          return;
      }
    });
  }

  bool _canRunAutoReadNow() {
    if (_settings.autoReadMode == ReaderAutoReadMode.page) {
      return _canRunPagedAutoReadNow();
    }
    final hasScrollClients = _scrollController.hasClients;
    final position = hasScrollClients ? _scrollController.position : null;
    return _autoReadCoordinator.canRunNow(
      isAutoReadSessionEnabled:
          _autoReadSessionState == ReaderAutoReadSessionState.running,
      isMangaChapter: _isMangaChapter,
      isPagedTextReaderEnabled: _isPagedTextReaderEnabled(),
      isReaderVisible: _isReaderRuntimeVisible,
      isLowBattery: _isReaderBatteryLowForRuntime,
      showOverlayControls: _showOverlayControls,
      isBootstrapping: _isBootstrapping,
      isLoadingContent: _isLoadingContent,
      hasError: _errorText != null,
      hasTextContent:
          _content.trim().isNotEmpty ||
          (_chapterAudioUrl?.trim().isNotEmpty ?? false) ||
          (_chapterAudioManifestUrl?.trim().isNotEmpty ?? false),
      hasScrollClients: hasScrollClients,
      maxScrollExtent: position?.maxScrollExtent ?? 0,
      scrollOffset: position?.pixels ?? 0,
    );
  }

  bool _canRunPagedAutoReadNow() {
    return _autoReadCoordinator.canRunPagedNow(
      isAutoReadSessionEnabled:
          _autoReadSessionState == ReaderAutoReadSessionState.running,
      isMangaChapter: _isMangaChapter,
      isPagedTextReaderEnabled: _isPagedTextReaderEnabled(),
      isReaderVisible: _isReaderRuntimeVisible,
      isLowBattery: _isReaderBatteryLowForRuntime,
      showOverlayControls: _showOverlayControls,
      isBootstrapping: _isBootstrapping,
      isLoadingContent: _isLoadingContent,
      hasError: _errorText != null,
      hasTextContent: _content.trim().isNotEmpty,
      isPaginating: _pagedPaginationState.isPaginating,
      isAnimating: _isPagedTransitionAnimating || _isCurlAutoTurning,
      pageCount: _currentPagedPageCount,
    );
  }

  double _autoReadProgressRatio() {
    if (!_scrollController.hasClients) {
      return 0;
    }
    final maxExtent = _scrollController.position.maxScrollExtent;
    if (maxExtent <= 0) {
      return 1;
    }
    return (_scrollController.position.pixels / maxExtent).clamp(0.0, 1.0);
  }

  Future<void> _refreshChapterBookmarks() async {
    final bookId = _currentBookId;
    if (bookId.isEmpty) {
      return;
    }
    try {
      final all = await _bookmarkRepository.listBookmarks(bookId);
      final filtered = all
          .where(_isBookmarkInCurrentChapter)
          .toList(growable: false);
      final ranges = _buildBookmarkRangesByParagraph(filtered);
      if (!mounted) {
        return;
      }
      setState(() {
        _chapterBookmarks = filtered;
        _bookmarkRangesByParagraph = ranges;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _chapterBookmarks = const [];
        _bookmarkRangesByParagraph = const <int, List<_BookmarkRange>>{};
      });
    }
  }

  Future<void> _consumePendingBookmarkJump() async {
    final pendingId = _pendingBookmarkId?.trim() ?? '';
    if (pendingId.isEmpty) {
      return;
    }
    _pendingBookmarkId = null;

    try {
      final items = await _bookmarkRepository.listBookmarks(_currentBookId);
      Bookmark? target;
      for (final bookmark in items) {
        if (bookmark.id == pendingId) {
          target = bookmark;
          break;
        }
      }
      if (target == null) {
        _showMessage('未找到对应灵感。');
        return;
      }
      await _jumpToBookmark(target);
    } catch (_) {
      _showMessage('灵感定位失败，请稍后重试。');
    }
  }

  Future<void> _jumpToBookmark(Bookmark bookmark) async {
    final request = _navigationEntryResolver.resolveBookmarkSelection(
      bookmark: bookmark,
      chapters: _chapters,
    );
    if (request == null) {
      _showMessage('未找到灵感所在章节。');
      return;
    }
    await _executeNavigationRequest(request);
  }

  bool _isAutoReadAtChapterEnd() {
    if (_settings.autoReadMode == ReaderAutoReadMode.page &&
        _isPagedTextReaderEnabled()) {
      final pageCount = _currentPagedPageCount;
      return pageCount > 0 && _currentPageIndex >= pageCount - 1;
    }
    final hasScrollClients = _scrollController.hasClients;
    final position = hasScrollClients ? _scrollController.position : null;
    return _autoReadCoordinator.isAtChapterEnd(
      hasScrollClients: hasScrollClients,
      maxScrollExtent: position?.maxScrollExtent ?? 0,
      scrollOffset: position?.pixels ?? 0,
    );
  }

  void _scheduleAutoReadResume() {
    if (!mounted) {
      return;
    }
    _autoReadResumeTimer?.cancel();
    if (!_isAutoReadSessionEnabled) {
      return;
    }
    _autoReadResumeTimer = Timer(_ReaderPageState._kAutoReadResumeDelay, () {
      if (_autoReadSessionState == ReaderAutoReadSessionState.paused &&
          !_isAutoReadPausedByRuntime) {
        return;
      }
      _isAutoReadPausedByRuntime = false;
      _autoReadSessionState = ReaderAutoReadSessionState.running;
      if (mounted) {
        setState(() {});
      }
      _reconcileAutoRead();
    });
  }

  void _reconcileAutoRead({bool restart = false}) {
    if (!mounted) {
      return;
    }
    if (restart) {
      _stopAutoRead();
    }
    if (!_isAutoReadSessionEnabled) {
      _stopAutoRead();
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (_canRunAutoReadNow()) {
        _startAutoReadIfNeeded();
      } else {
        _stopAutoRead();
        if (_settings.autoReadMode == ReaderAutoReadMode.page) {
          _stopPagedAutoRead();
          if (_isAutoReadAtChapterEnd()) {
            unawaited(_handleAutoReadChapterBoundary());
          }
        } else {
          unawaited(_handleAutoReadChapterBoundary());
        }
      }
    });
  }

  void _startAutoReadIfNeeded() {
    if (_settings.autoReadMode == ReaderAutoReadMode.page) {
      _startPagedAutoReadIfNeeded();
      return;
    }
    if (_isAutoReadRunning || !_canRunAutoReadNow()) {
      return;
    }

    _isAutoReadRunning = true;
    final token = ++_autoReadTaskToken;
    unawaited(_runAutoReadLoop(token));
  }

  Future<void> _runAutoReadLoop(int token) async {
    while (mounted && token == _autoReadTaskToken) {
      if (!_canRunAutoReadNow()) {
        break;
      }

      final position = _scrollController.position;
      final target = _autoReadCoordinator.resolveStepTargetOffset(
        currentOffset: position.pixels,
        maxScrollExtent: position.maxScrollExtent,
        autoReadSpeed: _settings.autoReadSpeed,
        stepDuration: _ReaderPageState._kAutoReadStepDuration,
      );

      if ((target - position.pixels).abs() < 0.5) {
        break;
      }

      try {
        await _scrollController.animateTo(
          target,
          duration: _ReaderPageState._kAutoReadStepDuration,
          curve: Curves.linear,
        );
      } catch (_) {
        break;
      }
    }

    if (token == _autoReadTaskToken) {
      _isAutoReadRunning = false;
      unawaited(_handleAutoReadChapterBoundary());
    }
  }

  void _startPagedAutoReadIfNeeded() {
    if (_autoReadPagedTimer != null || !_canRunPagedAutoReadNow()) {
      return;
    }
    _schedulePagedAutoReadTurn();
  }

  void _schedulePagedAutoReadTurn() {
    _autoReadPagedTimer?.cancel();
    _autoReadPagedTimer = Timer(
      _autoReadCoordinator.resolvePagedHoldDuration(
        speedLevel: _settings.autoReadSpeedLevel,
      ),
      () {
        _autoReadPagedTimer = null;
        unawaited(_runPagedAutoReadTurn());
      },
    );
  }

  Future<void> _runPagedAutoReadTurn() async {
    if (!_canRunPagedAutoReadNow()) {
      if (_isAutoReadAtChapterEnd()) {
        await _handleAutoReadChapterBoundary();
      }
      return;
    }
    if (_isAutoReadAtChapterEnd()) {
      await _handleAutoReadChapterBoundary();
      return;
    }

    await _turnPagedTextPage(direction: 1);
    if (!mounted ||
        _autoReadSessionState != ReaderAutoReadSessionState.running) {
      return;
    }
    if (_settings.autoReadPauseMode == ReaderAutoReadPauseMode.paragraphEnd) {
      await Future<void>.delayed(
        _autoReadCoordinator.paragraphPauseDuration(
          speedLevel: _settings.autoReadSpeedLevel,
        ),
      );
    }
    if (!mounted ||
        _autoReadSessionState != ReaderAutoReadSessionState.running) {
      return;
    }
    if (_isAutoReadAtChapterEnd()) {
      await _handleAutoReadChapterBoundary();
      return;
    }
    _schedulePagedAutoReadTurn();
  }

  void _stopPagedAutoRead() {
    _autoReadPagedTimer?.cancel();
    _autoReadPagedTimer = null;
  }

  Future<void> _handleAutoReadChapterBoundary() async {
    if (!_isAutoReadSessionEnabled ||
        _autoReadSessionState != ReaderAutoReadSessionState.running ||
        _isAutoReadHandlingBoundary) {
      return;
    }
    if (!_isAutoReadAtChapterEnd()) {
      return;
    }
    _isAutoReadHandlingBoundary = true;
    try {
      if (_settings.autoReadPauseMode == ReaderAutoReadPauseMode.chapterEnd) {
        _enterAutoReadChapterPaused();
        return;
      }

      final advanced = await _tryAdvanceAutoReadToNextChapter();
      if (advanced) {
        return;
      }
      await _handleAutoReadBookFinished();
    } finally {
      _isAutoReadHandlingBoundary = false;
    }
  }

  Future<bool> _tryAdvanceAutoReadToNextChapter() async {
    if (_isAutoReadAdvancingChapter) {
      return false;
    }
    _isAutoReadAdvancingChapter = true;
    try {
      return await _jumpToAdjacentReadableChapter(
        forward: true,
        showBoundaryHint: false,
      );
    } finally {
      _isAutoReadAdvancingChapter = false;
    }
  }

  void _enterAutoReadChapterPaused() {
    if (!mounted || !_isAutoReadSessionEnabled) {
      return;
    }
    _stopAutoRead();
    _stopPagedAutoRead();
    setState(() {
      _autoReadSessionState = ReaderAutoReadSessionState.chapterPaused;
    });
  }

  Future<void> _continueAutoReadAfterChapterPause() async {
    if (!_isAutoReadSessionEnabled ||
        _autoReadSessionState != ReaderAutoReadSessionState.chapterPaused) {
      return;
    }
    final advanced = await _tryAdvanceAutoReadToNextChapter();
    if (!mounted || !_isAutoReadSessionEnabled) {
      return;
    }
    if (!advanced) {
      await _handleAutoReadBookFinished();
      return;
    }
    _autoReadSessionState = ReaderAutoReadSessionState.running;
    if (mounted) {
      setState(() {});
    }
    _autoReadResumeTimer?.cancel();
    _autoReadResumeTimer = Timer(
      _ReaderPageState._kAutoReadBoundaryResumeDelay,
      () {
        if (!mounted ||
            _autoReadSessionState != ReaderAutoReadSessionState.running) {
          return;
        }
        _reconcileAutoRead(restart: true);
      },
    );
  }

  Future<void> _handleAutoReadBookFinished() async {
    if (!mounted || !_isAutoReadSessionEnabled) {
      return;
    }
    switch (_settings.autoReadEndBehavior) {
      case ReaderAutoReadEndBehavior.loopBook:
        final firstChapterIndex = _chapterNavigation.findReadableChapterIndex(
          _chapters,
          0,
          forward: true,
        );
        if (firstChapterIndex == null) {
          _finishAutoReadSession('本书已读完。');
          return;
        }
        await _jumpTo(firstChapterIndex, initialScrollRatio: 0);
        if (!mounted || !_isAutoReadSessionEnabled) {
          return;
        }
        _autoReadSessionState = ReaderAutoReadSessionState.running;
        setState(() {});
        _reconcileAutoRead(restart: true);
        return;
      case ReaderAutoReadEndBehavior.nextBook:
        final opened = await _openNextBookshelfBookForAutoRead();
        if (!opened) {
          _finishAutoReadSession('未找到下一本书，已停止自动阅读。');
        }
        return;
      case ReaderAutoReadEndBehavior.stop:
        _finishAutoReadSession('本书已读完。');
        return;
    }
  }

  Future<bool> _openNextBookshelfBookForAutoRead() async {
    try {
      final books = await _bookshelfService.getAll();
      if (books.length <= 1) {
        return false;
      }
      final currentBookId = _currentBookId;
      final currentSourceId = _sourceId?.trim() ?? '';
      final currentDetailUrl = _detailUrl?.trim() ?? '';
      final currentIndex = books.indexWhere((book) {
        if (book.bookId.trim() != currentBookId) {
          return false;
        }
        if (currentSourceId.isNotEmpty &&
            book.sourceId.trim() != currentSourceId) {
          return false;
        }
        if (currentDetailUrl.isNotEmpty &&
            book.detailUrl.trim() != currentDetailUrl) {
          return false;
        }
        return true;
      });
      if (currentIndex < 0 || currentIndex >= books.length - 1) {
        return false;
      }
      final nextBook = books[currentIndex + 1];
      final route = const ReaderEntryRouteResolver()
          .buildRouteFromBookshelfFallback(
            nextBook,
            openRequestedAtMs: DateTime.now().millisecondsSinceEpoch,
            openRouteKind: 'auto_read_next_book',
          );
      _stopAutoReadSession(showMessage: false);
      if (!mounted) {
        return false;
      }
      context.go(route);
      return true;
    } catch (_) {
      return false;
    }
  }

  void _finishAutoReadSession(String message) {
    if (!mounted || !_isAutoReadSessionEnabled) {
      return;
    }
    _stopAutoRead();
    _stopPagedAutoRead();
    setState(() {
      _autoReadSessionState = ReaderAutoReadSessionState.finished;
    });
    _showMessage(
      message,
      duration: _ReaderPageState._kReaderSnackActionDuration,
      dedupeKey: 'auto_read_finished',
    );
    _stopAutoReadSession(showMessage: false);
  }

  void _stopAutoRead() {
    _autoReadTaskToken += 1;
    _isAutoReadRunning = false;
    _stopPagedAutoRead();
    _autoReadResumeTimer?.cancel();
    _autoReadResumeTimer = null;
    if (!_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    final stableOffset = position.pixels.clamp(0.0, position.maxScrollExtent);
    try {
      _scrollController.jumpTo(stableOffset);
    } catch (_) {
      // ignore
    }
  }

  bool get _isReaderBatteryLowForRuntime =>
      _readerBatteryLevel != null && _readerBatteryLevel! <= 15;

  void _pauseAutoReadForRuntime() {
    if (!_isAutoReadSessionEnabled) {
      return;
    }
    _isAutoReadPausedByRuntime = true;
    _autoReadSessionState = ReaderAutoReadSessionState.paused;
    _stopAutoRead();
  }

  void _pauseAutoReadIfRuntimePolicyRequires() {
    if (!_runtimeWakePolicy.shouldPauseAutoRead(
      isReaderVisible: _isReaderRuntimeVisible,
      showOverlayControls: _showOverlayControls,
      isLowBattery: _isReaderBatteryLowForRuntime,
    )) {
      return;
    }
    _pauseAutoReadForRuntime();
  }

  void _onScrollChanged() {
    if (!_isTextScrollViewport) {
      return;
    }
    if (_isBootstrapping || _isLoadingContent || _errorText != null) {
      return;
    }
    if ((_content.trim().isEmpty &&
            _chapterImageUrls.isEmpty &&
            (_chapterAudioUrl?.trim().isEmpty ?? true) &&
            (_chapterAudioManifestUrl?.trim().isEmpty ?? true)) ||
        _currentIndex == null) {
      return;
    }

    _syncActiveContinuousTextChapterFromScroll();
    _maybePrefetchContinuousTextNeighbors();
    _syncActiveReadingRecordSessionProgress();
    _scheduleProgressSave();
  }

  void _maybePrefetchContinuousTextNeighbors() {
    if (!_shouldUseContinuousTextFlow ||
        !_scrollController.hasClients ||
        _continuousTextChapters.isEmpty ||
        _isScrollEdgeAdvancingChapter ||
        _isAutoReadAdvancingChapter) {
      return;
    }

    final position = _scrollController.position;
    final prefetchBottomDistance = max(240.0, position.viewportDimension * 0.7);
    final prefetchTopDistance = max(120.0, position.viewportDimension * 0.3);
    final remainingBottom = position.maxScrollExtent - position.pixels;

    if (remainingBottom <= prefetchBottomDistance) {
      unawaited(_loadAdjacentContinuousTextChapter(forward: true));
    }
    if (position.pixels <= prefetchTopDistance) {
      unawaited(_loadAdjacentContinuousTextChapter(forward: false));
    }
    if (_document.hasImageBlocks) {
      _scheduleInlineImagePrecacheNearProgress(limit: 6);
    }
  }

  void _scheduleProgressSave() {
    _progressDebounceTimer?.cancel();
    final delay = _runtimeWakePolicy.progressSaveDelay(
      lastSavedAt: _lastProgressSavedAt,
      now: DateTime.now(),
    );
    if (delay <= Duration.zero) {
      _flushProgressSave();
      return;
    }
    _progressDebounceTimer = Timer(delay, _flushProgressSave);
  }

  void _flushProgressSave() {
    _progressDebounceTimer?.cancel();
    _progressDebounceTimer = null;
    _lastProgressSavedAt = DateTime.now();
    unawaited(_saveProgress());
  }

  void _maybeStartReadingRecordSession({double? initialRatio}) {
    final result = _readingRecordCoordinator.startOrUpdateSession(
      readingRecordEnabled: _readingRecordEnabled,
      isBootstrapping: _isBootstrapping,
      isLoadingContent: _isLoadingContent,
      hasError: _errorText != null,
      hasVisibleReaderContent: _hasVisibleReaderContent,
      sourceId: _sourceId,
      detailUrl: _detailUrl,
      bookTitle: _bookTitle,
      currentBookId: _currentBookId,
      chapterId: _chapterId,
      chapterUrl: _chapterUrl,
      chapterTitle: _chapterTitle,
      chapterIndex: _currentIndex,
      bookAuthor: _bookAuthor,
      coverUrl: _bookCoverUrl,
      initialRatio: initialRatio ?? _currentScrollRatio(),
      now: DateTime.now(),
      existingSession: _activeReadingRecordSession,
    );
    _activeReadingRecordSession = result.session;
    if (result.cancelAutoCommitTimer) {
      _readingRecordAutoCommitTimer?.cancel();
      _readingRecordAutoCommitTimer = null;
      return;
    }
    if (result.scheduleAutoCommitTimer) {
      _scheduleReadingRecordAutoCommit();
    }
  }

  void _syncActiveReadingRecordSessionProgress({double? ratio}) {
    final session = _activeReadingRecordSession;
    if (session == null) {
      return;
    }
    _activeReadingRecordSession = _readingRecordCoordinator.syncProgress(
      session: session,
      ratio: ratio ?? _currentScrollRatio(),
    );
  }

  void _scheduleReadingRecordAutoCommit() {
    _readingRecordAutoCommitTimer?.cancel();
    if (_activeReadingRecordSession == null) {
      _readingRecordAutoCommitTimer = null;
      return;
    }
    final interval = _readingRecordCoordinator.autoCommitInterval(
      hasActiveSession: _activeReadingRecordSession != null,
    );
    if (interval <= Duration.zero) {
      _readingRecordAutoCommitTimer = null;
      return;
    }
    _readingRecordAutoCommitTimer = Timer(interval, () {
      if (!mounted) {
        return;
      }
      final restartRatio = _currentScrollRatio();
      _commitReadingRecordSession();
      _maybeStartReadingRecordSession(initialRatio: restartRatio);
    });
  }

  void _commitReadingRecordSession({double? endRatio}) {
    _readingRecordAutoCommitTimer?.cancel();
    _readingRecordAutoCommitTimer = null;
    final session = _activeReadingRecordSession;
    _activeReadingRecordSession = null;
    if (session == null) {
      return;
    }
    final resolvedEndRatio =
        endRatio ??
        (mounted ? _currentScrollRatio() : session.furthestPositionRatio);
    final commitInput = _readingRecordCoordinator.buildCommitInput(
      readingRecordEnabled: _readingRecordEnabled,
      session: session,
      endAt: DateTime.now(),
      endRatio: resolvedEndRatio,
      chapterLength: _chapterTextLength(),
      isMangaChapter: _isMangaChapter,
    );
    if (commitInput == null) {
      return;
    }

    unawaited(_readingRecordService.commitSession(commitInput));
  }

  double _currentScrollRatio() {
    switch (_currentViewportKind) {
      case ReaderModeViewportKind.textPaged:
        return _activeTextRenderer.captureProgress(_currentTextRenderMetrics());
      case ReaderModeViewportKind.imagePaged:
      case ReaderModeViewportKind.hybridPaged:
        final total = _chapterImageUrls.length;
        if (total <= 1) {
          return 0;
        }
        return (_mangaPageIndex / (total - 1)).clamp(0.0, 1.0);
      case ReaderModeViewportKind.textScroll:
      case ReaderModeViewportKind.imageScroll:
        if (_shouldUseContinuousTextFlow) {
          final currentChapter = _findCurrentContinuousTextChapter();
          if (currentChapter != null) {
            return _continuousTextChapterScrollRatioFor(currentChapter);
          }
        }
        return _activeTextRenderer.captureProgress(_currentTextRenderMetrics());
    }
  }

  void _showChapterSwitchFailedSnackbar(int targetIndex) {
    if (!mounted) {
      return;
    }

    _showReaderSnackBar(
      text: '切换章节失败，已回退到上一章。',
      duration: _ReaderPageState._kReaderSnackActionDuration,
      dedupeKey: 'chapter_switch_failed',
      actionLabel: '重试',
      onActionPressed: () => unawaited(_jumpTo(targetIndex)),
    );
  }

  void _scheduleBlockingLoadingCard() {
    _blockingLoadingCardTimer?.cancel();
    _blockingLoadingCardTimer = null;
    _showBlockingLoadingCard = false;

    if (!_needsBlockingLoadingUi) {
      return;
    }

    _blockingLoadingCardTimer = Timer(
      _ReaderPageState._kBlockingLoadingCardDelay,
      () {
        if (!mounted || !_needsBlockingLoadingUi) {
          return;
        }
        setState(() {
          _showBlockingLoadingCard = true;
        });
      },
    );
  }

  void _scheduleHiddenLoadingPlaceholder() {
    _hiddenLoadingPlaceholderTimer?.cancel();
    _hiddenLoadingPlaceholderTimer = null;
    _showHiddenLoadingPlaceholder = false;

    if (!_needsBlockingLoadingUi) {
      return;
    }

    _hiddenLoadingPlaceholderTimer = Timer(
      _ReaderPageState._kHiddenLoadingPlaceholderDelay,
      () {
        if (!mounted || !_needsBlockingLoadingUi) {
          return;
        }
        setState(() {
          _showHiddenLoadingPlaceholder = true;
        });
      },
    );
  }

  void _clearDelayedLoadingUi() {
    _chapterLoadingIndicatorTimer?.cancel();
    _chapterLoadingIndicatorTimer = null;
    _blockingLoadingCardTimer?.cancel();
    _blockingLoadingCardTimer = null;
    _hiddenLoadingPlaceholderTimer?.cancel();
    _hiddenLoadingPlaceholderTimer = null;
    _showChapterLoadingIndicator = false;
    _showBlockingLoadingCard = false;
    _showHiddenLoadingPlaceholder = false;
  }

  void _scheduleChapterLoadingIndicator() {
    _chapterLoadingIndicatorTimer?.cancel();
    _chapterLoadingIndicatorTimer = null;
    _showChapterLoadingIndicator = false;

    if (_isBootstrapping ||
        _isSwitchSourceLoading ||
        !_hasVisibleReaderContent) {
      return;
    }

    _chapterLoadingIndicatorTimer = Timer(
      _ReaderPageState._kChapterLoadingIndicatorDelay,
      () {
        if (!mounted ||
            !_isLoadingContent ||
            _shouldShowBlockingReaderLoading) {
          return;
        }
        setState(() {
          _showChapterLoadingIndicator = true;
        });
      },
    );
  }

  Future<void> _saveProgress() async {
    final sourceId = _sourceId;
    final detailUrl = _detailUrl;
    final chapterUrl = _chapterUrl;
    final chapterTitle = _chapterTitle;
    final currentIndex = _currentIndex;

    if (sourceId == null ||
        detailUrl == null ||
        chapterUrl == null ||
        chapterTitle == null ||
        currentIndex == null) {
      return;
    }

    final normalizedDetailUrl = _normalizeLocalDetailUrlForProgress(detailUrl);
    final normalizedChapterUrl = _normalizeLocalChapterUrlForProgress(
      chapterUrl,
    );
    final logicalPosition = _currentLogicalPosition();
    final viewportState = _currentViewportState();

    await _preferencesService.saveProgress(
      ReadingProgress(
        bookId: _currentBookId,
        sourceId: sourceId,
        detailUrl: normalizedDetailUrl,
        chapterId: _chapterId,
        chapterUrl: normalizedChapterUrl,
        chapterTitle: chapterTitle,
        chapterIndex: currentIndex,
        updatedAt: DateTime.now(),
        chapterPositionRatio: _currentScrollRatio(),
        logicalPosition: logicalPosition?.copyWith(
          pageIndex: viewportState.pageIndex,
          totalPageCount: viewportState.pageCount,
          viewportMode: viewportState.kind.name,
        ),
        positionSnapshot: ReaderPositionSnapshot(
          viewportMode: viewportState.kind.name,
          pageIndex: viewportState.pageIndex,
          pageCount: viewportState.pageCount,
          scrollOffset: viewportState.scrollOffset,
          maxScrollExtent: viewportState.maxScrollExtent,
          audioPositionMs:
              _currentContentMode == ReaderContentMode.audio
                  ? _audioPlaybackPosition.inMilliseconds
                  : null,
          audioDurationMs:
              _currentContentMode == ReaderContentMode.audio
                  ? _audioPlaybackDuration.inMilliseconds
                  : null,
          audioSpeed:
              _currentContentMode == ReaderContentMode.audio
                  ? _audioPlaybackSpeed
                  : null,
        ),
      ),
    );
  }

  Future<void> _turnPagedTextPage({required int direction}) async {
    if (!_isTextPagedViewport) {
      return;
    }

    _clearSelectionState();
    _clearSystemSelection();

    if (_pagedPaginationState.isPaginating) {
      return;
    }

    final pageCount = _currentPagedPageCount;
    if (pageCount <= 0) {
      return;
    }

    final safeDirection = direction >= 0 ? 1 : -1;
    final action = _pagedTransitionLogic.planTurn(
      direction: safeDirection,
      currentPageIndex: _currentPageIndex,
      pageCount: pageCount,
      settings: _settings,
      isAnimating: _isPagedTransitionAnimating,
      renderer: _pagedTextRenderer,
      document: _document,
    );
    switch (action.type) {
      case PagedTransitionActionType.ignored:
        return;
      case PagedTransitionActionType.crossChapter:
        _markFirstPageTurnRequested();
        await _playCrossChapterPagedTurnAnimation(action);
        final turned = await _jumpToAdjacentReadableChapter(
          forward: safeDirection >= 0,
        );
        if (turned) {
          _recordFirstPageTurnCompleted(mode: 'cross_chapter');
        }
        return;
      case PagedTransitionActionType.curl:
        _markFirstPageTurnRequested();
        await _autoTurnCurlPage(safeDirection);
        return;
      case PagedTransitionActionType.immediate:
        _markFirstPageTurnRequested();
        _snapToPagedTextPage(action.targetPageIndex);
        _recordFirstPageTurnCompleted(mode: 'immediate');
        return;
      case PagedTransitionActionType.animated:
        _markFirstPageTurnRequested();
        _startPagedPageTransition(action);
        return;
    }
  }

  void _startPagedPageTransition(PagedTransitionAction action) {
    if (_isPagedTransitionAnimating) {
      return;
    }
    final transitionState = action.transitionState;
    final motion = action.motion;
    if (transitionState == null || motion == null) {
      return;
    }
    _markReaderInteractionBusy(_ReaderInteractionState.animating);
    _pagedTransitionController.duration = motion.duration;
    setState(() {
      _pagedTransition = transitionState;
    });
    _pagedTransitionController.value = 0;
    _pagedTransitionController.forward();
  }

  Future<void> _playCrossChapterPagedTurnAnimation(
    PagedTransitionAction action,
  ) async {
    final transitionState = action.transitionState;
    final motion = action.motion;
    if (transitionState == null ||
        motion == null ||
        motion.duration <= Duration.zero) {
      return;
    }
    if (transitionState.style == ReaderPageAnimationStyle.curl) {
      await _playCrossChapterCurlTurnAnimation(transitionState, motion);
      return;
    }
    if (_isPagedTransitionAnimating) {
      return;
    }
    _markReaderInteractionBusy(_ReaderInteractionState.animating);
    _pagedTransitionController.duration = motion.duration;
    setState(() {
      _pagedTransition = transitionState;
    });
    _pagedTransitionController.value = 0;
    try {
      await _pagedTransitionController.forward().orCancel;
    } on TickerCanceled {
      // Reader may leave the page while the boundary animation is running.
    }
  }

  Future<void> _playCrossChapterCurlTurnAnimation(
    PagedTransitionState transitionState,
    PagedAnimationMotionSpec motion,
  ) async {
    if (_isCurlAutoTurning) {
      return;
    }
    _markReaderInteractionBusy(_ReaderInteractionState.animating);
    _curlAutoTurnController.duration = motion.duration;
    setState(() {
      _curlTransition = _curlTransition.copyWith(
        direction: transitionState.direction,
        fromIndex: transitionState.fromIndex,
        toIndex: transitionState.toIndex,
        commitOnAnimationEnd: true,
        isPreview: false,
        previewProgress: 0,
        isAnimating: true,
        isCrossChapter: true,
      );
    });
    _curlAutoTurnController.value = 0;
    try {
      await _curlAutoTurnController.forward().orCancel;
    } on TickerCanceled {
      // Reader may leave the page while the boundary animation is running.
    }
  }

  void _onPagedTransitionStatus(AnimationStatus status) {
    final commit = _pagedTransitionLogic.completeTransition(
      status: status,
      state: _pagedTransition,
    );
    if (commit == null) {
      return;
    }

    setState(() {
      _currentPageIndex = commit.nextPageIndex;
      _pagedTransition = commit.nextState;
    });
    _syncActiveReadingRecordSessionProgress();
    _scheduleProgressSave();
    _recordFirstPageTurnCompleted(mode: 'animated');
    _scheduleReaderInteractionSettle();
  }
}

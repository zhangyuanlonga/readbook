// ignore_for_file: invalid_use_of_protected_member

part of 'reader_page.dart';

extension _ReaderPageRuntimeExtension on _ReaderPageState {
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

  GlobalKey _continuousTextChapterKey(_ContinuousTextChapter chapter) {
    final identity =
        chapter.chapterUrl.trim().isNotEmpty
            ? chapter.chapterUrl.trim()
            : '${chapter.chapterIndex}:${chapter.chapterId}';
    return _continuousTextChapterKeys.putIfAbsent(identity, () => GlobalKey());
  }

  void _replaceContinuousTextFlowWithCurrentChapter({
    required Chapter chapter,
    required int chapterIndex,
    required _ChapterLoadSnapshot snapshot,
  }) {
    _replaceContinuousTextFlowWithCurrentChapterFlow(
      chapter: chapter,
      chapterIndex: chapterIndex,
      snapshot: snapshot,
    );
  }

  Future<_ContinuousTextChapter?> _loadContinuousTextChapter(int chapterIndex) {
    return _loadContinuousTextChapterFlow(chapterIndex);
  }

  Future<void> _loadAdjacentContinuousTextChapter({
    required bool forward,
  }) async {
    if (_isScrollEdgeAdvancingChapter ||
        !_shouldUseContinuousTextFlow ||
        _continuousTextChapters.isEmpty) {
      return;
    }

    final targetIndex = _contentLoadingPresenter
        .resolveAdjacentContinuousChapterIndex(
          chapters: _chapters,
          loadedChapterIndices: _continuousTextChapters
              .map((item) => item.chapterIndex)
              .toList(growable: false),
          forward: forward,
        );
    if (targetIndex == null) {
      return;
    }

    _isScrollEdgeAdvancingChapter = true;
    try {
      final chapter = await _loadContinuousTextChapter(targetIndex);
      if (!mounted || chapter == null) {
        return;
      }
      if (_continuousTextChapters.any(
        (item) => item.chapterIndex == chapter.chapterIndex,
      )) {
        return;
      }
      setState(() {
        _continuousTextChapters = List<_ContinuousTextChapter>.unmodifiable(
          forward
              ? <_ContinuousTextChapter>[..._continuousTextChapters, chapter]
              : <_ContinuousTextChapter>[chapter, ..._continuousTextChapters],
        );
      });
    } finally {
      _isScrollEdgeAdvancingChapter = false;
    }
  }

  bool _isContinuousTextChapterActive(_ContinuousTextChapter chapter) {
    return _isContinuousTextChapterActiveFlow(chapter);
  }

  _ContinuousTextChapter? _findCurrentContinuousTextChapter() {
    return _findCurrentContinuousTextChapterFlow();
  }

  _ContinuousTextChapter? _resolveActiveContinuousTextChapter() {
    return _resolveActiveContinuousTextChapterFlow();
  }

  double _continuousTextChapterScrollRatioFor(_ContinuousTextChapter chapter) {
    return _continuousTextChapterScrollRatioForFlow(chapter);
  }

  void _activateContinuousTextChapter(_ContinuousTextChapter chapter) {
    _activateContinuousTextChapterFlow(chapter);
  }

  void _syncActiveContinuousTextChapterFromScroll() {
    if (!_shouldUseContinuousTextFlow || _continuousTextChapters.length <= 1) {
      return;
    }

    final resolved = _resolveActiveContinuousTextChapter();
    if (resolved == null || _isContinuousTextChapterActive(resolved)) {
      return;
    }
    _activateContinuousTextChapter(resolved);
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
        case _ReaderViewportKind.textPaged:
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
        case _ReaderViewportKind.mangaPaged:
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
        case _ReaderViewportKind.textScroll:
        case _ReaderViewportKind.mangaContinuous:
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
    final hasScrollClients = _scrollController.hasClients;
    final position = hasScrollClients ? _scrollController.position : null;
    return _autoReadCoordinator.canRunNow(
      isAutoReadSessionEnabled: _isAutoReadSessionEnabled,
      isMangaChapter: _isMangaChapter,
      isPagedTextReaderEnabled: _isPagedTextReaderEnabled(),
      showOverlayControls: _showOverlayControls,
      isBootstrapping: _isBootstrapping,
      isLoadingContent: _isLoadingContent,
      hasError: _errorText != null,
      hasTextContent: _content.trim().isNotEmpty,
      hasScrollClients: hasScrollClients,
      maxScrollExtent: position?.maxScrollExtent ?? 0,
      scrollOffset: position?.pixels ?? 0,
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
        unawaited(_tryAutoReadAdvanceChapter());
      }
    });
  }

  void _startAutoReadIfNeeded() {
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
      unawaited(_tryAutoReadAdvanceChapter());
    }
  }

  Future<void> _tryAutoReadAdvanceChapter() async {
    if (!_autoReadCoordinator.shouldTryAdvanceChapter(
      isAutoReadSessionEnabled: _isAutoReadSessionEnabled,
      isAutoReadAdvancingChapter: _isAutoReadAdvancingChapter,
      isMangaChapter: _isMangaChapter,
      isPagedTextReaderEnabled: _isPagedTextReaderEnabled(),
      showOverlayControls: _showOverlayControls,
      isBootstrapping: _isBootstrapping,
      isLoadingContent: _isLoadingContent,
      hasError: _errorText != null,
      isAtChapterEnd: _isAutoReadAtChapterEnd(),
    )) {
      return;
    }

    _isAutoReadAdvancingChapter = true;
    try {
      await _jumpToAdjacentReadableChapter(
        forward: true,
        showBoundaryHint: false,
      );
    } finally {
      _isAutoReadAdvancingChapter = false;
    }
  }

  void _stopAutoRead() {
    _autoReadTaskToken += 1;
    _isAutoReadRunning = false;
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

  void _onScrollChanged() {
    if (!_isTextScrollViewport) {
      return;
    }
    if (_isBootstrapping || _isLoadingContent || _errorText != null) {
      return;
    }
    if ((_content.trim().isEmpty && _chapterImageUrls.isEmpty) ||
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
  }

  void _scheduleProgressSave() {
    _progressDebounceTimer?.cancel();
    _progressDebounceTimer = Timer(const Duration(milliseconds: 420), () {
      unawaited(_saveProgress());
    });
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
    _readingRecordAutoCommitTimer = Timer(
      _ReaderPageState._kReadingRecordAutoCommitInterval,
      () {
        final restartRatio = _currentScrollRatio();
        _commitReadingRecordSession();
        _maybeStartReadingRecordSession(initialRatio: restartRatio);
      },
    );
  }

  void _commitReadingRecordSession() {
    _readingRecordAutoCommitTimer?.cancel();
    _readingRecordAutoCommitTimer = null;
    final session = _activeReadingRecordSession;
    _activeReadingRecordSession = null;
    final commitInput = _readingRecordCoordinator.buildCommitInput(
      readingRecordEnabled: _readingRecordEnabled,
      session: session,
      endAt: DateTime.now(),
      endRatio: _currentScrollRatio(),
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
      case _ReaderViewportKind.textPaged:
        return _activeTextRenderer.captureProgress(_currentTextRenderMetrics());
      case _ReaderViewportKind.mangaPaged:
        final total = _chapterImageUrls.length;
        if (total <= 1) {
          return 0;
        }
        return (_mangaPageIndex / (total - 1)).clamp(0.0, 1.0);
      case _ReaderViewportKind.textScroll:
      case _ReaderViewportKind.mangaContinuous:
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

  void _clearDelayedLoadingUi() {
    _chapterLoadingIndicatorTimer?.cancel();
    _chapterLoadingIndicatorTimer = null;
    _blockingLoadingCardTimer?.cancel();
    _blockingLoadingCardTimer = null;
    _showChapterLoadingIndicator = false;
    _showBlockingLoadingCard = false;
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
        logicalPosition: logicalPosition,
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

    final pages = _pagedPages;
    if (pages.isEmpty) {
      return;
    }

    final safeDirection = direction >= 0 ? 1 : -1;
    final action = _pagedTransitionLogic.planTurn(
      direction: safeDirection,
      currentPageIndex: _currentPageIndex,
      pageCount: pages.length,
      settings: _settings,
      isAnimating: _isPagedTransitionAnimating,
      renderer: _pagedTextRenderer,
    );
    switch (action.type) {
      case PagedTransitionActionType.ignored:
        return;
      case PagedTransitionActionType.crossChapter:
        await _jumpToAdjacentReadableChapter(forward: safeDirection >= 0);
        return;
      case PagedTransitionActionType.curl:
        await _autoTurnCurlPage(safeDirection);
        return;
      case PagedTransitionActionType.immediate:
        setState(() {
          _currentPageIndex = action.targetPageIndex;
        });
        _syncActiveReadingRecordSessionProgress();
        _scheduleProgressSave();
        return;
      case PagedTransitionActionType.animated:
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
    _pagedTransitionController.duration = motion.duration;
    setState(() {
      _pagedTransition = transitionState;
    });
    _pagedTransitionController.value = 0;
    _pagedTransitionController.forward();
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
  }
}

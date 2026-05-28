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

  double _continuousTextChapterDocumentRatioFor(
    _ContinuousTextChapter chapter,
  ) {
    return _continuousTextChapterDocumentRatioForFlow(chapter);
  }

  _ContinuousTextChapter? _resolveActiveContinuousTextChapterForRuntime() {
    return _resolveActiveContinuousTextChapterFlow();
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
        case ReaderModeViewportKind.audio:
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
      textSelectionActive: _isTextSelectionActive,
      isBootstrapping: _isBootstrapping,
      isLoadingContent: _isLoadingContent || _isRestoringContinuousTextAnchor,
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
      textSelectionActive: _isTextSelectionActive,
      isBootstrapping: _isBootstrapping,
      isLoadingContent: _isLoadingContent,
      hasError: _errorText != null,
      hasTextContent: _content.trim().isNotEmpty,
      isPaginating: _pagedPaginationState.isPaginating,
      isAnimating: _isPagedTransitionAnimating || _isCurlAutoTurning,
      pageCount: _currentPagedPageCount,
    );
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
    if (_settings.autoReadMode == ReaderAutoReadMode.scroll &&
        _isTextScrollViewport &&
        _isCurrentContinuousTextChapterVisibleEnd()) {
      return true;
    }
    final hasScrollClients = _scrollController.hasClients;
    final position = hasScrollClients ? _scrollController.position : null;
    return _autoReadCoordinator.isAtChapterEnd(
      hasScrollClients: hasScrollClients,
      maxScrollExtent: position?.maxScrollExtent ?? 0,
      scrollOffset: position?.pixels ?? 0,
    );
  }

  bool _isCurrentContinuousTextChapterVisibleEnd() {
    if (!_shouldUseContinuousTextFlow || !_scrollController.hasClients) {
      return false;
    }
    final currentChapter = _findCurrentContinuousTextChapter();
    if (currentChapter == null) {
      return false;
    }
    final layout = _measureContinuousTextChapterLayoutFlow(currentChapter);
    if (layout == null) {
      return false;
    }
    final position = _scrollController.position;
    final target = _resolveAutoReadScrollTargetOffset(position);
    if (position.pixels < target - 1.5) {
      return false;
    }
    final viewportEnd = position.pixels + position.viewportDimension;
    return viewportEnd >= layout.endOffset - 2.0;
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

  bool get _isProgrammaticAutoReadScrollActive =>
      _isAutoReadSessionEnabled &&
      _autoReadSessionState == ReaderAutoReadSessionState.running &&
      _settings.autoReadMode == ReaderAutoReadMode.scroll &&
      _isAutoReadRunning;

  Future<void> _runAutoReadLoop(int token) async {
    if (!_canRunAutoReadNow()) {
      _finishAutoReadScrollRun(token, reason: 'not_ready');
      return;
    }

    _syncAutoReadVisibleContinuousTextChapter();
    final position = _scrollController.position;
    final startOffset = position.pixels;
    final target = _resolveAutoReadScrollTargetOffset(position);
    final remaining = target - startOffset;
    if (remaining <= 0.5) {
      final atChapterEnd = _isAutoReadAtChapterEnd();
      _finishAutoReadScrollRun(
        token,
        reason: atChapterEnd ? 'already_at_end' : 'no_scroll_room',
        handleBoundary: atChapterEnd,
      );
      return;
    }

    _beginAutoReadDisplayProgressRun(
      startOffset: startOffset,
      targetOffset: target,
    );
    final duration = _resolveAutoReadScrollDuration(remaining);
    _logAutoReadScrollTrace(
      step: 'start',
      token: token,
      startOffset: startOffset,
      targetOffset: target,
      duration: duration,
    );

    try {
      await _scrollController.animateTo(
        target,
        duration: duration,
        curve: Curves.linear,
      );
    } catch (error) {
      _logAutoReadScrollTrace(
        step: 'error',
        token: token,
        startOffset: startOffset,
        targetOffset: target,
        duration: duration,
        error: error,
      );
      _finishAutoReadScrollRun(token, reason: 'error');
      return;
    }

    final stillCurrent = mounted && token == _autoReadTaskToken;
    final reachedTarget =
        _scrollController.hasClients &&
        _scrollController.position.pixels >= target - 1.5;
    _logAutoReadScrollTrace(
      step: stillCurrent && reachedTarget ? 'complete' : 'interrupted',
      token: token,
      startOffset: startOffset,
      targetOffset: target,
      duration: duration,
      currentOffset:
          _scrollController.hasClients
              ? _scrollController.position.pixels
              : null,
      reachedEnd: reachedTarget,
    );
    _finishAutoReadScrollRun(
      token,
      reason: reachedTarget ? 'complete' : 'interrupted',
      handleBoundary: stillCurrent && reachedTarget,
    );
  }

  Duration _resolveAutoReadScrollDuration(double distance) {
    final speed =
        _settings.autoReadSpeed
            .clamp(
              ReaderSettings.minAutoReadSpeed,
              ReaderSettings.maxAutoReadSpeed,
            )
            .toDouble();
    final milliseconds = (distance / speed * 1000).round();
    return Duration(
      milliseconds: max(
        _ReaderPageState._kAutoReadMinimumScrollDuration.inMilliseconds,
        milliseconds,
      ),
    );
  }

  double _resolveAutoReadScrollTargetOffset(ScrollPosition position) {
    if (_settings.autoReadMode != ReaderAutoReadMode.scroll ||
        !_shouldUseContinuousTextFlow) {
      return position.maxScrollExtent;
    }
    final currentChapter = _findCurrentContinuousTextChapter();
    if (currentChapter == null) {
      return position.maxScrollExtent;
    }
    final layout = _measureContinuousTextChapterLayoutFlow(currentChapter);
    if (layout == null) {
      return position.maxScrollExtent;
    }
    final chapterEndOffset = layout.endOffset - position.viewportDimension;
    return chapterEndOffset.clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
  }

  void _finishAutoReadScrollRun(
    int token, {
    required String reason,
    bool handleBoundary = false,
  }) {
    if (token != _autoReadTaskToken) {
      return;
    }
    _isAutoReadRunning = false;
    if (reason != 'complete' || handleBoundary) {
      _clearAutoReadDisplayProgressRun(clearDisplayRatio: handleBoundary);
    }
    _logAutoReadScrollTrace(step: 'finish', token: token, reason: reason);
    if (handleBoundary) {
      unawaited(_handleAutoReadChapterBoundary());
    }
  }

  void _logAutoReadScrollTrace({
    required String step,
    required int token,
    double? startOffset,
    double? targetOffset,
    double? currentOffset,
    Duration? duration,
    bool? reachedEnd,
    String? reason,
    Object? error,
  }) {
    _logger.info(
      'Reader auto read scroll trace',
      context: <String, Object?>{
        'chain': 'reader_auto_read',
        'step': step,
        'token': token,
        'chapterId': _chapterId,
        'mode': _settings.autoReadMode.name,
        'pageTurnMode': _settings.pageTurnMode.name,
        'speedLevel': _settings.autoReadSpeedLevel,
        'speed': _settings.autoReadSpeed.round(),
        'startOffset': startOffset?.toStringAsFixed(1),
        'targetOffset': targetOffset?.toStringAsFixed(1),
        'currentOffset': currentOffset?.toStringAsFixed(1),
        'durationMs': duration?.inMilliseconds,
        'reachedEnd': reachedEnd,
        'reason': reason,
        'error': error?.toString(),
      },
    );
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
        _scheduleAutoReadBoundaryContinue();
        return;
      }
      await _handleAutoReadBookFinished();
    } finally {
      _isAutoReadHandlingBoundary = false;
    }
  }

  void _scheduleAutoReadBoundaryContinue() {
    _autoReadResumeTimer?.cancel();
    _lastAutoReadVisibleChapterIndex = null;
    _lastAutoReadProgressUiRefreshAt = null;
    _clearAutoReadDisplayProgressRun(clearDisplayRatio: true);
    _autoReadTapGuardUntil = DateTime.now().add(
      _ReaderPageState._kAutoReadBoundaryResumeDelay,
    );
    _autoReadResumeTimer = Timer(
      _ReaderPageState._kAutoReadBoundaryResumeDelay,
      () {
        if (!mounted ||
            !_isAutoReadSessionEnabled ||
            _autoReadSessionState != ReaderAutoReadSessionState.running) {
          return;
        }
        _lastAutoReadProgressUiRefreshAt = null;
        _clearAutoReadDisplayProgressRun(clearDisplayRatio: true);
        _reconcileAutoRead(restart: true);
      },
    );
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
      _stopAutoReadSession();
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
    _stopAutoReadSession();
  }

  void _stopAutoRead({bool preserveDisplayProgress = false}) {
    if (preserveDisplayProgress) {
      _updateAutoReadDisplayProgressRatio();
    }
    final preservedDisplayProgress =
        preserveDisplayProgress ? _autoReadDisplayProgressRatio : null;
    _autoReadTaskToken += 1;
    _isAutoReadRunning = false;
    _clearAutoReadDisplayProgressRun(
      clearDisplayRatio: !preserveDisplayProgress,
    );
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
    if (preserveDisplayProgress) {
      _autoReadDisplayProgressRatio = preservedDisplayProgress;
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
    _stopAutoRead(preserveDisplayProgress: true);
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

    if (_isProgrammaticAutoReadScrollActive) {
      _syncAutoReadVisibleContinuousTextChapter();
      _refreshAutoReadProgressUiIfNeeded();
      _logAutoReadContinuousSyncSkipped();
    } else {
      _lastAutoReadVisibleChapterIndex = null;
      _lastAutoReadProgressUiRefreshAt = null;
      _clearAutoReadDisplayProgressRun(clearDisplayRatio: true);
      _syncActiveContinuousTextChapterFromScroll();
      _maybePrefetchContinuousTextNeighbors();
    }
    _syncActiveReadingRecordSessionProgress();
    _scheduleProgressSave();
  }

  void _syncAutoReadVisibleContinuousTextChapter() {
    final resolved = _resolveActiveContinuousTextChapterForRuntime();
    if (resolved == null || resolved.chapterIndex == _currentIndex) {
      return;
    }
    final currentIndex = _currentIndex;
    if (currentIndex != null && resolved.chapterIndex < currentIndex) {
      _logAutoReadScrollTrace(
        step: 'backward_visible_chapter_ignored',
        token: _autoReadTaskToken,
        reason: 'resolved=${resolved.chapterIndex}, current=$currentIndex',
      );
      return;
    }
    if (_lastAutoReadVisibleChapterIndex == resolved.chapterIndex) {
      return;
    }
    _lastAutoReadVisibleChapterIndex = resolved.chapterIndex;
    _updateReaderState(() {
      _currentIndex = resolved.chapterIndex;
      _chapterId = resolved.chapterId;
      _chapterUrl = resolved.chapterUrl;
      _chapterTitle =
          resolved.displayTitle.trim().isNotEmpty
              ? resolved.displayTitle
              : resolved.chapterTitle;
      _isCurrentChapterCached = resolved.isCached;
    });
  }

  void _refreshAutoReadProgressUiIfNeeded() {
    if (!mounted) {
      return;
    }
    _updateAutoReadDisplayProgressRatio();
    final now = DateTime.now();
    final last = _lastAutoReadProgressUiRefreshAt;
    if (last != null && now.difference(last).inMilliseconds < 200) {
      return;
    }
    _lastAutoReadProgressUiRefreshAt = now;
    setState(() {});
  }

  void _beginAutoReadDisplayProgressRun({
    required double startOffset,
    required double targetOffset,
  }) {
    _autoReadRunStartOffset = startOffset;
    _autoReadRunTargetOffset = targetOffset;
    _autoReadRunStartProgressRatio =
        _autoReadDisplayProgressRatio ?? _currentScrollRatio();
    _autoReadDisplayProgressRatio = _autoReadRunStartProgressRatio;
  }

  void _updateAutoReadDisplayProgressRatio() {
    if (!_scrollController.hasClients) {
      return;
    }
    final startOffset = _autoReadRunStartOffset;
    final targetOffset = _autoReadRunTargetOffset;
    final startProgress = _autoReadRunStartProgressRatio;
    if (startOffset == null || targetOffset == null || startProgress == null) {
      _autoReadDisplayProgressRatio = _currentScrollRatio();
      return;
    }
    final distance = targetOffset - startOffset;
    if (distance <= 0) {
      _autoReadDisplayProgressRatio = _currentScrollRatio();
      return;
    }

    final scrolled = ((_scrollController.position.pixels - startOffset) /
            distance)
        .clamp(0.0, 1.0);
    _autoReadDisplayProgressRatio =
        (startProgress + (1 - startProgress) * scrolled).clamp(0.0, 1.0);
  }

  void _clearAutoReadDisplayProgressRun({bool clearDisplayRatio = false}) {
    _autoReadRunStartOffset = null;
    _autoReadRunTargetOffset = null;
    _autoReadRunStartProgressRatio = null;
    _lastAutoReadProgressUiRefreshAt = null;
    if (clearDisplayRatio) {
      _autoReadDisplayProgressRatio = null;
    }
  }

  void _logAutoReadContinuousSyncSkipped() {
    if (_lastAutoReadContinuousSyncSkipLogToken == _autoReadTaskToken) {
      return;
    }
    _lastAutoReadContinuousSyncSkipLogToken = _autoReadTaskToken;
    final position =
        _scrollController.hasClients ? _scrollController.position : null;
    _logger.info(
      'Reader auto read scroll trace',
      context: <String, Object?>{
        'chain': 'reader_auto_read',
        'step': 'continuous_sync_skipped',
        'token': _autoReadTaskToken,
        'chapterId': _chapterId,
        'mode': _settings.autoReadMode.name,
        'pageTurnMode': _settings.pageTurnMode.name,
        'scrollOffset': position?.pixels.toStringAsFixed(1),
        'maxScrollExtent': position?.maxScrollExtent.toStringAsFixed(1),
        'continuousChapterCount': _continuousTextChapters.length,
      },
    );
  }

  void _maybePrefetchContinuousTextNeighbors() {
    if (!_shouldUseContinuousTextFlow ||
        !_scrollController.hasClients ||
        _continuousTextChapters.isEmpty ||
        _isScrollEdgeAdvancingChapter ||
        _isAutoReadAdvancingChapter ||
        _isProgrammaticAutoReadScrollActive) {
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
      case ReaderModeViewportKind.audio:
        final totalMs = _audioPlaybackDuration.inMilliseconds;
        if (totalMs <= 0) {
          return 0;
        }
        return (_audioPlaybackPosition.inMilliseconds / totalMs).clamp(
          0.0,
          1.0,
        );
    }
  }

  void _handleReaderAudioControllerChanged() {
    final playbackState = _readerAudioController.state.playbackState;
    _audioPlaybackPosition = playbackState.currentPosition;
    _audioPlaybackDuration = playbackState.totalDuration ?? Duration.zero;
    _audioPlaybackSpeed = playbackState.speed;
    if (_currentContentMode == ReaderContentMode.audio) {
      _scheduleProgressSave();
    }
  }

  double _currentLogicalPositionRatio() {
    if (!_shouldUseContinuousTextFlow) {
      return _currentScrollRatio();
    }
    final currentChapter = _findCurrentContinuousTextChapter();
    if (currentChapter == null) {
      return _currentScrollRatio();
    }
    return _continuousTextChapterDocumentRatioFor(currentChapter);
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
    final positionRatio = _currentLogicalPositionRatio();

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
        chapterPositionRatio: positionRatio,
        logicalPosition: logicalPosition?.copyWith(
          chapterPositionRatio: positionRatio,
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
    if (_usesPaperCurlAnimation) {
      _markFirstPageTurnRequested();
      await _turnPaperCurlPage(safeDirection, pageCount);
      return;
    }

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
        final style =
            action.transitionState?.style ??
            _pagedTextRenderer.resolveAnimationStyle(
              _settings,
              document: _document,
            );
        await _turnCrossChapterWithSnapshot(
          forward: safeDirection >= 0,
          style: style,
          completionMode: 'cross_chapter',
        );
        return;
      case PagedTransitionActionType.curl:
        _markFirstPageTurnRequested();
        await _autoTurnCurlPage(safeDirection);
        return;
      case PagedTransitionActionType.paperCurl:
        _markFirstPageTurnRequested();
        await _turnPaperCurlPage(safeDirection, pageCount);
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

  Future<bool> _turnCrossChapterWithSnapshot({
    required bool forward,
    required ReaderPageAnimationStyle style,
    required String completionMode,
  }) async {
    if (_crossChapterSnapshotTransition.isActive) {
      return false;
    }

    final sessionState = _currentTextSessionState();
    final decision = _chapterFlow.resolveAdjacentChapter(
      chapters: _chapters,
      currentChapterIndex: sessionState?.currentChapterIndex ?? _currentIndex,
      forward: forward,
      initialScrollRatio: forward ? 0 : 1,
    );
    if (decision.type == ReaderAdjacentChapterDecisionType.noCurrent) {
      return false;
    }
    if (decision.type == ReaderAdjacentChapterDecisionType.boundary) {
      _showChapterBoundaryHint(isFirst: decision.isFirstBoundary);
      return false;
    }

    final direction = forward ? 1 : -1;
    final fromImage = await _captureReaderContentSnapshot();
    if (fromImage == null) {
      await _jumpToAdjacentReadableChapter(forward: forward);
      return true;
    }

    final generation = ++_crossChapterSnapshotGeneration;
    _markReaderInteractionBusy(_ReaderInteractionState.animating);
    _startCrossChapterSnapshotTransition(
      generation: generation,
      fromImage: fromImage,
      style: style,
      direction: direction,
      completionMode: completionMode,
    );

    final targetChapterIndex = decision.targetChapterIndex!;
    await _jumpTo(
      targetChapterIndex,
      initialScrollRatio: decision.initialScrollRatio,
    );
    if (!mounted ||
        generation != _crossChapterSnapshotGeneration ||
        _currentIndex != targetChapterIndex) {
      _clearCrossChapterSnapshotTransition();
      _scheduleReaderInteractionSettle();
      return false;
    }

    await _waitForCrossChapterSnapshotTarget(
      generation: generation,
      targetChapterIndex: targetChapterIndex,
    );
    if (!mounted || generation != _crossChapterSnapshotGeneration) {
      _clearCrossChapterSnapshotTransition();
      _scheduleReaderInteractionSettle();
      return false;
    }

    final toImage = await _captureReaderContentSnapshot();
    if (toImage == null) {
      _clearCrossChapterSnapshotTransition();
      _recordFirstPageTurnCompleted(mode: completionMode);
      _scheduleReaderInteractionSettle();
      return true;
    }

    _attachCrossChapterSnapshotTarget(generation: generation, toImage: toImage);
    if (style == ReaderPageAnimationStyle.paperCurl) {
      return true;
    }

    final motion = _pagedTextRenderer.motionSpecForStyle(style);
    _crossChapterSnapshotController.duration = motion.duration;
    _crossChapterSnapshotController.value = 0;
    if (motion.duration <= Duration.zero) {
      _completeCrossChapterSnapshotAnimation();
      return true;
    }
    try {
      await _crossChapterSnapshotController.forward().orCancel;
    } on TickerCanceled {
      if (mounted) {
        _clearCrossChapterSnapshotTransition();
        _scheduleReaderInteractionSettle();
      }
    }
    return true;
  }

  Future<ui.Image?> _captureReaderContentSnapshot() async {
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) {
      return null;
    }
    final context = _readerContentSnapshotKey.currentContext;
    if (context == null || !context.mounted) {
      return null;
    }
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) {
      return null;
    }
    if (renderObject.debugNeedsPaint) {
      await WidgetsBinding.instance.endOfFrame;
    }
    if (!mounted || !context.mounted) {
      return null;
    }
    final pixelRatio = MediaQuery.devicePixelRatioOf(context).clamp(1.0, 2.0);
    return renderObject.toImage(pixelRatio: pixelRatio);
  }

  Future<void> _waitForCrossChapterSnapshotTarget({
    required int generation,
    required int targetChapterIndex,
  }) async {
    const maxFrames = 60;
    for (var frame = 0; frame < maxFrames; frame++) {
      if (!mounted ||
          generation != _crossChapterSnapshotGeneration ||
          _currentIndex != targetChapterIndex) {
        return;
      }
      final hasPagedContent = _currentPagedPageCount > 0;
      if (!_isLoadingContent &&
          !_pagedPaginationState.isPaginating &&
          hasPagedContent) {
        await WidgetsBinding.instance.endOfFrame;
        return;
      }
      await WidgetsBinding.instance.endOfFrame;
    }
  }

  void _startCrossChapterSnapshotTransition({
    required int generation,
    required ui.Image fromImage,
    required ReaderPageAnimationStyle style,
    required int direction,
    required String completionMode,
  }) {
    _crossChapterSnapshotController.stop();
    _crossChapterSnapshotController.value = 0;
    _replaceCrossChapterSnapshotTransition(
      _CrossChapterSnapshotTransitionState(
        fromImage: fromImage,
        style: style,
        direction: direction,
        generation: generation,
        completionMode: completionMode,
      ),
    );
  }

  void _attachCrossChapterSnapshotTarget({
    required int generation,
    required ui.Image toImage,
  }) {
    final current = _crossChapterSnapshotTransition;
    if (!current.isActive || current.generation != generation) {
      toImage.dispose();
      return;
    }
    _replaceCrossChapterSnapshotTransition(current.copyWith(toImage: toImage));
  }

  void _replaceCrossChapterSnapshotTransition(
    _CrossChapterSnapshotTransitionState next,
  ) {
    final previous = _crossChapterSnapshotTransition;
    final previousFrom = previous.fromImage;
    final previousTo = previous.toImage;
    final nextFrom = next.fromImage;
    final nextTo = next.toImage;
    setState(() {
      _crossChapterSnapshotTransition = next;
    });
    if (previousFrom != null && previousFrom != nextFrom) {
      previousFrom.dispose();
    }
    if (previousTo != null && previousTo != nextTo) {
      previousTo.dispose();
    }
  }

  void _clearCrossChapterSnapshotTransition({bool setStateIfNeeded = false}) {
    _crossChapterSnapshotController.stop();
    final previous = _crossChapterSnapshotTransition;
    _crossChapterSnapshotTransition =
        const _CrossChapterSnapshotTransitionState();
    previous.fromImage?.dispose();
    previous.toImage?.dispose();
    if (mounted && setStateIfNeeded) {
      setState(() {});
    }
  }

  void _completeCrossChapterSnapshotAnimation() {
    if (!_crossChapterSnapshotTransition.hasTarget) {
      return;
    }
    final completionMode = _crossChapterSnapshotTransition.completionMode;
    _clearCrossChapterSnapshotTransition(setStateIfNeeded: true);
    _recordFirstPageTurnCompleted(mode: completionMode);
    _syncActiveReadingRecordSessionProgress();
    _scheduleProgressSave();
    _scheduleReaderInteractionSettle();
  }

  void _onCrossChapterSnapshotStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) {
      return;
    }
    _completeCrossChapterSnapshotAnimation();
  }

  Future<void> _turnPaperCurlPage(int direction, int pageCount) async {
    if (_paperCurlViewKey.currentState?.isAnimating ?? false) {
      return;
    }
    final currentIndex = _currentPageIndex.clamp(0, pageCount - 1);
    if (direction < 0 && currentIndex <= 0) {
      await _turnCrossChapterWithSnapshot(
        forward: false,
        style: ReaderPageAnimationStyle.paperCurl,
        completionMode: 'paper_curl_cross_chapter',
      );
      return;
    }
    if (direction > 0 && currentIndex >= pageCount - 1) {
      await _turnCrossChapterWithSnapshot(
        forward: true,
        style: ReaderPageAnimationStyle.paperCurl,
        completionMode: 'paper_curl_cross_chapter',
      );
      return;
    }

    final paperCurlState = _paperCurlViewKey.currentState;
    if (paperCurlState == null) {
      _scheduleReaderInteractionSettle();
      return;
    }
    final turned = paperCurlState.turnPage(direction);
    if (!turned) {
      _scheduleReaderInteractionSettle();
    }
  }

  void _commitPaperCurlPage(int pageIndex) {
    if (!mounted) {
      return;
    }
    final pageCount = _currentPagedPageCount;
    if (pageCount <= 0) {
      return;
    }
    final safeIndex = pageIndex.clamp(0, _safePageUpperBound(pageCount));
    _updateReaderState(() {
      _currentPageIndex = safeIndex;
      _pagedPaginationState = _pagedPaginationState.copyWith(
        pendingRestoreRatio: safeIndex / max(1, pageCount - 1),
      );
    });
    _syncActiveReadingRecordSessionProgress();
    _scheduleProgressSave();
    _scheduleReaderInteractionSettle();
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

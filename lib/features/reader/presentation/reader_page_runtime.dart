// ignore_for_file: invalid_use_of_protected_member

part of 'reader_page.dart';

extension _ReaderPageRuntimeExtension on _ReaderPageState {
  void _markFirstPageTurnRequested() {
    _pageTurnRuntimeController.markFirstPageTurnRequested();
  }

  void _recordFirstPageTurnCompleted({required String mode}) {
    final stopwatch = _pageTurnRuntimeController.completeFirstPageTurn();
    if (stopwatch == null) {
      return;
    }
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

  GlobalKey _continuousTextChapterKey(ReaderPageContinuousTextChapter chapter) {
    final identity =
        chapter.chapterUrl.trim().isNotEmpty
            ? chapter.chapterUrl.trim()
            : '${chapter.chapterIndex}:${chapter.chapterId}';
    return _continuousTextChapterKeys.putIfAbsent(identity, () => GlobalKey());
  }

  Future<ReaderPageContinuousTextChapter?> _loadAdjacentContinuousTextChapter({
    required bool forward,
  }) {
    return _loadAdjacentContinuousTextChapterFlow(forward: forward);
  }

  bool _isContinuousTextChapterActive(ReaderPageContinuousTextChapter chapter) {
    return _isContinuousTextChapterActiveFlow(chapter);
  }

  ReaderPageContinuousTextChapter? _findCurrentContinuousTextChapter() {
    return _findCurrentContinuousTextChapterFlow();
  }

  double _continuousTextChapterScrollRatioFor(
    ReaderPageContinuousTextChapter chapter,
  ) {
    return _continuousTextChapterScrollRatioForFlow(chapter);
  }

  double _continuousTextChapterDocumentRatioFor(
    ReaderPageContinuousTextChapter chapter,
  ) {
    return _continuousTextChapterDocumentRatioForFlow(chapter);
  }

  ReaderPageContinuousTextChapter?
  _resolveActiveContinuousTextChapterForRuntime() {
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
      _interactionRuntimeController.isLowPriorityWorkPaused;

  ReaderInteractionRuntimeState get _readerInteractionState =>
      _interactionRuntimeController.state;

  void _applyReaderInteractionTransition(
    ReaderInteractionStateTransition? transition,
  ) {
    if (transition == null) {
      return;
    }
    final context = <String, Object?>{
      'chain': 'reader_interaction_state',
      'from': transition.from.name,
      'to': transition.to.name,
      'chapterId': _chapterId,
      'viewportKind': _currentViewportKind.name,
      'contentMode': _currentContentMode.name,
    };
    developer.Timeline.instantSync(
      'reader.interaction_state',
      arguments: context,
    );
    _logger.debug('Reader interaction state changed', context: context);
    if (_interactionRuntimeController.consumeDeferredNeighborPreloadIfIdle()) {
      _startNeighborPreloadNow();
    }
  }

  void _markReaderInteractionBusy(ReaderInteractionRuntimeState state) {
    _applyReaderInteractionTransition(
      _interactionRuntimeController.markBusy(state),
    );
  }

  void _scheduleReaderInteractionSettle() {
    if (!mounted) {
      return;
    }
    _applyReaderInteractionTransition(
      _interactionRuntimeController.beginSettling(
        onSettled: (transition) {
          if (!mounted) {
            return;
          }
          _applyReaderInteractionTransition(transition);
        },
      ),
    );
  }

  void _handlePagedScrollInteractionChanged(bool isInteracting) {
    if (isInteracting) {
      _markReaderInteractionBusy(ReaderInteractionRuntimeState.dragging);
    } else {
      _scheduleReaderInteractionSettle();
    }
  }

  void _scheduleNeighborPreload() {
    if (_isLowPriorityReaderWorkPaused) {
      _interactionRuntimeController.markDeferredNeighborPreload();
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
            _pageTurnRuntimeController
                .pagedPaginationState = _pageTurnRuntimeController
                .pagedPaginationState
                .copyWith(pendingRestoreRatio: plan.normalizedRatio);
            return;
          }
          setState(() {
            _pageTurnRuntimeController.currentPageIndex = plan.pageIndex ?? 0;
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
      showOverlayControls: _overlayController.showOverlayControls,
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
      showOverlayControls: _overlayController.showOverlayControls,
      textSelectionActive: _isTextSelectionActive,
      isBootstrapping: _isBootstrapping,
      isLoadingContent: _isLoadingContent,
      hasError: _errorText != null,
      hasTextContent: _content.trim().isNotEmpty,
      isPaginating:
          _pageTurnRuntimeController.pagedPaginationState.isPaginating,
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
        _bookmarkRangesByParagraph = const <int, List<ReaderBookmarkRange>>{};
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
      return pageCount > 0 &&
          _pageTurnRuntimeController.currentPageIndex >= pageCount - 1;
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
      _setAutoReadSessionState(ReaderAutoReadSessionState.running);
      _reconcileAutoRead();
    });
  }

  void _setAutoReadSessionState(
    ReaderAutoReadSessionState state, {
    bool rebuild = true,
  }) {
    if (_autoReadSessionState == state) {
      return;
    }
    _autoReadSessionState = state;
    if (rebuild && mounted) {
      setState(() {});
    }
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

    await _turnPagedTextPage(
      direction: 1,
      source: ReaderPageTurnRequestSource.autoRead,
    );
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
    _setAutoReadSessionState(ReaderAutoReadSessionState.chapterPaused);
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
    _setAutoReadSessionState(ReaderAutoReadSessionState.running);
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
        _setAutoReadSessionState(ReaderAutoReadSessionState.running);
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
    _setAutoReadSessionState(ReaderAutoReadSessionState.finished);
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
      showOverlayControls: _overlayController.showOverlayControls,
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
    final decision = _readerRuntimeFacade.resolveProgressSaveDecision(
      lastSavedAt: _lastProgressSavedAt,
      now: DateTime.now(),
    );
    if (decision.flushImmediately) {
      _flushProgressSave();
      return;
    }
    _progressDebounceTimer = Timer(decision.debounce, _flushProgressSave);
  }

  void _flushProgressSave() {
    _progressDebounceTimer?.cancel();
    _progressDebounceTimer = null;
    _lastProgressSavedAt = DateTime.now();
    unawaited(_saveProgress());
  }

  void _maybeStartReadingRecordSession({double? initialRatio}) {
    final result = _readerRuntimeFacade.startOrUpdateReadingRecordSession(
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
    _activeReadingRecordSession = _readerRuntimeFacade
        .syncReadingRecordSessionProgress(
          session: _activeReadingRecordSession,
          ratio: ratio ?? _currentScrollRatio(),
        );
  }

  void _scheduleReadingRecordAutoCommit() {
    _readingRecordAutoCommitTimer?.cancel();
    if (_activeReadingRecordSession == null) {
      _readingRecordAutoCommitTimer = null;
      return;
    }
    final interval = _readerRuntimeFacade.autoCommitInterval(
      session: _activeReadingRecordSession,
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
    _overlayController.showBlockingLoadingCard = false;

    final decision = _contentLoadController.resolveDelayedUi(
      needsBlockingLoadingUi: _needsBlockingLoadingUi,
      isBootstrapping: _isBootstrapping,
      isSwitchSourceLoading: _isSwitchSourceLoading,
      hasVisibleReaderContent: _hasVisibleReaderContent,
      isLoadingContent: _isLoadingContent,
      shouldShowBlockingReaderLoading: _shouldShowBlockingReaderLoading,
    );
    if (!decision.showBlockingLoadingCard) {
      return;
    }

    _blockingLoadingCardTimer = Timer(
      _ReaderPageState._kBlockingLoadingCardDelay,
      () {
        if (!mounted || !_needsBlockingLoadingUi) {
          return;
        }
        setState(() {
          _overlayController.showBlockingLoadingCard = true;
        });
      },
    );
  }

  void _scheduleHiddenLoadingPlaceholder() {
    _hiddenLoadingPlaceholderTimer?.cancel();
    _hiddenLoadingPlaceholderTimer = null;
    _overlayController.showHiddenLoadingPlaceholder = false;

    final decision = _contentLoadController.resolveDelayedUi(
      needsBlockingLoadingUi: _needsBlockingLoadingUi,
      isBootstrapping: _isBootstrapping,
      isSwitchSourceLoading: _isSwitchSourceLoading,
      hasVisibleReaderContent: _hasVisibleReaderContent,
      isLoadingContent: _isLoadingContent,
      shouldShowBlockingReaderLoading: _shouldShowBlockingReaderLoading,
    );
    if (!decision.showHiddenLoadingPlaceholder) {
      return;
    }

    _hiddenLoadingPlaceholderTimer = Timer(
      _ReaderPageState._kHiddenLoadingPlaceholderDelay,
      () {
        if (!mounted || !_needsBlockingLoadingUi) {
          return;
        }
        setState(() {
          _overlayController.showHiddenLoadingPlaceholder = true;
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
    _overlayController.resetLoadingIndicators();
  }

  void _scheduleChapterLoadingIndicator() {
    _chapterLoadingIndicatorTimer?.cancel();
    _chapterLoadingIndicatorTimer = null;
    _overlayController.showChapterLoadingIndicator = false;

    final decision = _contentLoadController.resolveDelayedUi(
      needsBlockingLoadingUi: _needsBlockingLoadingUi,
      isBootstrapping: _isBootstrapping,
      isSwitchSourceLoading: _isSwitchSourceLoading,
      hasVisibleReaderContent: _hasVisibleReaderContent,
      isLoadingContent: _isLoadingContent,
      shouldShowBlockingReaderLoading: _shouldShowBlockingReaderLoading,
    );
    if (!decision.showChapterLoadingIndicator) {
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
          _overlayController.showChapterLoadingIndicator = true;
        });
      },
    );
  }

  Future<void> _saveProgress() async {
    final progress = _progressCommitController.buildProgress(
      ReaderProgressCommitInput(
        bookId: _currentBookId,
        sourceId: _sourceId,
        detailUrl: _detailUrl,
        chapterId: _chapterId,
        chapterUrl: _chapterUrl,
        chapterTitle: _chapterTitle,
        chapterIndex: _currentIndex,
        positionRatio: _currentLogicalPositionRatio(),
        viewportState: _currentViewportState(),
        contentMode: _currentContentMode,
        logicalPosition: _currentLogicalPosition(),
        audioPlaybackPosition: _audioPlaybackPosition,
        audioPlaybackDuration: _audioPlaybackDuration,
        audioPlaybackSpeed: _audioPlaybackSpeed,
        updatedAt: DateTime.now(),
      ),
    );
    if (progress == null) {
      return;
    }
    await _preferencesService.saveProgress(progress);
  }

  Future<void> _turnPagedTextPage({
    required int direction,
    ReaderPageTurnRequestSource source = ReaderPageTurnRequestSource.unknown,
  }) async {
    final request = ReaderPageTurnRequest(direction: direction, source: source);
    final plan = _pageTurnCoordinator.resolvePagedTextTurn(
      request: request,
      snapshot: _readerPageTurnCoordinatorSnapshot(),
      settings: _settings,
      renderer: _pagedTextRenderer,
      document: _document,
    );
    _logReaderPageTurnPlan(plan);

    final results = await _pageTurnCoordinator.executePlan(
      plan: plan,
      handlers: ReaderPageTurnExecutionHandlers(
        prepareForTurn: () {
          _clearSelectionState();
          _clearSystemSelection();
        },
        markFirstPageTurnRequested: _markFirstPageTurnRequested,
        onSettleRequired: _scheduleReaderInteractionSettle,
        executePaperCurl: _turnPaperCurlPage,
        executeCrossChapter: _turnCrossChapterWithSnapshot,
        executeCurl: _executeCurlPageTurn,
        executeImmediate: _executeImmediatePageTurn,
        executeAnimated: _executeAnimatedPageTurn,
      ),
    );
    for (final result in results) {
      _logReaderPageTurnResult(result);
    }
  }

  Future<ReaderPageTurnResult?> _executeCurlPageTurn(
    ReaderPageTurnPlan plan,
  ) async {
    return _autoTurnCurlPage(plan.safeDirection, request: plan.request);
  }

  Future<ReaderPageTurnResult?> _executeImmediatePageTurn(
    ReaderPageTurnPlan plan,
  ) async {
    final action = plan.action;
    if (action == null) {
      return ReaderPageTurnResult(
        type: ReaderPageTurnResultType.rejected,
        request: plan.request,
        executionType: plan.executionType,
        rejectReason: ReaderPageTurnRejectReason.missingAction,
      );
    }
    _snapToPagedTextPage(action.targetPageIndex);
    _recordFirstPageTurnCompleted(mode: 'immediate');
    return _pageTurnCoordinator.resultFromPlan(
      plan,
      type: ReaderPageTurnResultType.committed,
    );
  }

  Future<ReaderPageTurnResult?> _executeAnimatedPageTurn(
    ReaderPageTurnPlan plan,
  ) async {
    final action = plan.action;
    if (action == null) {
      return ReaderPageTurnResult(
        type: ReaderPageTurnResultType.rejected,
        request: plan.request,
        executionType: plan.executionType,
        rejectReason: ReaderPageTurnRejectReason.missingAction,
      );
    }
    _startPagedPageTransition(action, request: plan.request);
    return null;
  }

  ReaderPageTurnCoordinatorSnapshot _readerPageTurnCoordinatorSnapshot() {
    return ReaderPageTurnCoordinatorSnapshot(
      isTextPagedViewport: _isTextPagedViewport,
      isPaginating:
          _pageTurnRuntimeController.pagedPaginationState.isPaginating,
      pageCount: _currentPagedPageCount,
      currentPageIndex: _pageTurnRuntimeController.currentPageIndex,
      usesPaperCurlAnimation: _usesPaperCurlAnimation,
      pagedTransitionAnimating: _isPagedTransitionAnimating,
    );
  }

  void _logReaderPageTurnPlan(ReaderPageTurnPlan plan) {
    final context = <String, Object?>{
      'chain': 'reader_page_turn_coordinator',
      'step': 'plan',
      'executionType': plan.executionType.name,
      'direction': plan.request.safeDirection,
      'source': plan.request.source.name,
      'targetPageIndex': plan.targetPageIndex,
      'rejectReason': plan.rejectReason?.name,
      'message': plan.message,
      'chapterId': _chapterId,
      'currentPageIndex': _pageTurnRuntimeController.currentPageIndex,
      'pageCount': _currentPagedPageCount,
      'viewportKind': _currentViewportKind.name,
    };
    developer.Timeline.instantSync('reader.page_turn_plan', arguments: context);
    _logger.debug('Reader page turn plan', context: context);
  }

  void _logReaderPageTurnResult(ReaderPageTurnResult result) {
    final context = <String, Object?>{
      'chain': 'reader_page_turn_coordinator',
      'step': 'result',
      'type': result.type.name,
      'executionType': result.executionType?.name,
      'direction': result.request.safeDirection,
      'source': result.request.source.name,
      'targetPageIndex': result.targetPageIndex,
      'rejectReason': result.rejectReason?.name,
      'message': result.message,
      'chapterId': _chapterId,
      'currentPageIndex': _pageTurnRuntimeController.currentPageIndex,
      'pageCount': _currentPagedPageCount,
      'viewportKind': _currentViewportKind.name,
    };
    developer.Timeline.instantSync(
      'reader.page_turn_result',
      arguments: context,
    );
    if (result.isFailure) {
      _logger.warn('Reader page turn result', context: context);
    } else {
      _logger.debug('Reader page turn result', context: context);
    }
  }

  void _startPagedPageTransition(
    PagedTransitionAction action, {
    ReaderPageTurnRequest? request,
  }) {
    if (_isPagedTransitionAnimating) {
      return;
    }
    final transitionState = action.transitionState;
    final motion = action.motion;
    if (transitionState == null || motion == null) {
      return;
    }
    _markReaderInteractionBusy(ReaderInteractionRuntimeState.animating);
    _pagedTransitionController.duration = motion.duration;
    setState(() {
      _pageTurnRuntimeController.beginPagedTransition(transitionState);
    });
    _pagedTransitionController.value = 0;
    _pagedTransitionController.forward();
  }

  Future<ReaderPageTurnResult?> _turnCrossChapterWithSnapshot(
    ReaderPageTurnPlan plan, {
    ReaderPageAnimationStyle? style,
    String completionMode = 'cross_chapter',
  }) async {
    final forward = plan.safeDirection >= 0;
    final resolvedStyle =
        style ??
        plan.action?.transitionState?.style ??
        _pagedTextRenderer.resolveAnimationStyle(
          _settings,
          document: _document,
        );
    if (_pageTurnRuntimeController.crossChapterSnapshotTransition.isActive) {
      return ReaderPageTurnResult(
        type: ReaderPageTurnResultType.rejected,
        request: plan.request,
        executionType: ReaderPageTurnExecutionType.crossChapter,
        rejectReason: ReaderPageTurnRejectReason.pageTurnBusy,
      );
    }

    final sessionState = _currentTextSessionState();
    final decision = _chapterFlow.resolveAdjacentChapter(
      chapters: _chapters,
      currentChapterIndex: sessionState?.currentChapterIndex ?? _currentIndex,
      forward: forward,
      initialScrollRatio: forward ? 0 : 1,
    );
    if (decision.type == ReaderAdjacentChapterDecisionType.noCurrent) {
      return ReaderPageTurnResult(
        type: ReaderPageTurnResultType.rejected,
        request: plan.request,
        executionType: ReaderPageTurnExecutionType.crossChapter,
        rejectReason: ReaderPageTurnRejectReason.noAdjacentChapter,
      );
    }
    if (decision.type == ReaderAdjacentChapterDecisionType.boundary) {
      _showChapterBoundaryHint(isFirst: decision.isFirstBoundary);
      return ReaderPageTurnResult(
        type: ReaderPageTurnResultType.boundary,
        request: plan.request,
        executionType: ReaderPageTurnExecutionType.crossChapter,
      );
    }

    final direction = forward ? 1 : -1;
    final targetChapterIndex = decision.targetChapterIndex!;
    if (resolvedStyle == ReaderPageAnimationStyle.none) {
      await _jumpTo(
        targetChapterIndex,
        initialScrollRatio: decision.initialScrollRatio,
      );
      if (!mounted || _currentIndex != targetChapterIndex) {
        return ReaderPageTurnResult(
          type: ReaderPageTurnResultType.rejected,
          request: plan.request,
          executionType: ReaderPageTurnExecutionType.crossChapter,
          rejectReason: ReaderPageTurnRejectReason.crossChapterCancelled,
        );
      }
      _recordFirstPageTurnCompleted(mode: completionMode);
      _syncActiveReadingRecordSessionProgress();
      _scheduleProgressSave();
      _scheduleReaderInteractionSettle();
      return ReaderPageTurnResult(
        type: ReaderPageTurnResultType.committed,
        request: plan.request,
        executionType: ReaderPageTurnExecutionType.crossChapter,
      );
    }

    final fromImage = await _captureReaderContentSnapshot();
    if (fromImage == null) {
      final jumped = await _jumpToAdjacentReadableChapter(forward: forward);
      return ReaderPageTurnResult(
        type:
            jumped
                ? ReaderPageTurnResultType.fallbackCommitted
                : ReaderPageTurnResultType.rejected,
        request: plan.request,
        executionType: ReaderPageTurnExecutionType.crossChapter,
      );
    }

    final generation =
        _pageTurnRuntimeController.nextCrossChapterSnapshotGeneration();
    _markReaderInteractionBusy(ReaderInteractionRuntimeState.animating);
    _startCrossChapterSnapshotTransition(
      generation: generation,
      fromImage: fromImage,
      style: resolvedStyle,
      direction: direction,
      completionMode: completionMode,
    );

    await _jumpTo(
      targetChapterIndex,
      initialScrollRatio: decision.initialScrollRatio,
    );
    if (!mounted ||
        !_pageTurnRuntimeController.isCrossChapterSnapshotGenerationActive(
          generation,
        ) ||
        _currentIndex != targetChapterIndex) {
      _clearCrossChapterSnapshotTransition();
      _scheduleReaderInteractionSettle();
      return ReaderPageTurnResult(
        type: ReaderPageTurnResultType.rejected,
        request: plan.request,
        executionType: ReaderPageTurnExecutionType.crossChapter,
        rejectReason: ReaderPageTurnRejectReason.crossChapterCancelled,
      );
    }

    await _waitForCrossChapterSnapshotTarget(
      generation: generation,
      targetChapterIndex: targetChapterIndex,
    );
    if (!mounted ||
        !_pageTurnRuntimeController.isCrossChapterSnapshotGenerationActive(
          generation,
        )) {
      _clearCrossChapterSnapshotTransition();
      _scheduleReaderInteractionSettle();
      return ReaderPageTurnResult(
        type: ReaderPageTurnResultType.rejected,
        request: plan.request,
        executionType: ReaderPageTurnExecutionType.crossChapter,
        rejectReason: ReaderPageTurnRejectReason.crossChapterCancelled,
      );
    }

    final toImage = await _captureReaderContentSnapshot();
    if (toImage == null) {
      _clearCrossChapterSnapshotTransition();
      _recordFirstPageTurnCompleted(mode: completionMode);
      _scheduleReaderInteractionSettle();
      return ReaderPageTurnResult(
        type: ReaderPageTurnResultType.fallbackCommitted,
        request: plan.request,
        executionType: ReaderPageTurnExecutionType.crossChapter,
      );
    }

    _attachCrossChapterSnapshotTarget(generation: generation, toImage: toImage);
    if (resolvedStyle == ReaderPageAnimationStyle.paperCurl) {
      return null;
    }

    final motion = _crossChapterMotionSpecForStyle(resolvedStyle);
    _crossChapterSnapshotController.duration = motion.duration;
    _crossChapterSnapshotController.value = 0;
    if (motion.duration <= Duration.zero) {
      _completeCrossChapterSnapshotAnimation();
      return null;
    }
    try {
      await _crossChapterSnapshotController.forward().orCancel;
    } on TickerCanceled {
      if (mounted) {
        _clearCrossChapterSnapshotTransition();
        _scheduleReaderInteractionSettle();
      }
    }
    return null;
  }

  PagedAnimationMotionSpec _crossChapterMotionSpecForStyle(
    ReaderPageAnimationStyle style,
  ) {
    final base = _pagedTextRenderer.motionSpecForStyle(style);
    final duration = switch (style) {
      ReaderPageAnimationStyle.cover => const Duration(milliseconds: 280),
      ReaderPageAnimationStyle.translate ||
      ReaderPageAnimationStyle.vertical => const Duration(milliseconds: 260),
      ReaderPageAnimationStyle.fade => const Duration(milliseconds: 220),
      ReaderPageAnimationStyle.curl => const Duration(milliseconds: 360),
      ReaderPageAnimationStyle.paperCurl => base.duration,
      ReaderPageAnimationStyle.none => Duration.zero,
    };
    return PagedAnimationMotionSpec(
      duration: duration,
      switchInCurve: base.switchInCurve,
      switchOutCurve: base.switchOutCurve,
    );
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
    // In release mode, debugNeedsPaint is always false, so we unconditionally
    // wait one more frame to ensure rendering is complete before capturing.
    await WidgetsBinding.instance.endOfFrame;
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
          !_pageTurnRuntimeController.isCrossChapterSnapshotGenerationActive(
            generation,
          ) ||
          _currentIndex != targetChapterIndex) {
        return;
      }
      final hasPagedContent = _currentPagedPageCount > 0;
      if (!_isLoadingContent &&
          !_pageTurnRuntimeController.pagedPaginationState.isPaginating &&
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
      _pageTurnRuntimeController.buildCrossChapterSnapshotTransition(
        generation: generation,
        fromImage: fromImage,
        style: style,
        direction: direction,
        completionMode: completionMode,
      ),
    );
  }

  void _attachCrossChapterSnapshotTarget({
    required int generation,
    required ui.Image toImage,
  }) {
    if (!_pageTurnRuntimeController.attachCrossChapterSnapshotTarget(
      generation: generation,
      toImage: toImage,
    )) {
      toImage.dispose();
      return;
    }
    setState(() {});
  }

  void _replaceCrossChapterSnapshotTransition(
    ReaderCrossChapterSnapshotTransitionState next,
  ) {
    final previous = _pageTurnRuntimeController
        .replaceCrossChapterSnapshotTransition(next);
    final previousFrom = previous.fromImage;
    final previousTo = previous.toImage;
    final nextFrom = next.fromImage;
    final nextTo = next.toImage;
    setState(() {});
    if (previousFrom != null && previousFrom != nextFrom) {
      previousFrom.dispose();
    }
    if (previousTo != null && previousTo != nextTo) {
      previousTo.dispose();
    }
  }

  void _clearCrossChapterSnapshotTransition({bool setStateIfNeeded = false}) {
    _crossChapterSnapshotController.stop();
    final previous =
        _pageTurnRuntimeController.clearCrossChapterSnapshotTransition();
    if (mounted && setStateIfNeeded) {
      setState(() {});
      _disposeCrossChapterSnapshotImagesAfterFrame(previous);
    } else {
      previous.fromImage?.dispose();
      previous.toImage?.dispose();
    }
  }

  Future<void> _disposeCrossChapterSnapshotImagesAfterFrame(
    ReaderCrossChapterSnapshotTransitionState previous,
  ) async {
    await WidgetsBinding.instance.endOfFrame;
    previous.fromImage?.dispose();
    if (previous.fromImage != previous.toImage) {
      previous.toImage?.dispose();
    }
  }

  void _completeCrossChapterSnapshotAnimation() {
    if (!_pageTurnRuntimeController.crossChapterSnapshotTransition.hasTarget) {
      return;
    }
    final direction =
        _pageTurnRuntimeController.crossChapterSnapshotTransition.direction;
    final completionMode =
        _pageTurnRuntimeController
            .crossChapterSnapshotTransition
            .completionMode;
    _clearCrossChapterSnapshotTransition(setStateIfNeeded: true);
    _recordFirstPageTurnCompleted(mode: completionMode);
    _syncActiveReadingRecordSessionProgress();
    _scheduleProgressSave();
    _scheduleReaderInteractionSettle();
    _logReaderPageTurnResult(
      ReaderPageTurnResult(
        type: ReaderPageTurnResultType.committed,
        request: ReaderPageTurnRequest(direction: direction),
        executionType: ReaderPageTurnExecutionType.crossChapter,
      ),
    );
  }

  void _onCrossChapterSnapshotStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) {
      return;
    }
    _completeCrossChapterSnapshotAnimation();
  }

  Future<ReaderPageTurnResult?> _turnPaperCurlPage(
    ReaderPageTurnPlan plan,
  ) async {
    if (_paperCurlViewKey.currentState?.isAnimating ?? false) {
      return ReaderPageTurnResult(
        type: ReaderPageTurnResultType.rejected,
        request: plan.request,
        executionType: ReaderPageTurnExecutionType.paperCurl,
        rejectReason: ReaderPageTurnRejectReason.pageTurnBusy,
      );
    }
    final direction = plan.safeDirection;
    final pageCount = _currentPagedPageCount;
    final currentIndex = _pageTurnRuntimeController.currentPageIndex.clamp(
      0,
      pageCount - 1,
    );
    if (direction < 0 && currentIndex <= 0) {
      return _turnCrossChapterWithSnapshot(
        plan,
        style: ReaderPageAnimationStyle.paperCurl,
        completionMode: 'paper_curl_cross_chapter',
      );
    }
    if (direction > 0 && currentIndex >= pageCount - 1) {
      return _turnCrossChapterWithSnapshot(
        plan,
        style: ReaderPageAnimationStyle.paperCurl,
        completionMode: 'paper_curl_cross_chapter',
      );
    }

    final paperCurlState = _paperCurlViewKey.currentState;
    if (paperCurlState == null) {
      return ReaderPageTurnResult(
        type: ReaderPageTurnResultType.rejected,
        request: plan.request,
        executionType: ReaderPageTurnExecutionType.paperCurl,
        rejectReason: ReaderPageTurnRejectReason.paperCurlUnavailable,
      );
    }
    final turned = paperCurlState.turnPage(direction);
    if (!turned) {
      return ReaderPageTurnResult(
        type: ReaderPageTurnResultType.rejected,
        request: plan.request,
        executionType: ReaderPageTurnExecutionType.paperCurl,
        rejectReason: ReaderPageTurnRejectReason.paperCurlRejected,
      );
    }
    return null;
  }

  void _commitPaperCurlPage(int pageIndex) {
    if (!mounted) {
      return;
    }
    final pageCount = _currentPagedPageCount;
    if (pageCount <= 0) {
      return;
    }
    final previousIndex = _pageTurnRuntimeController.currentPageIndex;
    final safeIndex = pageIndex.clamp(0, _safePageUpperBound(pageCount));
    _updateReaderState(() {
      _pageTurnRuntimeController.commitPaperCurlTurn(
        pageIndex: safeIndex,
        pageCount: pageCount,
      );
    });
    _syncActiveReadingRecordSessionProgress();
    _scheduleProgressSave();
    _scheduleReaderInteractionSettle();
    _logReaderPageTurnResult(
      ReaderPageTurnResult(
        type: ReaderPageTurnResultType.committed,
        request: ReaderPageTurnRequest(direction: pageIndex - previousIndex),
        executionType: ReaderPageTurnExecutionType.paperCurl,
        targetPageIndex: safeIndex,
      ),
    );
  }

  void _handlePaperCurlTurnResult(ReaderPaperCurlResult result) {
    final context = <String, Object?>{
      'chain': 'reader_paper_curl_adapter',
      'type': result.type.name,
      'direction': result.direction,
      'fromPageIndex': result.fromPageIndex,
      'targetPageIndex': result.targetPageIndex,
      'failureReason': result.failureReason?.name,
      'message': result.message,
      'chapterId': _chapterId,
      'currentPageIndex': _pageTurnRuntimeController.currentPageIndex,
      'pageCount': _currentPagedPageCount,
      'viewportKind': _currentViewportKind.name,
    };
    developer.Timeline.instantSync(
      'reader.paper_curl_adapter_result',
      arguments: context,
    );
    if (result.isFailure) {
      _logger.warn('Reader paper curl adapter result', context: context);
    } else {
      _logger.info('Reader paper curl adapter result', context: context);
    }
  }

  void _onPagedTransitionStatus(AnimationStatus status) {
    final commit = _pagedTransitionLogic.completeTransition(
      status: status,
      state: _pageTurnRuntimeController.pagedTransition,
    );
    if (commit == null) {
      return;
    }

    setState(() {
      _pageTurnRuntimeController.currentPageIndex = commit.nextPageIndex;
      _pageTurnRuntimeController.beginPagedTransition(commit.nextState);
    });
    _syncActiveReadingRecordSessionProgress();
    _scheduleProgressSave();
    _recordFirstPageTurnCompleted(mode: 'animated');
    _scheduleReaderInteractionSettle();
    _logReaderPageTurnResult(
      ReaderPageTurnResult(
        type: ReaderPageTurnResultType.committed,
        request: ReaderPageTurnRequest(direction: commit.nextState.direction),
        executionType: ReaderPageTurnExecutionType.animated,
        targetPageIndex: commit.nextPageIndex,
      ),
    );
  }
}

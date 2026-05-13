part of 'reader_page.dart';

class _ReaderPageDependencyBinder {
  const _ReaderPageDependencyBinder();

  void bind(_ReaderPageState state, ReaderFeatureDependencies dependencies) {
    state._contentProviderRegistry = dependencies.contentProviderRegistry;
    state._preferencesService = dependencies.preferencesService;
    state._visualOverridesService = dependencies.visualOverridesService;
    state._platformBridgeService = dependencies.platformBridgeService;
    state._fontRegistryService = dependencies.fontRegistryService;
    state._paginationCacheService = dependencies.paginationCacheService;
    state._systemSettingsService = dependencies.systemSettingsService;
    state._readerBackgroundService = dependencies.readerBackgroundService;
    state._localBookStorageService = dependencies.localBookStorageService;
    state._readerErrorCenterService = dependencies.readerErrorCenterService;
    state._readingRecordService = dependencies.readingRecordService;
    state._imageSelectionService = dependencies.imageSelectionService;
    state._bookshelfService = dependencies.bookshelfService;
    state._switchSourceSearchService = dependencies.switchSourceSearchService;
    state._searchHitCacheService = dependencies.searchHitCacheService;
    state._sourceHealthService = dependencies.sourceHealthService;
    state._sourceRuntimeFacade = dependencies.sourceRuntimeFacade;
    state._taskConflictService = dependencies.taskConflictService;
    state._taskScheduler = dependencies.taskScheduler;
    state._bookmarkRepository = dependencies.bookmarkRepository;
    state._bookMetadataOverrideRepository =
        dependencies.bookMetadataOverrideRepository;
    state._localBookRepository = dependencies.localBookRepository;
    state._cachedChapterStore = dependencies.cachedChapterStore;
    state._resourceBudgetResolver = dependencies.resourceBudgetResolver;
    state._logger = dependencies.logger;
    state._battery = dependencies.battery;
    state._deviceInfo = dependencies.deviceInfo;
  }
}

extension _ReaderPageLifecycleExtension on _ReaderPageState {
  void _bindReaderDependencies() {
    final dependenciesFactory = ref.read(
      readerFeatureDependenciesFactoryProvider,
    );
    const _ReaderPageDependencyBinder().bind(this, dependenciesFactory());
  }

  void _initializeReaderPage() {
    WidgetsBinding.instance.addObserver(this);
    _bindDependencies();
    _appThemeModeSubscription = ref.listenManual<ThemeMode>(
      appThemeModeProvider,
      (_, next) => _handleAppThemeModeChanged(next),
    );
    _activeAdvancedThemeSubscription = ref
        .listenManual<AsyncValue<AppAdvancedTheme?>>(
          activeAdvancedThemeProvider,
          (_, next) => _handleActiveAdvancedThemeChanged(next),
        );
    _chapterId = widget.chapterId;
    _chapterUrl = widget.chapterUrl?.trim();
    _chapterTitle = widget.chapterTitle?.trim();
    _sourceId = widget.sourceId?.trim();
    _detailUrl = widget.detailUrl?.trim();
    _activeBookId = widget.bookId.trim();
    _cancelBackgroundRefreshConflictForCurrentBook();
    _bookTitle = widget.chapterTitle?.trim() ?? '';
    _currentIndex = widget.chapterIndex;
    _readerInteractionUnlockAt = DateTime.now().add(
      _ReaderPageState._kInitialReaderInteractionCooldown,
    );
    final incomingBookmarkId = widget.bookmarkId?.trim() ?? '';
    if (incomingBookmarkId.isNotEmpty) {
      _pendingBookmarkId = incomingBookmarkId;
    }
    _overlayControlsController = AnimationController(
      vsync: this,
      duration: _ReaderPageState._kOverlayControlsShowDuration,
      reverseDuration: _ReaderPageState._kOverlayControlsHideDuration,
      value: _showOverlayControls ? 1 : 0,
    );
    _pagedTransitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _pagedTransitionController.addStatusListener(_onPagedTransitionStatus);
    _curlAutoTurnController = AnimationController(
      vsync: this,
      duration: _ReaderPageState._kCurlAutoTurnDuration,
    );
    _curlAutoTurnController.addStatusListener(_onCurlAutoTurnStatus);
    _scrollController.addListener(_onScrollChanged);
    _selectionNotifier.addListener(_handleSelectionNotifierChanged);
    if (_platformBridgeService.isVolumeKeyPagingSupported) {
      _volumeKeyEventSubscription = _platformBridgeService.volumeKeyEvents
          .listen(
            (event) => unawaited(_handleVolumeKeyEvent(event)),
            onError: (_) {},
          );
    }
    unawaited(_syncVolumeKeyPageInterception());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncSystemUiVisibility(force: true);
    });
    unawaited(_refreshReaderInfoSnapshot(force: true));
    _scheduleReaderInfoMinuteTick();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _readerFocusNode.requestFocus();
      }
    });

    _bootstrap();
  }

  void _handlePlatformBrightnessChange() {
    // Reader theme is persisted independently from the app shell theme.
    // Platform brightness changes only affect reader brightness-following UI.
    if (_settings.followSystemBrightness &&
        _lifecycleDelegate.shouldSyncThemeOnPlatformBrightness(
          mounted: mounted,
          hasPendingModalInteraction: false,
        )) {
      _updateReaderState(() {});
    }
  }

  void _disposeReaderPage() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelActiveSwitchSourceSearch();
    _readerSessionController.cancelAll();
    _flushProgressSave();
    final sourceId = (_sourceId ?? '').trim();
    if (sourceId.isNotEmpty) {
      _sourceRuntimeFacade.clearReadingFlow(
        sourceId: sourceId,
        detailUrl: (_detailUrl ?? '').trim(),
        title: _bookTitle.trim(),
      );
    }
    _commitReadingRecordSession();
    _syncSystemUiVisibility(force: true, visible: true);
    unawaited(_restoreSystemReaderBrightness());
    _overlayControlsController.stop();
    _pagedTransitionController.stop();
    _curlAutoTurnController.stop();
    _pagedTransition = PagedTransitionController.idleState;
    _curlTransition = const _CurlTransitionState();
    _progressDebounceTimer?.cancel();
    _autoReadResumeTimer?.cancel();
    _readerInfoClockTimer?.cancel();
    _chapterLoadingIndicatorTimer?.cancel();
    _blockingLoadingCardTimer?.cancel();
    _hiddenLoadingPlaceholderTimer?.cancel();
    _readingRecordAutoCommitTimer?.cancel();
    _readerInteractionSettleTimer?.cancel();
    _volumeKeyEventSubscription?.cancel();
    _appThemeModeSubscription?.close();
    _activeAdvancedThemeSubscription?.close();
    _volumeKeyEventSubscription = null;
    _scrollController.removeListener(_onScrollChanged);
    _selectionNotifier.removeListener(_handleSelectionNotifierChanged);
    _selectionNotifier.dispose();
    unawaited(_setVolumeKeyPageInterceptionEnabled(false));
    _stopAutoRead();
    _scrollController.dispose();
    _mangaPageController.dispose();
    _readerFocusNode.dispose();
    _staticPagedTextPageControllerInstance?.dispose();
    _disposeMangaTransformControllers();
    _overlayControlsController.dispose();
    _pagedTransitionController.dispose();
    _curlAutoTurnController.dispose();
  }

  void _applyReaderImageCacheBudget() {
    final budget = _readerImageDecodeBudget(
      role: ReaderImageDecodeRole.epubInline,
      logicalWidth: MediaQuery.sizeOf(context).width,
    );
    final imageCache = PaintingBinding.instance.imageCache;
    imageCache.maximumSize = budget.imageCacheMaximumSize;
    imageCache.maximumSizeBytes = budget.imageCacheMaximumSizeBytes;
  }

  void _handleReaderAppLifecycleState(AppLifecycleState state) {
    if (_lifecycleDelegate.shouldPauseReaderRuntime(state)) {
      _isReaderRuntimeVisible = false;
      _pauseAutoReadForRuntime();
      _flushProgressSave();
      unawaited(_setVolumeKeyPageInterceptionEnabled(false));
      unawaited(_restoreSystemReaderBrightness());
      _commitReadingRecordSession();
      return;
    }

    if (_lifecycleDelegate.shouldResumeReaderRuntime(state)) {
      _isReaderRuntimeVisible = true;
      unawaited(_refreshReaderInfoSnapshot(force: true));
      _scheduleReaderInfoMinuteTick();
      unawaited(_syncVolumeKeyPageInterception());
      unawaited(_applySystemReaderBrightness());
      _maybeStartReadingRecordSession(initialRatio: _currentScrollRatio());
      if (_isAutoReadPausedByRuntime) {
        _isAutoReadPausedByRuntime = false;
        _scheduleAutoReadResume();
      }
    }
  }

  Future<void> _applySystemReaderBrightnessImpl([double? brightness]) async {
    if (_settings.followSystemBrightness) {
      await _restoreSystemReaderBrightness();
      return;
    }
    final applied = await _platformBridgeService.setReaderBrightness(
      brightness ?? _settings.brightness,
    );
    if (!mounted) {
      _isSystemBrightnessOverrideActive = applied;
      return;
    }
    if (_isSystemBrightnessOverrideActive == applied) {
      return;
    }
    _updateReaderState(() {
      _isSystemBrightnessOverrideActive = applied;
    });
  }

  Future<void> _restoreSystemReaderBrightnessImpl() async {
    await _platformBridgeService.resetReaderBrightness();
    _isSystemBrightnessOverrideActive = false;
  }
}

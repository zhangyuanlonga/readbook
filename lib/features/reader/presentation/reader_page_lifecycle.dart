part of 'reader_page.dart';

class _ReaderPageDependencyBinder {
  const _ReaderPageDependencyBinder();

  void bind(_ReaderPageState state, ReaderFeatureDependencies dependencies) {
    state._contentProviderRegistry = dependencies.contentProviderRegistry;
    state._preferencesService = dependencies.preferencesService;
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
    _chapterId = widget.chapterId;
    _chapterUrl = widget.chapterUrl?.trim();
    _chapterTitle = widget.chapterTitle?.trim();
    _sourceId = widget.sourceId?.trim();
    _detailUrl = widget.detailUrl?.trim();
    _activeBookId = widget.bookId.trim();
    _cancelBackgroundRefreshConflictForCurrentBook();
    _bookTitle = widget.chapterTitle?.trim() ?? '';
    _currentIndex = widget.chapterIndex;
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
    _appThemeModeSubscription = ref.listenManual<ThemeMode>(
      appThemeModeProvider,
      (previous, next) {
        unawaited(_syncReaderThemeModeWithAppTheme(next));
      },
    );
    if (_platformBridgeService.isVolumeKeyPagingSupported) {
      _volumeKeyEventSubscription = _platformBridgeService.volumeKeyEvents.listen(
            (event) => unawaited(_handleVolumeKeyEvent(event)),
            onError: (_) {},
          );
    }
    unawaited(_syncVolumeKeyPageInterception());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncSystemUiVisibility(force: true);
    });
    unawaited(_refreshReaderInfoSnapshot(force: true));
    _readerInfoClockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) {
        return;
      }
      unawaited(_refreshReaderInfoSnapshot());
    });

    _bootstrap();
  }

  void _handlePlatformBrightnessChange() {
    final appThemeMode = ref.read(appThemeModeProvider);
    if (_settings.followSystemBrightness &&
        _lifecycleDelegate.shouldSyncThemeOnPlatformBrightness(
          mounted: mounted,
          hasPendingModalInteraction: false,
        )) {
      _updateReaderState(() {});
    }
    if (appThemeMode != ThemeMode.system) {
      return;
    }
    unawaited(_syncReaderThemeModeWithAppTheme(appThemeMode));
  }

  void _disposeReaderPage() {
    WidgetsBinding.instance.removeObserver(this);
    _appThemeModeSubscription?.close();
    _appThemeModeSubscription = null;
    _cancelActiveSwitchSourceSearch();
    _chapterContentRequestToken += 1;
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
    _readingRecordAutoCommitTimer?.cancel();
    _volumeKeyEventSubscription?.cancel();
    _volumeKeyEventSubscription = null;
    _scrollController.removeListener(_onScrollChanged);
    _selectionNotifier.removeListener(_handleSelectionNotifierChanged);
    _selectionNotifier.dispose();
    unawaited(_setVolumeKeyPageInterceptionEnabled(false));
    _stopAutoRead();
    _scrollController.dispose();
    _mangaPageController.dispose();
    _disposeMangaTransformControllers();
    _overlayControlsController.dispose();
    _pagedTransitionController.dispose();
    _curlAutoTurnController.dispose();
  }

  void _handleReaderAppLifecycleState(AppLifecycleState state) {
    if (_lifecycleDelegate.shouldPauseReaderRuntime(state)) {
      unawaited(_setVolumeKeyPageInterceptionEnabled(false));
      unawaited(_restoreSystemReaderBrightness());
      _commitReadingRecordSession();
      return;
    }

    if (_lifecycleDelegate.shouldResumeReaderRuntime(state)) {
      unawaited(_syncVolumeKeyPageInterception());
      unawaited(_applySystemReaderBrightness());
      _maybeStartReadingRecordSession(initialRatio: _currentScrollRatio());
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

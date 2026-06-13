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
    state._membershipAccessService = dependencies.membershipAccessService;
    state._switchSourceSearchService = dependencies.switchSourceSearchService;
    state._searchHitCacheService = dependencies.searchHitCacheService;
    state._sourceHealthService = dependencies.sourceHealthService;
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
    _appThemeMode = ref.read(appThemeModeProvider);
    _activeAdvancedTheme = ref.read(activeAdvancedThemeProvider).valueOrNull;
    _coverGalleries = ref.read(coverGalleriesProvider).valueOrNull ?? const [];
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
    _coverGalleriesSubscription = ref
        .listenManual<AsyncValue<List<CoverGallery>>>(coverGalleriesProvider, (
          _,
          next,
        ) {
          if (!mounted || next.isLoading) {
            return;
          }
          _coverGalleries = next.valueOrNull ?? const [];
        });
    final seed = _pageBootstrapController.resolveSeed(
      bookId: widget.bookId,
      chapterId: widget.chapterId,
      chapterUrl: widget.chapterUrl,
      chapterTitle: widget.chapterTitle,
      sourceId: widget.sourceId,
      detailUrl: widget.detailUrl,
      chapterIndex: widget.chapterIndex,
      bookmarkId: widget.bookmarkId,
    );
    _chapterId = seed.chapterId;
    _chapterUrl = seed.chapterUrl;
    _chapterTitle = seed.chapterTitle;
    _sourceId = seed.sourceId;
    _detailUrl = seed.detailUrl;
    _activeBookId = seed.bookId;
    _cancelBackgroundRefreshConflictForCurrentBook();
    _bookTitle = seed.chapterTitle ?? '';
    _currentIndex = seed.chapterIndex;
    _interactionRuntimeController.lockInitialInteractionUntil(
      DateTime.now().add(_ReaderPageState._kInitialReaderInteractionCooldown),
    );
    final incomingBookmarkId = seed.pendingBookmarkId;
    if (incomingBookmarkId != null) {
      _pendingBookmarkId = incomingBookmarkId;
    }
    _overlayControlsController = AnimationController(
      vsync: this,
      duration: _ReaderPageState._kOverlayControlsShowDuration,
      reverseDuration: _ReaderPageState._kOverlayControlsHideDuration,
      value: _overlayController.showOverlayControls ? 1 : 0,
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
    _crossChapterSnapshotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _crossChapterSnapshotController.addStatusListener(
      _onCrossChapterSnapshotStatus,
    );
    _scrollController.addListener(_onScrollChanged);
    _selectionNotifier.addListener(_handleSelectionNotifierChanged);
    _readerAudioController = ReaderAudioController();
    _readerAudioController.addListener(_handleReaderAudioControllerChanged);
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
    _readerSessionController.cancelAllForDispose();
    _scheduleReaderSessionProviderInvalidation();
    _flushProgressSave();
    _commitReadingRecordSession(
      endRatio: _activeReadingRecordSession?.furthestPositionRatio,
    );
    _syncSystemUiVisibility(force: true, visible: true);
    unawaited(_restoreSystemReaderBrightness());
    _overlayControlsController.stop();
    _pagedTransitionController.stop();
    _curlAutoTurnController.stop();
    _crossChapterSnapshotController.stop();
    _pageTurnRuntimeController.resetPagedTransition();
    _pageTurnRuntimeController.resetCurlTransition(
      pageIndex: _pageTurnRuntimeController.currentPageIndex,
    );
    _clearCrossChapterSnapshotTransition();
    _progressDebounceTimer?.cancel();
    _autoReadResumeTimer?.cancel();
    _autoReadPagedTimer?.cancel();
    _overlayAutoHideTimer?.cancel();
    _systemUiHideTimer?.cancel();
    _readerInfoClockTimer?.cancel();
    _chapterLoadingIndicatorTimer?.cancel();
    _blockingLoadingCardTimer?.cancel();
    _hiddenLoadingPlaceholderTimer?.cancel();
    _readingRecordAutoCommitTimer?.cancel();
    _pointerInputController.dispose();
    _interactionRuntimeController.dispose();
    _volumeKeyEventSubscription?.cancel();
    _appThemeModeSubscription?.close();
    _activeAdvancedThemeSubscription?.close();
    _coverGalleriesSubscription?.close();
    _volumeKeyEventSubscription = null;
    _scrollController.removeListener(_onScrollChanged);
    _selectionNotifier.removeListener(_handleSelectionNotifierChanged);
    _selectionNotifier.dispose();
    _readerAudioController.removeListener(_handleReaderAudioControllerChanged);
    unawaited(_readerAudioController.disposeController());
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
    _crossChapterSnapshotController.dispose();
  }

  void _scheduleReaderSessionProviderInvalidation() {
    final container = _readerSessionProviderContainer;
    final provider = readerSessionControllerProvider(_readerSessionScopeKey);
    Future<void>(() {
      try {
        container.invalidate(provider);
      } catch (_) {
        // 页面释放清理不应影响返回流程；容器已释放时忽略即可。
      }
    });
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
    final decision = _runtimeLifecycleController.resolve(state);
    if (decision.pauseRuntime) {
      _isReaderRuntimeVisible = false;
      _pauseAutoReadForRuntime();
      _flushProgressSave();
      if (_currentContentMode == ReaderContentMode.audio) {
        unawaited(_readerAudioController.pauseForLifecycle());
      }
      unawaited(_setVolumeKeyPageInterceptionEnabled(false));
      unawaited(_restoreSystemReaderBrightness());
      _commitReadingRecordSession();
      return;
    }

    if (decision.resumeRuntime) {
      _isReaderRuntimeVisible = true;
      unawaited(_refreshReaderInfoSnapshot(force: true));
      _scheduleReaderInfoMinuteTick();
      unawaited(_syncVolumeKeyPageInterception());
      unawaited(_applySystemReaderBrightness());
      if (_currentContentMode == ReaderContentMode.audio) {
        unawaited(_readerAudioController.resumeAfterLifecycle());
      }
      _maybeStartReadingRecordSession(initialRatio: _currentScrollRatio());
      if (_isAutoReadPausedByRuntime) {
        _isAutoReadPausedByRuntime = false;
        _autoReadSessionState = ReaderAutoReadSessionState.running;
        _scheduleAutoReadResume();
      }
    }
  }

  Future<void> _applySystemReaderBrightnessImpl([double? brightness]) async {
    final decision = _readerPlatformFacade.resolveBrightness(
      followSystemBrightness: _settings.followSystemBrightness,
      configuredBrightness: brightness ?? _settings.brightness,
    );
    if (decision.action == ReaderBrightnessAction.restoreSystem) {
      await _restoreSystemReaderBrightness();
      return;
    }
    final applied = await _platformBridgeService.setReaderBrightness(
      decision.brightness ?? _settings.brightness,
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

// ignore_for_file: invalid_use_of_protected_member

part of 'reader_page.dart';

extension _ReaderPageBootstrapExtension on _ReaderPageState {
  bool _canBootstrapCurrentChapterWithoutCatalog() {
    final sourceId = (_sourceId ?? '').trim();
    final chapterId = _chapterId.trim();
    final chapterUrl = (_chapterUrl ?? '').trim();
    if (sourceId.isEmpty) {
      return false;
    }
    if (_shouldTryLocalBootstrapPreview()) {
      return false;
    }
    if (LocalReaderIdentity.isLocalSourceId(sourceId)) {
      return chapterId.isNotEmpty && chapterId.toLowerCase() != 'bootstrap';
    }
    return chapterUrl.isNotEmpty;
  }

  Future<bool> _bootstrapCurrentChapterWithoutCatalog() async {
    if (!_canBootstrapCurrentChapterWithoutCatalog()) {
      return false;
    }

    final bootstrapProgress = _bootstrapProgressForCurrentChapter(
      consume: true,
    );
    return _loadCurrentChapter(
      initialScrollRatio: bootstrapProgress?.chapterPositionRatio,
      initialLogicalPosition: bootstrapProgress?.logicalPosition,
    );
  }

  void _scheduleDeferredReaderPostVisibleSync({
    BookDetailLoadResult? detailResult,
    bool refreshBookshelf = true,
  }) {
    unawaited(() async {
      if (detailResult != null) {
        await _persistTocSnapshot(detailResult);
      }
      if (refreshBookshelf) {
        await _refreshBookshelfState();
      }
    }());
  }

  Future<void> _copyLocalReaderDiagnostics() async {
    final localBook = await _localBookRepository.getBookById(_currentBookId);
    final sourcePath = localBook?.sourcePath?.trim() ?? '';
    final storagePath = localBook?.storagePath.trim() ?? '';
    final resolvedStoragePath =
        localBook == null
            ? storagePath
            : await _localBookStorageService.resolveStoragePath(
              localBook.storagePath,
            );
    final sourceExists =
        sourcePath.isNotEmpty ? await File(sourcePath).exists() : false;
    final storageExists =
        resolvedStoragePath.isNotEmpty
            ? await File(resolvedStoragePath).exists()
            : false;
    final content = [
      '本地图书正文诊断',
      'bookId: $_currentBookId',
      'chapterId: $_chapterId',
      'chapterTitle: ${_chapterTitle ?? ''}',
      'sourceId: ${_sourceId ?? ''}',
      'detailUrl: ${_detailUrl ?? ''}',
      'title: $_bookTitle',
      'error: ${_errorText ?? ''}',
      'textPaginationFallbackDiagnostic: ${_textPaginationFallbackDiagnostic ?? ''}',
      if (localBook != null) ...[
        'format: ${localBook.format.name}',
        'indexStatus: ${localBook.indexStatus.name}',
        'chapterCount: ${localBook.chapterCount}',
        'charset: ${localBook.charset ?? ''}',
        'sourceFile: ${sourcePath.isEmpty ? '未记录' : sourcePath}',
        'sourceExists: $sourceExists',
        'storageFile: ${storagePath.isEmpty ? '未记录' : storagePath}',
        if (resolvedStoragePath.isNotEmpty &&
            resolvedStoragePath != storagePath)
          'resolvedStorageFile: $resolvedStoragePath',
        'storageExists: $storageExists',
        if ((localBook.lastError?.trim().isNotEmpty ?? false))
          'lastError: ${localBook.lastError!.trim()}',
      ],
    ].join('\n');
    await Clipboard.setData(ClipboardData(text: content));
    if (!mounted) {
      return;
    }
    _showMessage('已复制本地图书诊断信息。');
  }

  Future<void> _refreshReaderInfoSnapshot({bool force = false}) async {
    final now = DateTime.now();

    int? batteryLevel;
    var batteryReadFailed = _readerBatteryReadFailed;
    final shouldPollBattery = _runtimeWakePolicy.shouldPollBattery(
      force: force,
      infoShowBattery: _settings.infoShowBattery,
      lastReadAt: _lastReaderBatteryRefreshAt,
      now: now,
    );
    if (shouldPollBattery) {
      final shouldSkipBatteryRead = await _shouldSkipBatteryRead();
      if (shouldSkipBatteryRead) {
        batteryReadFailed = true;
        batteryLevel = null;
      } else {
        try {
          batteryLevel = await _battery.batteryLevel;
          batteryReadFailed = false;
        } catch (_) {
          batteryReadFailed = true;
          batteryLevel = null;
        }
      }
    } else {
      batteryLevel = _readerBatteryLevel;
    }

    if (!mounted) {
      return;
    }

    final shouldUpdateTime =
        force ||
        now.year != _readerInfoNow.year ||
        now.month != _readerInfoNow.month ||
        now.day != _readerInfoNow.day ||
        now.hour != _readerInfoNow.hour ||
        now.minute != _readerInfoNow.minute;

    final shouldUpdateBattery =
        force ||
        batteryLevel != _readerBatteryLevel ||
        batteryReadFailed != _readerBatteryReadFailed;

    if (!shouldUpdateTime && !shouldUpdateBattery) {
      return;
    }

    setState(() {
      _readerInfoNow = now;
      _readerBatteryLevel = batteryLevel;
      _readerBatteryReadFailed = batteryReadFailed;
      if (shouldPollBattery) {
        _lastReaderBatteryRefreshAt = now;
      }
    });
    _pauseAutoReadIfRuntimePolicyRequires();
  }

  Future<bool> _shouldSkipBatteryRead() async {
    if (kIsWeb || !Platform.isIOS) {
      return false;
    }
    _iosSimulatorCheck ??= _loadIsIosSimulator();
    return _iosSimulatorCheck!;
  }

  Future<bool> _loadIsIosSimulator() async {
    try {
      final iosInfo = await _deviceInfo.iosInfo;
      return !iosInfo.isPhysicalDevice;
    } catch (_) {
      return false;
    }
  }

  Future<void> _applyPresentedBookMetadata({
    String? fallbackTitle,
    String? fallbackAuthor,
    String? fallbackIntro,
    String? realCoverUrl,
    String? sourceId,
    String? detailUrl,
    bool allowSetState = true,
  }) async {
    final resolvedSourceId = (sourceId ?? _sourceId ?? '').trim();
    final resolvedDetailUrl = (detailUrl ?? _detailUrl ?? '').trim();
    final localBook =
        _isLocalContent
            ? await _localBookRepository.getBookById(_currentBookId)
            : null;
    final metadataOverride =
        !_isLocalContent &&
                resolvedSourceId.isNotEmpty &&
                resolvedDetailUrl.isNotEmpty
            ? await _bookMetadataOverrideRepository.getByRemoteBook(
              sourceId: resolvedSourceId,
              detailUrl: resolvedDetailUrl,
            )
            : null;
    final presentation = _bookMetadataPresentationResolver.resolve(
      fallbackTitle: fallbackTitle ?? _bookTitle,
      fallbackAuthor: fallbackAuthor ?? _bookAuthor,
      fallbackIntro: fallbackIntro,
      realCoverUrl: realCoverUrl ?? _bookCoverUrl,
      localBook: localBook,
      metadataOverride: metadataOverride,
    );
    if (!mounted || !allowSetState) {
      _bookTitle = presentation.displayTitle;
      _bookAuthor = presentation.displayAuthor;
      _bookCoverUrl = presentation.realCoverUrl;
      _bookCustomCoverPath = presentation.customCoverPath;
      return;
    }
    setState(() {
      _bookTitle = presentation.displayTitle;
      _bookAuthor = presentation.displayAuthor;
      _bookCoverUrl = presentation.realCoverUrl;
      _bookCustomCoverPath = presentation.customCoverPath;
    });
  }

  Future<void> _bootstrap() async {
    _cancelBackgroundRefreshConflictForCurrentBook();
    final bootstrapStopwatch = Stopwatch()..start();
    final tapToBootstrapStartMs = _tapTraceElapsedMs();
    var progressLoadMs = 0;
    var progressHit = false;
    var tocSnapshotLoadMs = 0;
    var tocSnapshotHit = false;
    var visibleCacheLoadMs = 0;
    var visibleCacheHit = false;
    var detailCacheHit = false;
    var detailLoadMs = 0;
    var detailLoaded = false;
    var localBootstrapPreviewAttempted = false;
    var localBootstrapPreviewLoaded = false;
    var chapterLoadMs = 0;
    var chapterLoaded = false;
    var bootstrapSucceeded = false;
    int? tapToVisibleMs;
    _logger.info(
      'Reader bootstrap started',
      context: <String, Object?>{
        'chain': 'reader_open',
        'step': 'bootstrap_start',
        'bookId': _currentBookId,
        'sourceId': _sourceId,
        'detailUrl': _detailUrl,
        'chapterId': _chapterId,
        'openRouteKind': widget.openRouteKind,
        'tapToBootstrapStartMs': tapToBootstrapStartMs,
      },
    );
    try {
      final loadedSettingsFuture = _preferencesService.loadSettings();
      final loadedVisualOverridesFuture =
          _visualOverridesService.loadOverrides();
      final progressFuture = _preferencesService.loadProgress(_currentBookId);

      final progressLoadStopwatch = Stopwatch()..start();
      final progress = await progressFuture;
      progressLoadMs = progressLoadStopwatch.elapsedMilliseconds;
      _bootstrapProgress = progress;
      progressHit = progress != null;

      if (progress != null) {
        _applyProgressFallback(progress);
      }

      _applyLocalSchemeFallback();
      final visibleCacheStopwatch = Stopwatch()..start();
      final hydratedVisibleContent = await _tryHydrateVisibleContentFromCache();
      visibleCacheLoadMs = visibleCacheStopwatch.elapsedMilliseconds;
      visibleCacheHit = hydratedVisibleContent;
      if (_hasVisibleReaderContent) {
        tapToVisibleMs ??= _tapTraceElapsedMs();
      } else {
        _scheduleHiddenLoadingPlaceholder();
      }

      final loadedSettings = await loadedSettingsFuture;
      var normalizedSettings = _typographyMetricsResolver.normalizeSettings(
        loadedSettings,
      );
      var loadedVisualOverrides = await loadedVisualOverridesFuture;
      normalizedSettings = _typographyMetricsResolver.normalizeSettings(
        normalizedSettings,
      );

      var infoSettingsChanged = false;
      if (!normalizedSettings.infoShowTime &&
          !normalizedSettings.infoShowBattery &&
          !normalizedSettings.infoShowProgress) {
        normalizedSettings = normalizedSettings.copyWith(
          infoShowProgress: true,
        );
        infoSettingsChanged = true;
      }
      if (normalizedSettings.infoHeaderEnabled) {
        normalizedSettings = normalizedSettings.copyWith(
          infoHeaderEnabled: false,
          infoHeaderDividerEnabled: false,
        );
        infoSettingsChanged = true;
      }
      if (!normalizedSettings.infoHeaderEnabled &&
          normalizedSettings.infoHeaderDividerEnabled) {
        normalizedSettings = normalizedSettings.copyWith(
          infoHeaderDividerEnabled: false,
        );
        infoSettingsChanged = true;
      }
      if (!normalizedSettings.infoFooterEnabled &&
          normalizedSettings.infoFooterDividerEnabled) {
        normalizedSettings = normalizedSettings.copyWith(
          infoFooterDividerEnabled: false,
        );
        infoSettingsChanged = true;
      }

      final fontSettingsChanged =
          normalizedSettings.fontSource != loadedSettings.fontSource ||
          normalizedSettings.fontFamilyKey != loadedSettings.fontFamilyKey ||
          normalizedSettings.customFontPath != loadedSettings.customFontPath;
      final typographySettingsChanged =
          normalizedSettings.lineHeight != loadedSettings.lineHeight ||
          normalizedSettings.paragraphSpacing !=
              loadedSettings.paragraphSpacing ||
          normalizedSettings.paragraphIndent !=
              loadedSettings.paragraphIndent ||
          normalizedSettings.letterSpacing != loadedSettings.letterSpacing;
      if (fontSettingsChanged ||
          infoSettingsChanged ||
          typographySettingsChanged) {
        await _preferencesService.saveSettings(normalizedSettings);
      }

      _persistedReaderSettings = normalizedSettings;
      _visualOverrides = loadedVisualOverrides;
      final activeTheme = _currentActiveAdvancedTheme();
      final appThemeMode = _currentAppThemeMode();
      final platformBrightness = _currentPlatformBrightness();
      final bootSettings = _resolveReaderSettingsLayers(
        persistedSettings: normalizedSettings,
        visualOverrides: loadedVisualOverrides,
        activeTheme: activeTheme,
        appThemeMode: appThemeMode,
        platformBrightness: platformBrightness,
      ).copyWith(autoReadEnabled: false);
      _debugLogReaderBackground('bootstrap', bootSettings);
      if (mounted) {
        setState(() {
          _persistedReaderSettings = normalizedSettings;
          _visualOverrides = loadedVisualOverrides;
          _settings = bootSettings;
          _customFonts = const <ReaderCustomFontEntry>[];
          _customBackgroundImages = const <String>[];
        });
        unawaited(_applySystemReaderBrightness(bootSettings.brightness));
        unawaited(_syncVolumeKeyPageInterception());
      } else {
        _settings = bootSettings;
        _customFonts = const <ReaderCustomFontEntry>[];
        _customBackgroundImages = const <String>[];
        unawaited(_applySystemReaderBrightness(bootSettings.brightness));
      }
      unawaited(_runDeferredBootstrapWarmup());
      final tocSnapshotStopwatch = Stopwatch()..start();
      final hydratedTocSnapshot = await _tryHydrateTocSnapshot();
      tocSnapshotLoadMs = tocSnapshotStopwatch.elapsedMilliseconds;
      tocSnapshotHit = hydratedTocSnapshot;

      if (hydratedTocSnapshot) {
        if (_hasVisibleReaderContent) {
          bootstrapSucceeded = true;
          _scheduleDeferredReaderPostVisibleSync();
          await _consumePendingBookmarkJump();
          return;
        }

        final bootstrapProgress = _bootstrapProgressForCurrentChapter(
          consume: true,
        );
        final chapterLoadStopwatch = Stopwatch()..start();
        final loaded = await _loadCurrentChapter(
          initialScrollRatio: bootstrapProgress?.chapterPositionRatio,
          initialLogicalPosition: bootstrapProgress?.logicalPosition,
        );
        chapterLoadMs = chapterLoadStopwatch.elapsedMilliseconds;
        chapterLoaded = loaded;
        bootstrapSucceeded = loaded;
        if (loaded && _hasVisibleReaderContent) {
          tapToVisibleMs ??= _tapTraceElapsedMs();
        }
        if (loaded) {
          _scheduleDeferredReaderPostVisibleSync();
          await _consumePendingBookmarkJump();
        }
        return;
      }

      if (_shouldTryLocalBootstrapPreview()) {
        localBootstrapPreviewAttempted = true;
        final bootstrapProgress = _bootstrapProgressForCurrentChapter(
          consume: true,
        );
        final chapterLoadStopwatch = Stopwatch()..start();
        final loaded = await _loadCurrentChapter(
          initialScrollRatio: bootstrapProgress?.chapterPositionRatio,
          initialLogicalPosition: bootstrapProgress?.logicalPosition,
        );
        chapterLoadMs = chapterLoadStopwatch.elapsedMilliseconds;
        chapterLoaded = loaded;
        bootstrapSucceeded = loaded;
        localBootstrapPreviewLoaded = loaded;
        if (loaded && _hasVisibleReaderContent) {
          tapToVisibleMs ??= _tapTraceElapsedMs();
        }
        if (loaded) {
          _scheduleDeferredReaderPostVisibleSync();
          await _consumePendingBookmarkJump();
          return;
        }
      }

      if (_canBootstrapCurrentChapterWithoutCatalog()) {
        final chapterLoadStopwatch = Stopwatch()..start();
        final loaded = await _bootstrapCurrentChapterWithoutCatalog();
        chapterLoadMs = chapterLoadStopwatch.elapsedMilliseconds;
        chapterLoaded = loaded;
        bootstrapSucceeded = loaded;
        if (loaded && _hasVisibleReaderContent) {
          tapToVisibleMs ??= _tapTraceElapsedMs();
          _scheduleDeferredReaderPostVisibleSync();
          await _consumePendingBookmarkJump();
          unawaited(_hydrateCatalogAfterVisible());
          return;
        }
      }

      if (_isMissingCriticalParams) {
        if (!mounted) {
          return;
        }
        setState(() {
          _errorText = '缺少 sourceId/detailUrl，无法加载正文。';
          _isBootstrapping = false;
        });
        return;
      }

      final detailProvider = _requireContentProvider(
        sourceId: _sourceId,
        stage: ErrorStage.detail,
      );

      final cachedDetail = _peekCachedDetailResult();
      detailCacheHit = cachedDetail != null;
      final detailResult =
          cachedDetail ??
          await () async {
            final detailLoadStopwatch = Stopwatch()..start();
            final loaded = await detailProvider.loadDetail(
              sourceId: _sourceId!,
              bookId: _currentBookId,
              detailUrl: _detailUrl!,
              fallbackTitle: _chapterTitle,
            );
            detailLoadMs = detailLoadStopwatch.elapsedMilliseconds;
            return loaded;
          }();
      detailLoaded = true;
      _scheduleDeferredReaderPostVisibleSync(
        detailResult: detailResult,
        refreshBookshelf: false,
      );

      _bookTitle = detailResult.detail.title;
      _bookAuthor = detailResult.detail.author;
      _bookCoverUrl = detailResult.detail.coverUrl;
      _bookCustomCoverPath = null;
      _chapters = detailResult.chapters;
      _currentIndex = _resolveCurrentIndex(_chapters);
      await _applyPresentedBookMetadata(
        fallbackTitle: detailResult.detail.title,
        fallbackAuthor: detailResult.detail.author,
        realCoverUrl: detailResult.detail.coverUrl,
      );

      if (_currentIndex == null) {
        if (!mounted) {
          return;
        }
        setState(() {
          _errorText = _resolveNoReadableChapterMessage(
            localBootstrapPreviewAttempted: localBootstrapPreviewAttempted,
          );
          _isBootstrapping = false;
        });
        return;
      }

      final current = _chapters[_currentIndex!];
      _chapterId = current.id;
      _chapterUrl = current.chapterUrl;
      _chapterTitle = current.title;

      final bootstrapProgress = _bootstrapProgressForCurrentChapter(
        consume: true,
      );
      final chapterLoadStopwatch = Stopwatch()..start();
      final loaded = await _loadCurrentChapter(
        initialScrollRatio: bootstrapProgress?.chapterPositionRatio,
        initialLogicalPosition: bootstrapProgress?.logicalPosition,
      );
      chapterLoadMs = chapterLoadStopwatch.elapsedMilliseconds;
      chapterLoaded = loaded;
      bootstrapSucceeded = loaded;
      if (loaded && _hasVisibleReaderContent) {
        tapToVisibleMs ??= _tapTraceElapsedMs();
      }
      if (loaded) {
        _scheduleDeferredReaderPostVisibleSync();
        await _consumePendingBookmarkJump();
      }
    } on AppException catch (error) {
      if (!mounted) {
        return;
      }
      final readableError = _toUserReadableError(error);
      _recordReaderFailure(message: readableError, errorCode: error.code);
      setState(() {
        _errorText = readableError;
      });
      _maybePromptSwitchSourceForMissingSource(error.code);
    } catch (_) {
      if (!mounted) {
        return;
      }
      const fallbackError = '阅读器初始化失败。';
      _recordReaderFailure(message: fallbackError);
      setState(() {
        _errorText = fallbackError;
      });
    } finally {
      _logger.info(
        'Reader bootstrap finished',
        context: <String, Object?>{
          'chain': 'reader_open',
          'step': 'bootstrap_finish',
          'bookId': _currentBookId,
          'sourceId': _sourceId,
          'detailUrl': _detailUrl,
          'chapterId': _chapterId,
          'openRouteKind': widget.openRouteKind,
          'success': bootstrapSucceeded,
          'progressHit': progressHit,
          'tocSnapshotHit': tocSnapshotHit,
          'visibleCacheHit': visibleCacheHit,
          'detailCacheHit': detailCacheHit,
          'detailLoaded': detailLoaded,
          'localBootstrapPreviewAttempted': localBootstrapPreviewAttempted,
          'localBootstrapPreviewLoaded': localBootstrapPreviewLoaded,
          'chapterLoaded': chapterLoaded,
          'progressLoadMs': progressLoadMs,
          'tocSnapshotLoadMs': tocSnapshotLoadMs,
          'visibleCacheLoadMs': visibleCacheLoadMs,
          'detailLoadMs': detailLoadMs,
          'chapterLoadMs': chapterLoadMs,
          'totalMs': bootstrapStopwatch.elapsedMilliseconds,
          'tapToVisibleMs': tapToVisibleMs,
          'tapToBootstrapDoneMs': _tapTraceElapsedMs(),
          'hasVisibleReaderContent': _hasVisibleReaderContent,
          'errorText': _errorText,
        },
      );
      _clearDelayedLoadingUi();
      if (mounted) {
        setState(() {
          _isBootstrapping = false;
        });
        unawaited(_syncVolumeKeyPageInterception());
        _scheduleReadingRecordSessionStart(initialRatio: _currentScrollRatio());
        _reconcileAutoRead(restart: true);
      }
    }
  }

  int? _tapTraceElapsedMs() {
    final requestedAtMs = widget.openRequestedAtMs;
    if (requestedAtMs == null || requestedAtMs <= 0) {
      return null;
    }
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (nowMs < requestedAtMs) {
      return null;
    }
    return nowMs - requestedAtMs;
  }

  Future<void> _runDeferredBootstrapWarmup() async {
    final fontRestoreFuture = () async {
      await _fontRegistryService.restoreRegisteredFonts();
      return _fontRegistryService.listRegisteredFonts();
    }();
    final customBackgroundsFuture = _loadUnifiedCustomBackgrounds();
    final recentColorsFuture = _preferencesService.loadRecentBodyTextColors();
    final autoSwitchSourceOnFailureFuture =
        _systemSettingsService.loadAutoSwitchSourceOnFailureEnabled();
    final readingRecordEnabledFuture =
        _systemSettingsService.loadReadRecordEnabled();

    var availableCustomFonts = const <ReaderCustomFontEntry>[];
    var availableCustomBackgrounds = const <String>[];
    var recentColors = const <int>[];
    var autoSwitchSourceOnFailureEnabled = false;
    var readingRecordEnabled = true;

    try {
      availableCustomFonts = await fontRestoreFuture;
    } catch (_) {
      availableCustomFonts = const <ReaderCustomFontEntry>[];
    }
    try {
      availableCustomBackgrounds = await customBackgroundsFuture;
    } catch (_) {
      availableCustomBackgrounds = const <String>[];
    }
    try {
      recentColors = await recentColorsFuture;
    } catch (_) {
      recentColors = const <int>[];
    }
    try {
      autoSwitchSourceOnFailureEnabled = await autoSwitchSourceOnFailureFuture;
    } catch (_) {
      autoSwitchSourceOnFailureEnabled = false;
    }
    try {
      readingRecordEnabled = await readingRecordEnabledFuture;
    } catch (_) {
      readingRecordEnabled = true;
    }

    if (!mounted) {
      _customFonts = availableCustomFonts;
      _customBackgroundImages = availableCustomBackgrounds;
      _recentBodyTextColors = recentColors;
      _autoSwitchSourceOnFailureEnabled = autoSwitchSourceOnFailureEnabled;
      _readingRecordEnabled = readingRecordEnabled;
      return;
    }

    setState(() {
      _customFonts = availableCustomFonts;
      _customBackgroundImages = availableCustomBackgrounds;
      _recentBodyTextColors = recentColors;
      _autoSwitchSourceOnFailureEnabled = autoSwitchSourceOnFailureEnabled;
      _readingRecordEnabled = readingRecordEnabled;
    });
    unawaited(_preloadCustomBackgroundPreviews(availableCustomBackgrounds));
  }

  Future<void> _hydrateCatalogAfterVisible() async {
    final sourceId = (_sourceId ?? '').trim();
    final detailUrl = (_detailUrl ?? '').trim();
    if (sourceId.isEmpty ||
        detailUrl.isEmpty ||
        _chapters.isNotEmpty ||
        !mounted) {
      return;
    }
    try {
      final detailProvider = _requireContentProvider(
        sourceId: _sourceId,
        stage: ErrorStage.detail,
      );
      final detailResult = await detailProvider.loadDetail(
        sourceId: sourceId,
        bookId: _currentBookId,
        detailUrl: detailUrl,
        fallbackTitle: _chapterTitle,
      );
      if (!mounted || detailResult.chapters.isEmpty) {
        return;
      }
      final resolvedIndex = _resolveCurrentIndex(detailResult.chapters);
      if (resolvedIndex == null) {
        return;
      }
      final current = detailResult.chapters[resolvedIndex];
      setState(() {
        _bookTitle = detailResult.detail.title;
        _bookAuthor = detailResult.detail.author;
        _bookCoverUrl = detailResult.detail.coverUrl;
        _bookCustomCoverPath = null;
        _chapters = detailResult.chapters;
        _currentIndex = resolvedIndex;
        _chapterId = current.id;
        _chapterUrl = current.chapterUrl;
        _chapterTitle = current.title;
      });
      await _applyPresentedBookMetadata(
        fallbackTitle: detailResult.detail.title,
        fallbackAuthor: detailResult.detail.author,
        realCoverUrl: detailResult.detail.coverUrl,
      );
      _scheduleDeferredReaderPostVisibleSync(
        detailResult: detailResult,
        refreshBookshelf: false,
      );
    } catch (_) {
      // Ignore post-visible catalog hydration failures.
    }
  }

  bool _shouldTryLocalBootstrapPreview() {
    if (!_isLocalSource) {
      return false;
    }
    if (_chapterId.trim().toLowerCase() != 'bootstrap') {
      return false;
    }
    return (_chapterUrl ?? '').trim().isNotEmpty;
  }

  BookDetailLoadResult? _peekCachedDetailResult() {
    final sourceId = (_sourceId ?? '').trim();
    final detailUrl = (_detailUrl ?? '').trim();
    if (sourceId.isEmpty || detailUrl.isEmpty) {
      return null;
    }
    final provider = _contentProviderRegistry.findForSourceId(sourceId);
    if (provider is! SourceContentProvider) {
      return null;
    }
    return provider.peekCachedDetail(sourceId: sourceId, detailUrl: detailUrl);
  }

  String _resolveNoReadableChapterMessage({
    required bool localBootstrapPreviewAttempted,
  }) {
    if (_isLocalSource && localBootstrapPreviewAttempted) {
      return '本地图书目录尚未建立完成，预览正文也暂不可用，请稍后重试或等待后台索引完成。';
    }
    if (_isLocalSource) {
      return '本地图书目录尚未建立完成，请稍后重试或先完成索引。';
    }
    return '当前目录没有可阅读的正文章节。';
  }

  Future<bool> _tryHydrateTocSnapshot() async {
    final sourceId = (_sourceId ?? '').trim();
    final detailUrl = (_detailUrl ?? '').trim();
    if (sourceId.isEmpty || detailUrl.isEmpty) {
      return false;
    }

    try {
      final snapshot = await _preferencesService.loadTocSnapshot(
        sourceId: sourceId,
        detailUrl: detailUrl,
      );
      if (snapshot == null || snapshot.chapters.isEmpty) {
        return false;
      }

      final chapters = snapshot.chapters;
      final resolvedIndex = _resolveCurrentIndex(chapters);
      if (resolvedIndex == null) {
        return false;
      }
      final current = chapters[resolvedIndex];

      if (mounted) {
        setState(() {
          _bookTitle = snapshot.title;
          _bookAuthor = snapshot.author;
          _bookCoverUrl = snapshot.coverUrl;
          _bookCustomCoverPath = null;
          _chapters = chapters;
          _currentIndex = resolvedIndex;
          _chapterId = current.id;
          _chapterUrl = current.chapterUrl;
          _chapterTitle = current.title;
          _errorText = null;
        });
      } else {
        _bookTitle = snapshot.title;
        _bookAuthor = snapshot.author;
        _bookCoverUrl = snapshot.coverUrl;
        _bookCustomCoverPath = null;
        _chapters = chapters;
        _currentIndex = resolvedIndex;
        _chapterId = current.id;
        _chapterUrl = current.chapterUrl;
        _chapterTitle = current.title;
        _errorText = null;
      }

      await _applyPresentedBookMetadata(
        fallbackTitle: snapshot.title,
        fallbackAuthor: snapshot.author,
        realCoverUrl: snapshot.coverUrl,
        sourceId: sourceId,
        detailUrl: detailUrl,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _persistTocSnapshot(BookDetailLoadResult detailResult) async {
    final sourceId = (_sourceId ?? '').trim();
    final detailUrl = (_detailUrl ?? '').trim();
    if (sourceId.isEmpty ||
        detailUrl.isEmpty ||
        detailResult.chapters.isEmpty ||
        detailResult.detail.title.trim().isEmpty) {
      return;
    }

    try {
      await _preferencesService.saveTocSnapshot(
        ReaderTocSnapshot(
          bookId: _currentBookId,
          sourceId: sourceId,
          detailUrl: detailUrl,
          title: detailResult.detail.title,
          author: detailResult.detail.author,
          coverUrl: detailResult.detail.coverUrl,
          chapters: detailResult.chapters,
          updatedAt: DateTime.now(),
        ),
      );
      await _applyPresentedBookMetadata(
        fallbackTitle: detailResult.detail.title,
        fallbackAuthor: detailResult.detail.author,
        fallbackIntro: null,
        realCoverUrl: detailResult.detail.coverUrl,
        sourceId: sourceId,
        detailUrl: detailUrl,
      );
    } catch (_) {
      // Ignore snapshot persistence failures.
    }
  }

  Future<String?> _resolveCurrentBookCustomCoverPath() async {
    if (!_isLocalContent) {
      return null;
    }
    final localBook = await _localBookRepository.getBookById(_currentBookId);
    final path = localBook?.coverPath?.trim() ?? '';
    return path.isEmpty ? null : path;
  }
}

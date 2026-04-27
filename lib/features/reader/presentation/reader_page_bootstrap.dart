// ignore_for_file: invalid_use_of_protected_member

part of 'reader_page.dart';

extension _ReaderPageBootstrapExtension on _ReaderPageState {
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
    var batteryReadFailed = false;
    final shouldSkipBatteryRead = await _shouldSkipBatteryRead();
    if (shouldSkipBatteryRead) {
      batteryReadFailed = true;
    } else {
      try {
        batteryLevel = await _battery.batteryLevel;
      } catch (_) {
        batteryReadFailed = true;
        batteryLevel = null;
      }
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
    });
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
    try {
      final loadedSettings = await _preferencesService.loadSettings();
      var normalizedSettings = _typographyMetricsResolver.normalizeSettings(
        loadedSettings,
      );
      var availableCustomFonts = const <ReaderCustomFontEntry>[];
      var storedCustomBackgrounds = const <String>[];

      try {
        storedCustomBackgrounds = await _loadUnifiedCustomBackgrounds();
      } catch (_) {
        storedCustomBackgrounds = const <String>[];
      }

      try {
        await _fontRegistryService.restoreRegisteredFonts();
        availableCustomFonts = await _fontRegistryService.listRegisteredFonts();
        normalizedSettings = await _fontRegistryService
            .normalizeCustomFontSettings(loadedSettings);
      } catch (_) {
        normalizedSettings = loadedSettings.copyWith(
          fontSource: ReaderFontSource.system,
          clearFontFamilyKey: true,
          clearCustomFontPath: true,
        );
      }

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
      if (normalizedSettings.infoShowChapter) {
        normalizedSettings = normalizedSettings.copyWith(
          infoShowChapter: false,
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

      final bootSettings = normalizedSettings.copyWith(autoReadEnabled: false);
      _debugLogReaderBackground('bootstrap', bootSettings);
      if (mounted) {
        setState(() {
          _settings = bootSettings;
          _customFonts = availableCustomFonts;
          _customBackgroundImages = storedCustomBackgrounds;
        });
        unawaited(_preloadCustomBackgroundPreviews(storedCustomBackgrounds));
        unawaited(_applySystemReaderBrightness(bootSettings.brightness));
        unawaited(_syncVolumeKeyPageInterception());
      } else {
        _settings = bootSettings;
        _customFonts = availableCustomFonts;
        _customBackgroundImages = storedCustomBackgrounds;
        unawaited(_preloadCustomBackgroundPreviews(storedCustomBackgrounds));
        unawaited(_applySystemReaderBrightness(bootSettings.brightness));
      }
      await _syncReaderThemeModeWithAppTheme(
        ref.read(appThemeModeProvider),
        persist: true,
      );
      try {
        final recentColors =
            await _preferencesService.loadRecentBodyTextColors();
        if (mounted) {
          setState(() {
            _recentBodyTextColors = recentColors;
          });
        } else {
          _recentBodyTextColors = recentColors;
        }
      } catch (_) {
        _recentBodyTextColors = const <int>[];
      }
      try {
        _autoSwitchSourceOnFailureEnabled =
            await _systemSettingsService.loadAutoSwitchSourceOnFailureEnabled();
      } catch (_) {
        _autoSwitchSourceOnFailureEnabled = false;
      }
      try {
        _readingRecordEnabled =
            await _systemSettingsService.loadReadRecordEnabled();
      } catch (_) {
        _readingRecordEnabled = true;
      }

      final progress = await _preferencesService.loadProgress(_currentBookId);
      _bootstrapProgress = progress;

      if (progress != null) {
        _applyProgressFallback(progress);
      }

      _applyLocalSchemeFallback();
      final hydratedTocSnapshot = await _tryHydrateTocSnapshot();
      await _tryHydrateVisibleContentFromCache();

      if (hydratedTocSnapshot) {
        await _refreshBookshelfState();
        if (_hasVisibleReaderContent) {
          await _consumePendingBookmarkJump();
          return;
        }

        final bootstrapProgress = _bootstrapProgressForCurrentChapter(
          consume: true,
        );
        final loaded = await _loadCurrentChapter(
          initialScrollRatio: bootstrapProgress?.chapterPositionRatio,
          initialLogicalPosition: bootstrapProgress?.logicalPosition,
        );
        if (loaded) {
          await _consumePendingBookmarkJump();
        }
        return;
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

      final detailResult = await detailProvider.loadDetail(
        sourceId: _sourceId!,
        bookId: _currentBookId,
        detailUrl: _detailUrl!,
        fallbackTitle: _chapterTitle,
      );
      await _persistTocSnapshot(detailResult);

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
          _errorText = '当前目录没有可阅读的正文章节。';
          _isBootstrapping = false;
        });
        return;
      }

      final current = _chapters[_currentIndex!];
      _chapterId = current.id;
      _chapterUrl = current.chapterUrl;
      _chapterTitle = current.title;

      await _refreshBookshelfState();
      final bootstrapProgress = _bootstrapProgressForCurrentChapter(
        consume: true,
      );
      final loaded = await _loadCurrentChapter(
        initialScrollRatio: bootstrapProgress?.chapterPositionRatio,
        initialLogicalPosition: bootstrapProgress?.logicalPosition,
      );
      if (loaded) {
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

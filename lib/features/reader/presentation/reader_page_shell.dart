// ignore_for_file: invalid_use_of_protected_member

part of 'reader_page.dart';

extension _ReaderPageShellExtension on _ReaderPageState {
  bool get _shouldEnableVolumeKeyPageInterception {
    if (!_platformBridgeService.isVolumeKeyPagingSupported) {
      return false;
    }
    if (!_settings.volumeKeyPageEnabled) {
      return false;
    }
    if (_showOverlayControls || _isTextSelectionActive) {
      return false;
    }
    if (_isBootstrapping || _isLoadingContent || _errorText != null) {
      return false;
    }
    return true;
  }

  String get _volumeKeyPageSupportDescription {
    return _platformBridgeService.volumeKeyPagingSupportDescription;
  }

  Future<void> _syncVolumeKeyPageInterception() async {
    await _setVolumeKeyPageInterceptionEnabled(
      _shouldEnableVolumeKeyPageInterception,
    );
  }

  Future<void> _setVolumeKeyPageInterceptionEnabled(bool enabled) async {
    if (_isVolumeKeyPageInterceptionEnabled == enabled) {
      return;
    }
    _isVolumeKeyPageInterceptionEnabled = enabled;
    await _platformBridgeService.setVolumeKeyPagingEnabled(enabled);
  }

  KeyEventResult _handleReaderKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    if (_isTextSelectionActive || _isEditingBookmarkNote) {
      return KeyEventResult.ignored;
    }
    if (_isBootstrapping || _isLoadingContent || _errorText != null) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      if (_showOverlayControls) {
        _hideOverlayControls(resumeAutoRead: true);
      } else {
        _setOverlayControlsVisibility(true);
      }
      return KeyEventResult.handled;
    }

    if (_showOverlayControls) {
      return KeyEventResult.ignored;
    }
    if (_isAutoReadSessionEnabled) {
      _pauseAutoReadSession(showMessage: true);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.pageUp) {
      unawaited(_turnReaderByDirection(forward: false));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.pageDown) {
      unawaited(_turnReaderByDirection(forward: true));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.home) {
      _restoreScrollPosition(0);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.end) {
      _restoreScrollPosition(1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _handleReaderPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) {
      return;
    }
    if (_currentViewportKind != ReaderModeViewportKind.textPaged &&
        _currentViewportKind != ReaderModeViewportKind.imagePaged) {
      return;
    }
    if (_showOverlayControls || _isTextSelectionActive) {
      return;
    }
    final delta = event.scrollDelta.dy;
    if (delta.abs() < 8) {
      return;
    }
    final now = DateTime.now();
    final lastAt = _lastPointerScrollPageTurnAt;
    if (lastAt != null && now.difference(lastAt).inMilliseconds < 180) {
      return;
    }
    _lastPointerScrollPageTurnAt = now;
    unawaited(_turnReaderByDirection(forward: delta > 0));
  }

  Future<void> _handleVolumeKeyEvent(ReaderVolumeKeyEvent event) async {
    if (!mounted || !_settings.volumeKeyPageEnabled) {
      return;
    }
    if (_showOverlayControls || _isTextSelectionActive) {
      return;
    }
    if (_isBootstrapping || _isLoadingContent || _errorText != null) {
      return;
    }
    if (event.repeatCount > 0) {
      return;
    }
    final shouldResumeAutoRead =
        _isAutoReadSessionEnabled &&
        _autoReadSessionState == ReaderAutoReadSessionState.running;
    if (shouldResumeAutoRead) {
      _pauseAutoReadSession(showMessage: false);
    }

    if (event.direction == ReaderVolumeKeyDirection.up) {
      await _turnReaderByDirection(forward: false);
    } else {
      await _turnReaderByDirection(forward: true);
    }

    if (shouldResumeAutoRead &&
        mounted &&
        _isAutoReadSessionEnabled &&
        _autoReadSessionState == ReaderAutoReadSessionState.paused) {
      _resumeAutoReadSession(showMessage: false);
    }
  }

  Future<void> _turnReaderByDirection({
    required bool forward,
    bool includeMangaPaged = true,
  }) async {
    if (_showOverlayControls) {
      _hideOverlayControls(resumeAutoRead: false);
    }
    switch (_currentViewportKind) {
      case ReaderModeViewportKind.imagePaged:
        if (includeMangaPaged) {
          await _turnMangaPage(forward: forward);
        }
        return;
      case ReaderModeViewportKind.hybridPaged:
        if (includeMangaPaged) {
          await _turnMangaPage(forward: forward);
        }
        return;
      case ReaderModeViewportKind.textPaged:
        await _turnPagedTextPage(direction: forward ? 1 : -1);
        return;
      case ReaderModeViewportKind.textScroll:
        if (_settings.pageTurnMode.usesScrollLayout) {
          await _advanceScrollReaderByStep(forward: forward);
        }
        return;
      case ReaderModeViewportKind.imageScroll:
        return;
    }
  }

  Future<void> _advanceScrollReaderByStep({required bool forward}) async {
    if (!_scrollController.hasClients || _isScrollStepAnimating) {
      return;
    }

    final position = _scrollController.position;
    final viewport = position.viewportDimension;
    final lineReserve =
        (_settings.fontSize *
                _typographyMetricsResolver.resolveLineHeight(_settings))
            .clamp(18.0, viewport * 0.22)
            .toDouble();
    final imageReserve = _document.hasImageBlocks ? 0.0 : lineReserve;
    final distance =
        (viewport * _settings.pageTurnStepRatio - imageReserve)
            .clamp(120.0, max(viewport - imageReserve, 120.0))
            .toDouble();
    final current = position.pixels;
    final target =
        forward
            ? min(current + distance, position.maxScrollExtent)
            : max(current - distance, 0.0);

    if ((target - current).abs() >= 1.0) {
      _isScrollStepAnimating = true;
      try {
        await _scrollController.animateTo(
          target,
          duration: _ReaderPageState._kPagedScrollTurnDuration,
          curve: Curves.easeOutCubic,
        );
      } catch (_) {
        // Ignore interrupted animations.
      } finally {
        _isScrollStepAnimating = false;
      }
      _scheduleProgressSave();
      return;
    }

    await _jumpToAdjacentReadableChapter(forward: forward);
  }

  Future<void> _turnMangaPage({required bool forward}) async {
    if (!_isMangaPagedMode) {
      return;
    }
    final total = _chapterImageUrls.length;
    final target = forward ? _mangaPageIndex + 1 : _mangaPageIndex - 1;
    final isOutOfRange = forward ? target >= total : target < 0;
    if (isOutOfRange) {
      await _jumpToAdjacentReadableChapter(forward: forward);
      return;
    }
    if (_mangaPageController.hasClients) {
      await _mangaPageController.animateToPage(
        target,
        duration: _ReaderPageState._kMangaPagedTurnDuration,
        curve: Curves.easeInOutCubic,
      );
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _mangaPageIndex = target;
    });
    _syncActiveReadingRecordSessionProgress();
    _scheduleProgressSave();
  }

  bool get _isBackNavigationInteractionCoolingDown {
    final lastAt = _lastBackNavigationAt;
    if (lastAt == null) {
      return false;
    }
    return DateTime.now().difference(lastAt) <
        _ReaderPageState._kBackNavigationInteractionCooldown;
  }

  bool get _isInitialReaderInteractionCoolingDown {
    final unlockAt = _readerInteractionUnlockAt;
    if (unlockAt == null) {
      return false;
    }
    return DateTime.now().isBefore(unlockAt);
  }

  void _handleBackNavigation() {
    _markBackNavigationTriggered();
    final now = DateTime.now();
    final previousBackAt = _lastReaderBackAt;
    _lastReaderBackAt = now;
    if (previousBackAt != null &&
        now.difference(previousBackAt) <= const Duration(milliseconds: 700)) {
      context.go('/bookshelf');
      return;
    }
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/bookshelf');
  }

  void _markBackNavigationTriggered() {
    _lastBackNavigationAt = DateTime.now();
    _markReaderTapHandledByChild();
  }

  void _markReaderTapHandledByChild() {
    _readerTapHandledByChild = true;
  }

  Widget _buildOverlayScrim() {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _overlayControlsController,
        builder: (context, _) {
          final opacity =
              _overlayControlsFadeProgress *
              _ReaderPageState._kOverlayScrimMaxAlpha;
          return IgnorePointer(
            ignoring: opacity <= 0.001,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _hideOverlayControls(manual: true),
              child: ColoredBox(color: Colors.black.withValues(alpha: opacity)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBackgroundLayer(_ReaderThemeColors colors) {
    return DecoratedBox(decoration: _buildReaderBackgroundDecoration(colors));
  }

  Widget _buildChapterLoadingIndicator(_ReaderThemeColors colors) {
    final showIndicator =
        _showChapterLoadingIndicator && !_shouldShowBlockingReaderLoading;
    final topInset = _topSafeInset(context);

    return AnimatedBuilder(
      animation: _overlayControlsController,
      builder: (context, _) {
        final overlayProgress = _overlayControlsShiftProgress;
        final topOffset =
            lerpDouble(topInset + 8, topInset + 60, overlayProgress)!;
        return Positioned(
          top: topOffset,
          left: 20,
          right: 20,
          child: IgnorePointer(
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOutCubic,
              offset: showIndicator ? Offset.zero : const Offset(0, -0.35),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: showIndicator ? 1 : 0,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: AppLayout.dialogMaxWidth(
                        context,
                        maxWidth: 220,
                        horizontalMargin: 40,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        minHeight: 3,
                        backgroundColor: colors.divider.withValues(alpha: 0.22),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          colors.text.withValues(alpha: 0.72),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _hideOverlayControls({
    bool resumeAutoRead = true,
    bool syncSystemUi = true,
    bool manual = false,
  }) {
    if (!_showOverlayControls || !mounted) {
      return;
    }

    _cancelOverlayAutoHideTimer();
    if (syncSystemUi) {
      _setOverlayControlsVisibility(false);
    } else {
      setState(() {
        _showOverlayControls = false;
        _bottomOverlayDraftProgressRatio = null;
      });
      unawaited(_syncVolumeKeyPageInterception());
      _overlayControlsController.reverse();
    }
    if (resumeAutoRead) {
      _scheduleAutoReadResume();
    }
  }

  void _setOverlayControlsVisibility(bool visible) {
    if (!mounted || _showOverlayControls == visible) {
      if (visible) {
        _scheduleOverlayAutoHide();
      }
      return;
    }

    setState(() {
      _showOverlayControls = visible;
      if (!visible) {
        _bottomOverlayDraftProgressRatio = null;
      }
    });
    if (visible) {
      _pauseAutoReadForRuntime();
      _scheduleOverlayAutoHide();
      _maybeShowToolbarHint();
    } else {
      _cancelOverlayAutoHideTimer();
    }
    unawaited(_syncVolumeKeyPageInterception());
    if (visible) {
      _overlayControlsController.forward();
    } else {
      _overlayControlsController.reverse();
    }
  }

  void _scheduleOverlayAutoHide() {
    _overlayAutoHideTimer?.cancel();
    if (!_showOverlayControls || _isOverlayAutoHideSuspended) {
      return;
    }
    _overlayAutoHideTimer = Timer(
      _ReaderPageState._kOverlayControlsAutoHideDelay,
      () {
        _overlayAutoHideTimer = null;
        if (!mounted || !_showOverlayControls || _isOverlayAutoHideSuspended) {
          return;
        }
        _hideOverlayControls(resumeAutoRead: true);
      },
    );
  }

  void _cancelOverlayAutoHideTimer() {
    _overlayAutoHideTimer?.cancel();
    _overlayAutoHideTimer = null;
  }

  void _suspendOverlayAutoHide() {
    _isOverlayAutoHideSuspended = true;
    _cancelOverlayAutoHideTimer();
  }

  void _resumeOverlayAutoHide() {
    if (!_isOverlayAutoHideSuspended) {
      return;
    }
    _isOverlayAutoHideSuspended = false;
    _scheduleOverlayAutoHide();
  }

  void _touchOverlayControls() {
    if (!_showOverlayControls) {
      return;
    }
    _scheduleOverlayAutoHide();
  }

  void _maybeShowToolbarHint() {
    if (_hasShownToolbarHint) {
      return;
    }
    _hasShownToolbarHint = true;
    unawaited(_preferencesService.saveToolbarHintShown(true));
    _showMessage(
      '轻触中间区域显示/隐藏工具栏',
      duration: _ReaderPageState._kReaderSnackActionDuration,
      dedupeKey: 'reader_toolbar_hint',
    );
  }

  Future<void> _maybePromptTapZoneGuide() async {
    if (_hasShownTapZoneGuide || !mounted || _isMangaChapter) {
      return;
    }
    _hasShownTapZoneGuide = true;
    await _preferencesService.saveTapZoneGuideShown(true);
    if (!mounted) {
      return;
    }
    _showReaderSnackBar(
      text: '可自定义正文点击分区，默认保持当前翻页习惯。',
      duration: _ReaderPageState._kReaderSnackActionDuration,
      dedupeKey: 'reader_tap_zone_guide',
      actionLabel: '现在设置',
      onActionPressed: () {
        unawaited(
          _showSettingsSheet(
            initialTab: _ReaderSettingsTab.interface,
            initialSettingsGroupKey: 'interaction',
          ),
        );
      },
    );
  }

  void _syncSystemUiVisibility({bool force = false, bool? visible}) {
    if (!mounted) {
      return;
    }
    final shouldShow = visible ?? _showOverlayControls;
    if (!force && _isSystemUiVisible == shouldShow) {
      return;
    }
    _isSystemUiVisible = shouldShow;

    if (shouldShow) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      return;
    }

    final platform = Theme.of(context).platform;
    if (platform == TargetPlatform.android) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      return;
    }

    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: const [SystemUiOverlay.bottom],
    );
  }

  void _onReaderTap(Offset localPosition, Size size, EdgeInsets gestureInsets) {
    if (_isTextSelectionActive) {
      return;
    }
    if (_isInitialReaderInteractionCoolingDown) {
      return;
    }
    if (_isBackNavigationInteractionCoolingDown) {
      return;
    }

    if (_autoReadSessionState == ReaderAutoReadSessionState.chapterPaused) {
      unawaited(_showAutoReadControlSheet());
      return;
    }

    if (_isAutoReadSessionEnabled) {
      if (_autoReadSessionState == ReaderAutoReadSessionState.running) {
        unawaited(_openAutoReadFromOverlay());
      } else if (_autoReadSessionState == ReaderAutoReadSessionState.paused) {
        unawaited(_showAutoReadControlSheet());
      }
      return;
    }

    if (_showOverlayControls) {
      _hideOverlayControls(resumeAutoRead: true);
      return;
    }

    if (!_settings.pageTurnMode.tapEnabled &&
        !_settings.pageTurnMode.usesScrollLayout) {
      return;
    }

    final hit = _resolveTapZoneHit(
      localPosition: localPosition,
      size: size,
      gestureInsets: gestureInsets,
    );
    if (hit == null) {
      return;
    }
    _performTapZoneAction(hit.action);
  }

  ReaderTapZoneHit? _resolveTapZoneHit({
    required Offset localPosition,
    required Size size,
    required EdgeInsets gestureInsets,
  }) {
    final surfaceMetrics = _resolveReaderSurfaceMetrics(
      context,
      viewportSize: size,
      viewportKind: _currentViewportKind,
    );
    final tapZoneRect = _tapZoneResolver.resolveRect(
      viewportSize: size,
      contentRect: surfaceMetrics.contentRect,
      gestureInsets: gestureInsets,
    );
    return _tapZoneResolver.resolveHit(
      localPosition: localPosition,
      rect: tapZoneRect,
      actions: _settings.tapZoneActions,
    );
  }

  bool get _supportsFloatingToolbarOnLongPress {
    if (_isTextPagedViewport || _isTextScrollViewport) {
      return false;
    }
    if (_currentContentMode == ReaderContentMode.audio) {
      return false;
    }
    if (_isMangaViewport) {
      return false;
    }
    return _resolvedContentSession().hybridSubMode != ReaderHybridSubMode.pdf;
  }

  bool get _shouldHandleReaderLongPress =>
      _isMangaViewport || _supportsFloatingToolbarOnLongPress;

  Future<void> _handleReaderLongPress() async {
    if (_isAutoReadSessionEnabled) {
      if (_autoReadSessionState == ReaderAutoReadSessionState.running) {
        _pauseAutoReadSession(showMessage: true);
      } else if (_autoReadSessionState == ReaderAutoReadSessionState.paused) {
        await _showSettingsSheet(
          initialTab: _ReaderSettingsTab.reading,
          initialSettingsGroupKey: 'auto_read',
        );
        return;
      }
    }
    if (_isMangaViewport) {
      await _openMangaPositionSheet();
      return;
    }
    if (_supportsFloatingToolbarOnLongPress) {
      _setOverlayControlsVisibility(true);
      _touchOverlayControls();
      return;
    }
    _hideOverlayControls(resumeAutoRead: false);
  }

  void _performTapZoneAction(ReaderTapZoneAction action) {
    switch (action) {
      case ReaderTapZoneAction.previousPage:
        unawaited(_turnReaderByDirection(forward: false));
        return;
      case ReaderTapZoneAction.nextPage:
        unawaited(_turnReaderByDirection(forward: true));
        return;
      case ReaderTapZoneAction.toggleToolbar:
        final nextShow = !_showOverlayControls;
        _setOverlayControlsVisibility(nextShow);
        if (!nextShow) {
          _scheduleAutoReadResume();
        } else {
          _touchOverlayControls();
        }
        return;
      case ReaderTapZoneAction.catalog:
        unawaited(_openCatalogSheetFromOverlay());
        return;
      case ReaderTapZoneAction.autoRead:
        if (_supportsAutoRead) {
          unawaited(_openAutoReadFromOverlay());
        } else {
          _showMessage('当前内容暂不支持自动阅读');
        }
        return;
      case ReaderTapZoneAction.bookmark:
        unawaited(_showCatalogSheet());
        return;
      case ReaderTapZoneAction.nightMode:
        unawaited(_toggleDayNightMode());
        return;
      case ReaderTapZoneAction.none:
        return;
    }
  }

  Future<void> _toggleAutoReadSession() async {
    if (_autoReadSessionState == ReaderAutoReadSessionState.running) {
      _pauseAutoReadSession(showMessage: true);
      return;
    }
    if (_autoReadSessionState == ReaderAutoReadSessionState.paused) {
      _resumeAutoReadSession(showMessage: true);
      return;
    }
    if (_autoReadSessionState == ReaderAutoReadSessionState.chapterPaused) {
      unawaited(_continueAutoReadAfterChapterPause());
      return;
    }

    if (!_supportsAutoRead) {
      _showMessage('漫画模式暂不支持自动阅读。');
      return;
    }

    if (_showOverlayControls) {
      _hideOverlayControls(resumeAutoRead: false);
    }
    _startAutoReadSession(showMessage: true);
  }

  Future<void> _openAutoReadFromOverlay() async {
    if (_autoReadSessionState == ReaderAutoReadSessionState.running) {
      _pauseAutoReadSession(showMessage: false);
      await _showAutoReadControlSheet();
      return;
    }
    if (_autoReadSessionState == ReaderAutoReadSessionState.paused) {
      await _showAutoReadControlSheet();
      return;
    }
    if (_autoReadSessionState == ReaderAutoReadSessionState.chapterPaused) {
      await _showAutoReadControlSheet();
      return;
    }

    if (!_supportsAutoRead) {
      _showMessage('当前内容暂不支持自动阅读。');
      return;
    }

    final configured = await _preferencesService.loadAutoReadConfigured();
    if (!mounted) {
      return;
    }
    if (!configured) {
      await _preferencesService.saveAutoReadConfigured(true);
      if (!mounted) {
        return;
      }
      await _showSettingsSheet(
        initialTab: _ReaderSettingsTab.reading,
        initialSettingsGroupKey: 'auto_read',
      );
      return;
    }

    await _toggleAutoReadSession();
  }

  Future<void> _showAutoReadControlSheet() async {
    if (!mounted) {
      return;
    }

    var speedLevel = _settings.autoReadSpeedLevel;
    final action = await showAdaptiveActionSurface<
      _ReaderAutoReadControlAction
    >(
      context: context,
      maxWidth: 420,
      maxHeightFactor: 0.56,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final theme = Theme.of(context);
            final colorScheme = theme.colorScheme;
            final isPagedMode =
                _settings.autoReadMode != ReaderAutoReadMode.scroll;
            final speedDescription =
                isPagedMode
                    ? '${(_autoReadCoordinator.resolvePagedHoldDuration(speedLevel: speedLevel).inMilliseconds / 1000).toStringAsFixed(1)} 秒/页'
                    : '${ReaderSettings.autoReadSpeedForLevel(speedLevel).round()} px/s';
            final canContinue =
                _isAutoReadSessionEnabled &&
                (_autoReadSessionState == ReaderAutoReadSessionState.paused ||
                    _autoReadSessionState ==
                        ReaderAutoReadSessionState.chapterPaused);

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.auto_mode_rounded,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '自动阅读控制台',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            canContinue ? '已暂停，调整后可继续阅读' : '调整自动阅读节奏',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.62,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Text(
                            '速度 $speedLevel 档',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            speedDescription,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        min: ReaderSettings.minAutoReadSpeedLevel.toDouble(),
                        max: ReaderSettings.maxAutoReadSpeedLevel.toDouble(),
                        divisions:
                            ReaderSettings.maxAutoReadSpeedLevel -
                            ReaderSettings.minAutoReadSpeedLevel,
                        label: '$speedLevel',
                        value: speedLevel.toDouble(),
                        onChanged: (value) {
                          final nextLevel = value.round();
                          setSheetState(() {
                            speedLevel = nextLevel;
                          });
                          unawaited(_applyAutoReadSpeedLevel(nextLevel));
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _buildAutoReadControlButton(
                        context: context,
                        icon: Icons.list_alt_outlined,
                        label: '目录',
                        action: _ReaderAutoReadControlAction.catalog,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildAutoReadControlButton(
                        context: context,
                        icon:
                            canContinue
                                ? Icons.play_arrow_rounded
                                : Icons.pause_rounded,
                        label: canContinue ? '继续' : '暂停',
                        action: _ReaderAutoReadControlAction.toggle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildAutoReadControlButton(
                        context: context,
                        icon: Icons.tune_rounded,
                        label: '设置',
                        action: _ReaderAutoReadControlAction.settings,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildAutoReadControlButton(
                        context: context,
                        icon: Icons.close_rounded,
                        label: '退出',
                        action: _ReaderAutoReadControlAction.exit,
                        destructive: true,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );

    if (!mounted || action == null) {
      return;
    }

    switch (action) {
      case _ReaderAutoReadControlAction.catalog:
        await _openCatalogSheetFromOverlay();
        return;
      case _ReaderAutoReadControlAction.toggle:
        if (_autoReadSessionState == ReaderAutoReadSessionState.running) {
          _pauseAutoReadSession(showMessage: true);
        } else if (_autoReadSessionState ==
            ReaderAutoReadSessionState.chapterPaused) {
          unawaited(_continueAutoReadAfterChapterPause());
        } else if (_autoReadSessionState == ReaderAutoReadSessionState.paused) {
          _resumeAutoReadSession(showMessage: true);
        } else if (_supportsAutoRead) {
          _startAutoReadSession(showMessage: true);
        }
        return;
      case _ReaderAutoReadControlAction.settings:
        await _showSettingsSheet(initialTab: _ReaderSettingsTab.interface);
        return;
      case _ReaderAutoReadControlAction.exit:
        _stopAutoReadSession(showMessage: true);
        return;
    }
  }

  Widget _buildAutoReadControlButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required _ReaderAutoReadControlAction action,
    bool destructive = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground =
        destructive ? colorScheme.error : colorScheme.onSurfaceVariant;
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: foreground,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        side: BorderSide(
          color:
              destructive
                  ? colorScheme.error.withValues(alpha: 0.45)
                  : colorScheme.outlineVariant,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      onPressed: () => Navigator.of(context).pop(action),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20),
          const SizedBox(height: 4),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Future<void> _applyAutoReadSpeedLevel(int level) async {
    if (!mounted) {
      return;
    }
    final normalized =
        level
            .clamp(
              ReaderSettings.minAutoReadSpeedLevel,
              ReaderSettings.maxAutoReadSpeedLevel,
            )
            .toInt();
    if (_settings.autoReadSpeedLevel == normalized) {
      return;
    }
    final nextSettings = _settings.copyWith(autoReadSpeedLevel: normalized);
    _applyReaderSettingsWithModeRestore(
      nextSettings: nextSettings,
      syncVolumeKeyPageInterception: false,
    );
    await _persistResolvedReaderSettingsLayers(nextSettings);
    if (mounted &&
        _autoReadSessionState == ReaderAutoReadSessionState.running) {
      _reconcileAutoRead(restart: true);
    }
  }

  void _startAutoReadSession({bool showMessage = false}) {
    if (!mounted || !_supportsAutoRead) {
      return;
    }

    _autoReadResumeTimer?.cancel();
    _pageTurnModeBeforeAutoRead = _settings.pageTurnMode;
    _isAutoReadPausedByRuntime = false;
    final targetPageTurnMode =
        _settings.autoReadMode == ReaderAutoReadMode.scroll
            ? ReaderPageTurnMode.scroll
            : (_settings.pageTurnMode.usesScrollLayout
                ? ReaderPageTurnMode.tapAndSwipe
                : _settings.pageTurnMode);
    _applyReaderSettingsWithModeRestore(
      nextSettings: _settings.copyWith(
        pageTurnMode: targetPageTurnMode,
        autoReadEnabled: false,
      ),
      syncVolumeKeyPageInterception: false,
      beforeStateUpdate: () {
        _isAutoReadSessionEnabled = true;
        _autoReadSessionState = ReaderAutoReadSessionState.running;
      },
    );
    _reconcileAutoRead(restart: true);
    if (showMessage) {
      _showMessage('已开启自动阅读。');
    }
  }

  void _pauseAutoReadSession({bool showMessage = false}) {
    if (!_isAutoReadSessionEnabled ||
        (_autoReadSessionState != ReaderAutoReadSessionState.running &&
            _autoReadSessionState !=
                ReaderAutoReadSessionState.chapterPaused)) {
      return;
    }
    _autoReadSessionState = ReaderAutoReadSessionState.paused;
    _stopAutoRead();
    if (mounted) {
      setState(() {});
    }
    if (showMessage) {
      _showMessage('已暂停自动阅读。');
    }
  }

  void _resumeAutoReadSession({bool showMessage = false}) {
    if (!_isAutoReadSessionEnabled ||
        _autoReadSessionState != ReaderAutoReadSessionState.paused) {
      return;
    }
    _isAutoReadPausedByRuntime = false;
    _autoReadSessionState = ReaderAutoReadSessionState.running;
    _reconcileAutoRead(restart: true);
    if (mounted) {
      setState(() {});
    }
    if (showMessage) {
      _showMessage('继续自动阅读。');
    }
  }

  void _stopAutoReadSession({bool showMessage = false}) {
    if (!_isAutoReadSessionEnabled) {
      return;
    }
    _isAutoReadAdvancingChapter = false;
    _isAutoReadHandlingBoundary = false;
    _isAutoReadPausedByRuntime = false;
    _autoReadSessionState = ReaderAutoReadSessionState.off;
    _autoReadResumeTimer?.cancel();
    _stopPagedAutoRead();
    _stopAutoRead();

    if (mounted) {
      _applyReaderSettingsWithModeRestore(
        nextSettings: _settings.copyWith(
          pageTurnMode: _pageTurnModeBeforeAutoRead,
          autoReadEnabled: false,
        ),
        syncVolumeKeyPageInterception: false,
        beforeStateUpdate: () {
          _isAutoReadSessionEnabled = false;
          _autoReadSessionState = ReaderAutoReadSessionState.off;
        },
      );
    } else {
      _isAutoReadSessionEnabled = false;
      _autoReadSessionState = ReaderAutoReadSessionState.off;
    }

    if (showMessage) {
      _showMessage('已停止自动阅读。');
    }
  }

  Future<void> _toggleDayNightMode() async {
    final result = _readerThemeModeService.buildToggleResult(
      settings: _settings,
      lightModeBackgroundImageBackup: _lightModeBackgroundImageBackup,
    );
    if (!mounted) {
      return;
    }
    _lightModeBackgroundImageBackup = result.nextLightModeBackgroundImageBackup;
    _applyReaderSettingsWithModeRestore(nextSettings: result.nextSettings);
    await _persistResolvedReaderSettingsLayers(result.nextSettings);
  }

  Future<void> _toggleDayNightModeWithReveal(BuildContext sourceContext) async {
    final result = _readerThemeModeService.buildToggleResult(
      settings: _settings,
      lightModeBackgroundImageBackup: _lightModeBackgroundImageBackup,
    );
    if (!mounted) {
      return;
    }

    Future<void> applyToggle() async {
      _lightModeBackgroundImageBackup =
          result.nextLightModeBackgroundImageBackup;
      _applyReaderSettingsWithModeRestore(nextSettings: result.nextSettings);
      await _persistResolvedReaderSettingsLayers(result.nextSettings);
    }

    final overlay = CircularThemeRevealOverlay.of(sourceContext);
    if (overlay == null) {
      await applyToggle();
      return;
    }
    final center = CircularThemeRevealOverlay.getCenterFromContext(
      sourceContext,
    );
    await overlay.startTransition(
      center: center,
      reverse: false,
      onThemeChange: () {
        unawaited(applyToggle());
      },
    );
  }

  void _showMessage(
    String text, {
    Duration duration = _ReaderPageState._kReaderSnackDuration,
    String? dedupeKey,
  }) {
    _showReaderSnackBar(text: text, duration: duration, dedupeKey: dedupeKey);
  }

  void _showChapterBoundaryHint({required bool isFirst}) {
    if (_isBackNavigationInteractionCoolingDown) {
      return;
    }
    _showMessage(
      _readerFeedbackService.chapterBoundaryMessage(isFirst: isFirst),
      duration: _ReaderPageState._kReaderBoundarySnackDuration,
      dedupeKey: isFirst ? 'boundary_first_chapter' : 'boundary_last_chapter',
    );
  }

  void _showReaderSnackBar({
    required String text,
    Duration duration = _ReaderPageState._kReaderSnackDuration,
    String? dedupeKey,
    String? actionLabel,
    VoidCallback? onActionPressed,
    bool replaceCurrent = true,
  }) {
    if (!mounted) {
      return;
    }

    final decision = _readerFeedbackService.resolveSnackDecision(
      text: text,
      dedupeKey: dedupeKey,
      now: DateTime.now(),
      dedupeWindow: _ReaderPageState._kReaderSnackDedupWindow,
      currentState: ReaderSnackDedupState(
        lastAt: _lastReaderSnackAt,
        lastKey: _lastReaderSnackKey,
      ),
    );
    if (!decision.shouldShow) {
      return;
    }
    _lastReaderSnackAt = decision.nextState.lastAt;
    _lastReaderSnackKey = decision.nextState.lastKey;

    final messenger = ScaffoldMessenger.of(context);
    if (replaceCurrent) {
      messenger.hideCurrentSnackBar();
    }

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final horizontal = AppSpacing.pageHorizontal(context);
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;
    SnackBarAction? snackAction;
    final normalizedActionLabel = actionLabel?.trim() ?? '';
    if (normalizedActionLabel.isNotEmpty && onActionPressed != null) {
      snackAction = SnackBarAction(
        label: normalizedActionLabel,
        textColor: colorScheme.primary,
        onPressed: onActionPressed,
      );
    }

    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(horizontal, 0, horizontal, 12 + bottomSafe),
        elevation: 0,
        duration: duration,
        dismissDirection: DismissDirection.down,
        backgroundColor: colorScheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.55),
          ),
        ),
        content: Text(
          text,
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        action: snackAction,
      ),
    );
  }

  void _recordReaderFailure({required String message, ErrorCode? errorCode}) {
    _readerFeedbackService.recordFailure(
      readerErrorCenterService: _readerErrorCenterService,
      bookId: _currentBookId,
      chapterId: _chapterId,
      chapterTitle: _chapterTitle ?? '',
      message: message,
      bookTitle: _bookTitle,
      sourceId: _sourceId,
      detailUrl: _detailUrl,
      chapterUrl: _chapterUrl,
      errorCode: errorCode,
    );
  }

  void _maybePromptSwitchSourceForMissingSource(ErrorCode? code) {
    return;
  }
}

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
      _stopAutoReadSession(showMessage: true);
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
    if (_isAutoReadSessionEnabled) {
      _stopAutoReadSession(showMessage: true);
      return;
    }

    if (event.direction == ReaderVolumeKeyDirection.up) {
      await _turnReaderByDirection(forward: false);
      return;
    }
    await _turnReaderByDirection(forward: true);
  }

  Future<void> _turnReaderByDirection({
    required bool forward,
    bool includeMangaPaged = true,
  }) async {
    switch (_currentViewportKind) {
      case ReaderModeViewportKind.imagePaged:
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
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/bookshelf');
  }

  void _markBackNavigationTriggered() {
    _lastBackNavigationAt = DateTime.now();
    _suppressNextReaderTap = true;
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
              onTap: _hideOverlayControls,
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
  }) {
    if (!_showOverlayControls || !mounted) {
      return;
    }

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
    }
    unawaited(_syncVolumeKeyPageInterception());
    if (visible) {
      _overlayControlsController.forward();
    } else {
      _overlayControlsController.reverse();
    }
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

    final leftGuard = max(22.0, gestureInsets.left + size.width * 0.02);
    final rightGuard = max(22.0, gestureInsets.right + size.width * 0.02);
    final topGuard = max(0.0, gestureInsets.top);
    final bottomGuard = max(0.0, gestureInsets.bottom);

    final centerLeft = max(size.width * 0.32, leftGuard + 12);
    final centerRight = min(size.width * 0.68, size.width - rightGuard - 12);
    final centerTop = max(size.height * 0.2, topGuard + 8);
    final centerBottom = min(size.height * 0.8, size.height - bottomGuard - 8);

    final isCenterTap =
        localPosition.dx >= centerLeft &&
        localPosition.dx <= centerRight &&
        localPosition.dy >= centerTop &&
        localPosition.dy <= centerBottom;

    if (_isAutoReadSessionEnabled) {
      _stopAutoReadSession(showMessage: true);
      return;
    }

    if (isCenterTap) {
      final nextShow = !_showOverlayControls;
      _setOverlayControlsVisibility(nextShow);
      if (!nextShow) {
        _scheduleAutoReadResume();
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

    if (localPosition.dx <= leftGuard ||
        localPosition.dx >= size.width - rightGuard) {
      return;
    }

    if (localPosition.dx < centerLeft) {
      unawaited(_turnReaderByDirection(forward: false));
      return;
    }

    if (localPosition.dx > centerRight) {
      unawaited(_turnReaderByDirection(forward: true));
    }
  }

  Future<void> _toggleAutoReadSession() async {
    if (_isAutoReadSessionEnabled) {
      _stopAutoReadSession(showMessage: true);
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

  void _startAutoReadSession({bool showMessage = false}) {
    if (!mounted || !_supportsAutoRead) {
      return;
    }

    _autoReadResumeTimer?.cancel();
    _pageTurnModeBeforeAutoRead = _settings.pageTurnMode;
    _isAutoReadPausedByRuntime = false;
    _applyReaderSettingsWithModeRestore(
      nextSettings: _settings.copyWith(
        pageTurnMode: ReaderPageTurnMode.scroll,
        autoReadEnabled: false,
      ),
      syncVolumeKeyPageInterception: false,
      beforeStateUpdate: () {
        _isAutoReadSessionEnabled = true;
      },
    );
    _reconcileAutoRead(restart: true);
    if (showMessage) {
      _showMessage('已开启自动阅读。');
    }
  }

  void _stopAutoReadSession({bool showMessage = false}) {
    if (!_isAutoReadSessionEnabled) {
      return;
    }
    _isAutoReadAdvancingChapter = false;
    _isAutoReadPausedByRuntime = false;
    _autoReadResumeTimer?.cancel();
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
        },
      );
    } else {
      _isAutoReadSessionEnabled = false;
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

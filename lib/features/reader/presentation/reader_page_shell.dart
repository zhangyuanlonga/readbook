// ignore_for_file: invalid_use_of_protected_member

part of 'reader_page.dart';

extension _ReaderPageShellExtension on _ReaderPageState {
  bool get _shouldEnableVolumeKeyPageInterception {
    return _readerPlatformFacade
        .resolveVolumeKeyInterception(
          platformSupported: _platformBridgeService.isVolumeKeyPagingSupported,
          enabledInSettings: _settings.volumeKeyPageEnabled,
          overlayVisible: _overlayController.showOverlayControls,
          textSelectionActive: _isTextSelectionActive,
          bootstrapping: _isBootstrapping,
          loadingContent: _isLoadingContent,
          hasError: _errorText != null,
        )
        .shouldEnable;
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

  Future<void> _handleVolumeKeyEvent(ReaderVolumeKeyEvent event) async {
    if (!mounted || !_settings.volumeKeyPageEnabled) {
      return;
    }
    if (_overlayController.showOverlayControls || _isTextSelectionActive) {
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
      _pauseAutoReadSession();
    }

    await _dispatchReaderNavigationCommand(
      event.direction == ReaderVolumeKeyDirection.up
          ? const ReaderNavigationCommand.previousPage(
            source: ReaderNavigationCommandSource.volumeKey,
          )
          : const ReaderNavigationCommand.nextPage(
            source: ReaderNavigationCommandSource.volumeKey,
          ),
    );

    if (shouldResumeAutoRead &&
        mounted &&
        _isAutoReadSessionEnabled &&
        _autoReadSessionState == ReaderAutoReadSessionState.paused) {
      _resumeAutoReadSession();
    }
  }

  Future<void> _turnReaderByDirection({
    required bool forward,
    ReaderPageTurnRequestSource source = ReaderPageTurnRequestSource.unknown,
    bool includeMangaPaged = true,
  }) async {
    final shouldHideOverlayBeforeTurn =
        _currentViewportKind != ReaderModeViewportKind.textScroll;
    if (shouldHideOverlayBeforeTurn && _overlayController.showOverlayControls) {
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
        await _turnPagedTextPage(direction: forward ? 1 : -1, source: source);
        return;
      case ReaderModeViewportKind.textScroll:
        if (_settings.pageTurnMode.usesScrollLayout) {
          await _advanceScrollReaderByStep(forward: forward);
        }
        return;
      case ReaderModeViewportKind.imageScroll:
      case ReaderModeViewportKind.audio:
        return;
    }
  }

  Future<void> _advanceScrollReaderByStep({required bool forward}) async {
    if (!_scrollController.hasClients) {
      return;
    }

    if (_isScrollStepAnimating) {
      _scrollStepAnimationToken += 1;
      _isScrollStepAnimating = false;
      final currentOffset =
          _scrollController.position.pixels
              .clamp(
                _scrollController.position.minScrollExtent,
                _scrollController.position.maxScrollExtent,
              )
              .toDouble();
      try {
        _scrollController.jumpTo(currentOffset);
      } catch (_) {
        // Ignore interruptions from a detached scroll position.
      }
      if (!_scrollController.hasClients) {
        return;
      }
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
      final animationToken = ++_scrollStepAnimationToken;
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
        if (animationToken == _scrollStepAnimationToken) {
          _isScrollStepAnimating = false;
        }
      }
      if (animationToken != _scrollStepAnimationToken) {
        return;
      }
      _syncActiveContinuousTextChapterFromScroll();
      _scheduleProgressSave();
      return;
    }

    await _dispatchReaderNavigationCommand(
      forward
          ? const ReaderNavigationCommand.nextChapter(
            source: ReaderNavigationCommandSource.scrollEdge,
          )
          : const ReaderNavigationCommand.previousChapter(
            source: ReaderNavigationCommandSource.scrollEdge,
          ),
    );
  }

  Future<void> _turnMangaPage({required bool forward}) async {
    if (!_isMangaPagedMode) {
      return;
    }
    final total = _chapterImageUrls.length;
    final target = forward ? _imagePageIndex + 1 : _imagePageIndex - 1;
    final isOutOfRange = forward ? target >= total : target < 0;
    if (isOutOfRange) {
      await _dispatchReaderNavigationCommand(
        forward
            ? const ReaderNavigationCommand.nextChapter(
              source: ReaderNavigationCommandSource.scrollEdge,
            )
            : const ReaderNavigationCommand.previousChapter(
              source: ReaderNavigationCommandSource.scrollEdge,
            ),
      );
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
      _imagePageIndex = target;
    });
    _syncActiveReadingRecordSessionProgress();
    _scheduleProgressSave();
  }

  bool get _isBackNavigationInteractionCoolingDown {
    return _interactionRuntimeController.isBackNavigationCoolingDown(
      DateTime.now(),
      _ReaderPageState._kBackNavigationInteractionCooldown,
    );
  }

  bool get _isInitialReaderInteractionCoolingDown {
    return _interactionRuntimeController.isInitialInteractionCoolingDown(
      DateTime.now(),
    );
  }

  void _handleBackNavigation() {
    _markBackNavigationTriggered();
    _stopAutoReadSessionForReaderExit();
    final now = DateTime.now();
    if (_interactionRuntimeController.recordReaderBackAndShouldExit(
      now: now,
      doubleBackWindow: const Duration(milliseconds: 700),
    )) {
      context.go('/bookshelf');
      return;
    }
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/bookshelf');
  }

  void _stopAutoReadSessionForReaderExit() {
    if (!_isAutoReadSessionEnabled) {
      return;
    }
    _stopAutoReadSession();
  }

  void _markBackNavigationTriggered() {
    _interactionRuntimeController.markBackNavigationTriggered(DateTime.now());
    _markReaderTapHandledByChild();
  }

  void _markReaderTapHandledByChild() {
    _pointerInputController.markChildHandled();
  }

  Widget _buildOverlayScrim() {
    return ReaderOverlayScrimLayer(
      animation: _overlayControlsController,
      maxAlpha: _ReaderPageState._kOverlayScrimMaxAlpha,
      onTap: () => _hideOverlayControls(manual: true),
    );
  }

  Widget _buildBackgroundLayer(ReaderThemeColors colors) {
    return ReaderBackgroundLayer(
      model: ReaderBackgroundVisualModel(
        decoration: _buildReaderBackgroundDecoration(colors),
      ),
    );
  }

  Widget _buildChapterLoadingIndicator(ReaderThemeColors colors) {
    final showIndicator =
        _overlayController.showChapterLoadingIndicator &&
        !_shouldShowBlockingReaderLoading;
    final topInset = _topSafeInset(context);

    return ReaderChapterLoadingIndicatorLayer(
      animation: _overlayControlsController,
      showIndicator: showIndicator,
      topInset: topInset,
      dividerColor: colors.divider,
      indicatorColor: colors.text,
    );
  }

  Future<void> _toggleAutoReadSession() async {
    if (_autoReadSessionState == ReaderAutoReadSessionState.running) {
      _pauseAutoReadSession();
      return;
    }
    if (_autoReadSessionState == ReaderAutoReadSessionState.paused) {
      _resumeAutoReadSession();
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

    if (_overlayController.showOverlayControls) {
      _hideOverlayControls(resumeAutoRead: false);
    }
    _startAutoReadSession();
  }

  Future<void> _openAutoReadFromOverlay() async {
    if (_autoReadSessionState == ReaderAutoReadSessionState.running) {
      _pauseAutoReadSession();
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
          _pauseAutoReadSession();
        } else if (_autoReadSessionState ==
            ReaderAutoReadSessionState.chapterPaused) {
          unawaited(_continueAutoReadAfterChapterPause());
        } else if (_autoReadSessionState == ReaderAutoReadSessionState.paused) {
          _resumeAutoReadSession();
        } else if (_supportsAutoRead) {
          _startAutoReadSession();
        }
        return;
      case _ReaderAutoReadControlAction.settings:
        await _showSettingsSheet(
          initialTab: _ReaderSettingsTab.reading,
          initialSettingsGroupKey: 'auto_read',
        );
        return;
      case _ReaderAutoReadControlAction.exit:
        _stopAutoReadSession();
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
    // UI-GOV-EXEMPT: hardcoded-style auto-read control is a square icon+label control, not a standard text button.
    final borderRadius = BorderRadius.circular(16);
    return Material(
      // UI-GOV-EXEMPT: hardcoded-style transparent material is required for InkWell ripple over the custom control.
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius,
        side: BorderSide(
          color:
              destructive
                  ? colorScheme.error.withValues(alpha: 0.45)
                  : colorScheme.outlineVariant,
        ),
      ),
      child: InkWell(
        borderRadius: borderRadius,
        onTap: () => Navigator.of(context).pop(action),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: IconTheme.merge(
            data: IconThemeData(color: foreground),
            child: DefaultTextStyle.merge(
              style: TextStyle(color: foreground),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 20),
                  const SizedBox(height: 4),
                  Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ),
        ),
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

  void _startAutoReadSession() {
    if (!mounted || !_supportsAutoRead) {
      return;
    }

    _autoReadResumeTimer?.cancel();
    _lastAutoReadProgressUiRefreshAt = null;
    _autoReadTapGuardUntil = DateTime.now().add(
      const Duration(milliseconds: 650),
    );
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
  }

  void _pauseAutoReadSession() {
    if (!_isAutoReadSessionEnabled ||
        (_autoReadSessionState != ReaderAutoReadSessionState.running &&
            _autoReadSessionState !=
                ReaderAutoReadSessionState.chapterPaused)) {
      return;
    }
    _setAutoReadSessionState(ReaderAutoReadSessionState.paused);
    _stopAutoRead(preserveDisplayProgress: true);
  }

  void _resumeAutoReadSession() {
    if (!_isAutoReadSessionEnabled ||
        _autoReadSessionState != ReaderAutoReadSessionState.paused) {
      return;
    }
    _isAutoReadPausedByRuntime = false;
    _setAutoReadSessionState(ReaderAutoReadSessionState.running);
    _reconcileAutoRead(restart: true);
  }

  void _stopAutoReadSession() {
    if (!_isAutoReadSessionEnabled) {
      return;
    }
    _syncAutoReadVisibleContinuousTextChapter();
    _flushProgressSave();
    _isAutoReadAdvancingChapter = false;
    _isAutoReadHandlingBoundary = false;
    _isAutoReadPausedByRuntime = false;
    _setAutoReadSessionState(ReaderAutoReadSessionState.off, rebuild: false);
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
          _setAutoReadSessionState(
            ReaderAutoReadSessionState.off,
            rebuild: false,
          );
        },
      );
    } else {
      _isAutoReadSessionEnabled = false;
      _setAutoReadSessionState(ReaderAutoReadSessionState.off, rebuild: false);
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

    final colorScheme = Theme.of(context).colorScheme;
    SnackBarAction? snackAction;
    final normalizedActionLabel = actionLabel?.trim() ?? '';
    if (normalizedActionLabel.isNotEmpty && onActionPressed != null) {
      snackAction = SnackBarAction(
        label: normalizedActionLabel,
        textColor: colorScheme.primary,
        onPressed: onActionPressed,
      );
    }

    AppFeedback.showSnackBar(
      context,
      message: text,
      duration: duration,
      action: snackAction,
      clearPrevious: replaceCurrent,
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

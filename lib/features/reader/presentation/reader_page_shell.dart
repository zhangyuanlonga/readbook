// ignore_for_file: invalid_use_of_protected_member

part of 'reader_page.dart';

extension _ReaderPageShellExtension on _ReaderPageState {
  bool get _shouldEnableVolumeKeyPageInterception {
    if (!ReaderVolumeKeyPageBridge.instance.isSupported) {
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
    if (!ReaderVolumeKeyPageBridge.instance.isSupported) {
      return '当前平台暂不支持音量键翻页。';
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return 'iOS 真机支持音量键翻页；启用后会拦截按键并维持系统音量。';
    }
    return '仅在阅读态生效，打开菜单或弹层时不会拦截系统音量。';
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
    await ReaderVolumeKeyPageBridge.instance.setEnabled(enabled);
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
    if (!_scrollController.hasClients) {
      return;
    }

    final position = _scrollController.position;
    final distance =
        (position.viewportDimension * _settings.pageTurnStepRatio)
            .clamp(120.0, max(position.viewportDimension, 120.0))
            .toDouble();
    final current = position.pixels;
    final target =
        forward
            ? min(current + distance, position.maxScrollExtent)
            : max(current - distance, 0.0);

    if ((target - current).abs() >= 1.0) {
      try {
        await _scrollController.animateTo(
          target,
          duration: _ReaderPageState._kPagedScrollTurnDuration,
          curve: Curves.easeInOutCubic,
        );
      } catch (_) {
        // Ignore interrupted animations.
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
      unawaited(
        _turnReaderByDirection(forward: false, includeMangaPaged: false),
      );
      return;
    }

    if (localPosition.dx > centerRight) {
      unawaited(
        _turnReaderByDirection(forward: true, includeMangaPaged: false),
      );
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
}

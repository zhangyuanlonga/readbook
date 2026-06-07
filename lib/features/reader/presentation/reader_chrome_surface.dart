// ignore_for_file: invalid_use_of_protected_member

part of 'reader_page.dart';

extension _ReaderChromeSurface on _ReaderPageState {
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

    _cancelPendingSystemUiHide();
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
      _syncSystemUiVisibility(visible: true);
    } else {
      _cancelOverlayAutoHideTimer();
    }
    unawaited(_syncVolumeKeyPageInterception());
    if (visible) {
      _overlayControlsController.forward();
    } else {
      _overlayControlsController.reverse();
      _scheduleSystemUiHideAfterOverlay();
    }
  }

  void _scheduleSystemUiHideAfterOverlay() {
    _systemUiHideTimer?.cancel();
    _systemUiHideTimer = Timer(
      _ReaderPageState._kOverlayControlsHideDuration,
      () {
        _systemUiHideTimer = null;
        if (!mounted || _showOverlayControls) {
          return;
        }
        _syncSystemUiVisibility(visible: false);
      },
    );
  }

  void _cancelPendingSystemUiHide() {
    _systemUiHideTimer?.cancel();
    _systemUiHideTimer = null;
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
    final decision = _readerPlatformFacade.resolveSystemUiVisibility(
      overlayVisible: _showOverlayControls,
      forcedVisible: visible,
    );
    if (!force && _isSystemUiVisible == decision.visible) {
      return;
    }
    _isSystemUiVisible = decision.visible;

    if (decision.chromeState == ReaderSystemUiChromeState.edgeToEdge) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      return;
    }

    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: const <SystemUiOverlay>[SystemUiOverlay.bottom],
    );
  }
}

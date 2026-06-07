part of 'reader_page.dart';

extension _ReaderTouchNavigationLayer on _ReaderPageState {
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
      final guardUntil = _autoReadTapGuardUntil;
      if (guardUntil != null && DateTime.now().isBefore(guardUntil)) {
        return;
      }
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
        _pauseAutoReadSession();
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
}

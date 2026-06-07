part of 'reader_page.dart';

extension _ReaderDesktopInputLayer on _ReaderPageState {
  KeyEventResult _handleReaderKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    final action = _desktopInputResolver.resolveKeyAction(
      event.logicalKey,
      textSelectionActive: _isTextSelectionActive,
      editingText: _isEditingBookmarkNote,
      readerBusy: _isBootstrapping || _isLoadingContent || _errorText != null,
      overlayVisible: _showOverlayControls,
      autoReadSessionEnabled: _isAutoReadSessionEnabled,
    );
    return _dispatchReaderDesktopInputAction(action);
  }

  void _handleReaderPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) {
      return;
    }
    final now = DateTime.now();
    final action = _desktopInputResolver.resolvePointerScrollAction(
      deltaY: event.scrollDelta.dy,
      isPagedViewport:
          _currentViewportKind == ReaderModeViewportKind.textPaged ||
          _currentViewportKind == ReaderModeViewportKind.imagePaged,
      overlayVisible: _showOverlayControls,
      textSelectionActive: _isTextSelectionActive,
      lastPageTurnAt: _lastPointerScrollPageTurnAt,
      now: now,
    );
    if (action == ReaderDesktopInputAction.none) {
      return;
    }
    _lastPointerScrollPageTurnAt = now;
    _dispatchReaderDesktopInputAction(action);
  }

  KeyEventResult _dispatchReaderDesktopInputAction(
    ReaderDesktopInputAction action,
  ) {
    switch (action) {
      case ReaderDesktopInputAction.none:
        return KeyEventResult.ignored;
      case ReaderDesktopInputAction.toggleOverlay:
        if (_showOverlayControls) {
          _hideOverlayControls(resumeAutoRead: true);
        } else {
          _setOverlayControlsVisibility(true);
        }
        return KeyEventResult.handled;
      case ReaderDesktopInputAction.pauseAutoRead:
        _pauseAutoReadSession();
        return KeyEventResult.handled;
      case ReaderDesktopInputAction.previousPage:
        unawaited(_turnReaderByDirection(forward: false));
        return KeyEventResult.handled;
      case ReaderDesktopInputAction.nextPage:
        unawaited(_turnReaderByDirection(forward: true));
        return KeyEventResult.handled;
      case ReaderDesktopInputAction.chapterStart:
        _restoreScrollPosition(0);
        return KeyEventResult.handled;
      case ReaderDesktopInputAction.chapterEnd:
        _restoreScrollPosition(1);
        return KeyEventResult.handled;
    }
  }
}

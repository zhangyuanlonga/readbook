class ReaderOverlayController {
  bool showOverlayControls = false;
  bool isAutoHideSuspended = false;
  bool hasShownToolbarHint = false;
  bool hasShownTapZoneGuide = false;
  double? bottomDraftProgressRatio;

  bool showChapterLoadingIndicator = false;
  bool showBlockingLoadingCard = false;
  bool showHiddenLoadingPlaceholder = false;

  void resetBottomDraftProgress() {
    bottomDraftProgressRatio = null;
  }

  void resetLoadingIndicators() {
    showChapterLoadingIndicator = false;
    showBlockingLoadingCard = false;
    showHiddenLoadingPlaceholder = false;
  }
}

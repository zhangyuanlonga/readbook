class ReaderSettingsEntryPlan {
  const ReaderSettingsEntryPlan({
    required this.shouldStopAutoRead,
    required this.shouldSuspendOverlayAutoHide,
    required this.shouldRestoreOverlayAfterClose,
  });

  final bool shouldStopAutoRead;
  final bool shouldSuspendOverlayAutoHide;
  final bool shouldRestoreOverlayAfterClose;
}

class ReaderSettingsEntryController {
  const ReaderSettingsEntryController();

  ReaderSettingsEntryPlan buildOpenPlan({required bool overlayVisible}) {
    return ReaderSettingsEntryPlan(
      shouldStopAutoRead: true,
      shouldSuspendOverlayAutoHide: true,
      shouldRestoreOverlayAfterClose: overlayVisible,
    );
  }
}

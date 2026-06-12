class ReaderSharedUiStateSnapshot {
  const ReaderSharedUiStateSnapshot({
    required this.settingsSheetVisible,
    required this.catalogVisible,
    required this.isBootstrapping,
    required this.isLoadingContent,
    required this.isSwitchSourceLoading,
    required this.hasVisibleReaderContent,
    required this.hasRecoverableError,
  });

  final bool settingsSheetVisible;
  final bool catalogVisible;
  final bool isBootstrapping;
  final bool isLoadingContent;
  final bool isSwitchSourceLoading;
  final bool hasVisibleReaderContent;
  final bool hasRecoverableError;
}

class ReaderSharedUiStateDecision {
  const ReaderSharedUiStateDecision({
    required this.blockNavigationGestures,
    required this.blockSettingsEntry,
    required this.showTransientLoading,
    required this.showErrorRecovery,
    required this.suspendOverlayAutoHide,
  });

  final bool blockNavigationGestures;
  final bool blockSettingsEntry;
  final bool showTransientLoading;
  final bool showErrorRecovery;
  final bool suspendOverlayAutoHide;
}

class ReaderSharedUiStateBoundary {
  const ReaderSharedUiStateBoundary();

  ReaderSharedUiStateDecision resolve(ReaderSharedUiStateSnapshot snapshot) {
    final modalSurfaceVisible =
        snapshot.settingsSheetVisible || snapshot.catalogVisible;
    final busy =
        snapshot.isBootstrapping ||
        snapshot.isLoadingContent ||
        snapshot.isSwitchSourceLoading;

    return ReaderSharedUiStateDecision(
      blockNavigationGestures:
          modalSurfaceVisible || snapshot.isSwitchSourceLoading,
      blockSettingsEntry: snapshot.isSwitchSourceLoading,
      showTransientLoading:
          snapshot.isLoadingContent &&
          snapshot.hasVisibleReaderContent &&
          !snapshot.isSwitchSourceLoading,
      showErrorRecovery:
          snapshot.hasRecoverableError &&
          !snapshot.isBootstrapping &&
          !snapshot.isSwitchSourceLoading,
      suspendOverlayAutoHide: modalSurfaceVisible || busy,
    );
  }
}

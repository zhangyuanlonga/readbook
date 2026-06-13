enum ReaderSelectionOverlayHost { rootOverlay, foregroundOverlay }

class ReaderSelectionOverlayDecision {
  const ReaderSelectionOverlayDecision({
    required this.host,
    required this.reason,
    this.requiresDeviceValidation = false,
  });

  final ReaderSelectionOverlayHost host;
  final String reason;
  final bool requiresDeviceValidation;

  bool get usesRootOverlay => host == ReaderSelectionOverlayHost.rootOverlay;
}

class ReaderSelectionOverlayPolicy {
  const ReaderSelectionOverlayPolicy();

  ReaderSelectionOverlayDecision resolveToolbarHost({
    required bool rootOverlayIssueVerified,
    required bool foregroundAnchorsValidated,
  }) {
    if (rootOverlayIssueVerified && foregroundAnchorsValidated) {
      return const ReaderSelectionOverlayDecision(
        host: ReaderSelectionOverlayHost.foregroundOverlay,
        reason: 'root_overlay_verified_issue_and_foreground_anchors_validated',
      );
    }
    return const ReaderSelectionOverlayDecision(
      host: ReaderSelectionOverlayHost.rootOverlay,
      reason: 'preserve_system_selection_anchor_accuracy',
      requiresDeviceValidation: true,
    );
  }
}

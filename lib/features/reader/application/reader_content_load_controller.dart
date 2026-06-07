class ReaderContentLoadUiDecision {
  const ReaderContentLoadUiDecision({
    required this.showBlockingLoadingCard,
    required this.showHiddenLoadingPlaceholder,
    required this.showChapterLoadingIndicator,
  });

  final bool showBlockingLoadingCard;
  final bool showHiddenLoadingPlaceholder;
  final bool showChapterLoadingIndicator;
}

class ReaderContentLoadController {
  const ReaderContentLoadController();

  ReaderContentLoadUiDecision resolveDelayedUi({
    required bool needsBlockingLoadingUi,
    required bool isBootstrapping,
    required bool isSwitchSourceLoading,
    required bool hasVisibleReaderContent,
    required bool isLoadingContent,
    required bool shouldShowBlockingReaderLoading,
  }) {
    return ReaderContentLoadUiDecision(
      showBlockingLoadingCard: needsBlockingLoadingUi,
      showHiddenLoadingPlaceholder: needsBlockingLoadingUi,
      showChapterLoadingIndicator:
          !isBootstrapping &&
          !isSwitchSourceLoading &&
          hasVisibleReaderContent &&
          isLoadingContent &&
          !shouldShowBlockingReaderLoading,
    );
  }
}

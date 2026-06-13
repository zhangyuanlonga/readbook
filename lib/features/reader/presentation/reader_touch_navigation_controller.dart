import '../../../domain/entities/reader_settings.dart';

enum ReaderTouchAutoReadStatus { off, running, paused, chapterPaused, finished }

enum ReaderTouchNavigationIntentType {
  ignore,
  showAutoReadControl,
  openAutoReadOverlay,
  hideOverlay,
  resolveTapZone,
  performTapZoneAction,
}

class ReaderTouchNavigationIntent {
  const ReaderTouchNavigationIntent._(this.type, {this.tapZoneAction});

  const ReaderTouchNavigationIntent.ignore()
    : this._(ReaderTouchNavigationIntentType.ignore);

  const ReaderTouchNavigationIntent.showAutoReadControl()
    : this._(ReaderTouchNavigationIntentType.showAutoReadControl);

  const ReaderTouchNavigationIntent.openAutoReadOverlay()
    : this._(ReaderTouchNavigationIntentType.openAutoReadOverlay);

  const ReaderTouchNavigationIntent.hideOverlay()
    : this._(ReaderTouchNavigationIntentType.hideOverlay);

  const ReaderTouchNavigationIntent.resolveTapZone()
    : this._(ReaderTouchNavigationIntentType.resolveTapZone);

  const ReaderTouchNavigationIntent.performTapZoneAction(
    ReaderTapZoneAction action,
  ) : this._(
        ReaderTouchNavigationIntentType.performTapZoneAction,
        tapZoneAction: action,
      );

  final ReaderTouchNavigationIntentType type;
  final ReaderTapZoneAction? tapZoneAction;
}

class ReaderTouchNavigationController {
  const ReaderTouchNavigationController();

  ReaderTouchNavigationIntent resolveTapStart({
    required bool textSelectionActive,
    required bool initialInteractionCoolingDown,
    required bool backNavigationCoolingDown,
    required ReaderTouchAutoReadStatus autoReadStatus,
    required bool autoReadSessionEnabled,
    required DateTime? autoReadTapGuardUntil,
    required DateTime now,
    required bool overlayVisible,
    required bool tapEnabled,
    required bool usesScrollLayout,
  }) {
    if (textSelectionActive ||
        initialInteractionCoolingDown ||
        backNavigationCoolingDown) {
      return const ReaderTouchNavigationIntent.ignore();
    }

    if (autoReadStatus == ReaderTouchAutoReadStatus.chapterPaused) {
      return const ReaderTouchNavigationIntent.showAutoReadControl();
    }

    if (autoReadSessionEnabled) {
      if (autoReadTapGuardUntil != null &&
          now.isBefore(autoReadTapGuardUntil)) {
        return const ReaderTouchNavigationIntent.ignore();
      }
      return switch (autoReadStatus) {
        ReaderTouchAutoReadStatus.running =>
          const ReaderTouchNavigationIntent.openAutoReadOverlay(),
        ReaderTouchAutoReadStatus.paused =>
          const ReaderTouchNavigationIntent.showAutoReadControl(),
        ReaderTouchAutoReadStatus.off ||
        ReaderTouchAutoReadStatus.chapterPaused ||
        ReaderTouchAutoReadStatus
            .finished => const ReaderTouchNavigationIntent.ignore(),
      };
    }

    if (overlayVisible) {
      return const ReaderTouchNavigationIntent.hideOverlay();
    }

    if (!tapEnabled && !usesScrollLayout) {
      return const ReaderTouchNavigationIntent.ignore();
    }

    return const ReaderTouchNavigationIntent.resolveTapZone();
  }

  ReaderTouchNavigationIntent resolveTapZoneAction(
    ReaderTapZoneAction? action,
  ) {
    if (action == null) {
      return const ReaderTouchNavigationIntent.ignore();
    }
    return ReaderTouchNavigationIntent.performTapZoneAction(action);
  }
}

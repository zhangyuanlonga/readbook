import 'package:flutter/widgets.dart';

class ReaderPageLifecycleDelegate {
  const ReaderPageLifecycleDelegate();

  DateTime markBackNavigationTriggered({DateTime? now}) {
    return now ?? DateTime.now();
  }

  bool isBackNavigationCoolingDown({
    required DateTime? lastInteractionAt,
    required Duration cooldown,
    DateTime? now,
  }) {
    if (lastInteractionAt == null) {
      return false;
    }
    final current = now ?? DateTime.now();
    return current.difference(lastInteractionAt) < cooldown;
  }

  bool shouldSyncThemeOnPlatformBrightness({
    required bool mounted,
    required bool hasPendingModalInteraction,
  }) {
    return mounted && !hasPendingModalInteraction;
  }

  bool shouldResumeReaderRuntime(AppLifecycleState state) {
    return state == AppLifecycleState.resumed;
  }

  bool shouldPauseReaderRuntime(AppLifecycleState state) {
    return state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached;
  }
}

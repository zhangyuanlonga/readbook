class ReaderRuntimeWakePolicy {
  const ReaderRuntimeWakePolicy({
    this.progressSaveInterval = const Duration(minutes: 1),
    this.batteryPollInterval = const Duration(minutes: 5),
  });

  final Duration progressSaveInterval;
  final Duration batteryPollInterval;

  Duration nextMinuteDelay(DateTime now) {
    final nextMinute = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute + 1,
    );
    final delay = nextMinute.difference(now);
    return delay <= Duration.zero ? const Duration(minutes: 1) : delay;
  }

  bool shouldPollBattery({
    required bool force,
    required bool infoShowBattery,
    required DateTime? lastReadAt,
    required DateTime now,
  }) {
    if (force) {
      return true;
    }
    if (!infoShowBattery) {
      return false;
    }
    if (lastReadAt == null) {
      return true;
    }
    return now.difference(lastReadAt) >= batteryPollInterval;
  }

  Duration progressSaveDelay({
    required DateTime? lastSavedAt,
    required DateTime now,
  }) {
    if (lastSavedAt == null) {
      return Duration.zero;
    }
    final elapsed = now.difference(lastSavedAt);
    if (elapsed >= progressSaveInterval) {
      return Duration.zero;
    }
    return progressSaveInterval - elapsed;
  }

  bool shouldPauseAutoRead({
    required bool isReaderVisible,
    required bool showOverlayControls,
    required bool isLowBattery,
  }) {
    return !isReaderVisible || showOverlayControls || isLowBattery;
  }
}

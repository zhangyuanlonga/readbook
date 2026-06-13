import 'dart:async';

enum ReaderInteractionRuntimeState { idle, dragging, animating, settling }

class ReaderInteractionStateTransition {
  const ReaderInteractionStateTransition({
    required this.from,
    required this.to,
  });

  final ReaderInteractionRuntimeState from;
  final ReaderInteractionRuntimeState to;
}

class ReaderInteractionRuntimeController {
  ReaderInteractionRuntimeController({
    this.settleDuration = const Duration(milliseconds: 200),
  });

  final Duration settleDuration;
  Timer? _settleTimer;
  ReaderInteractionRuntimeState _state = ReaderInteractionRuntimeState.idle;
  bool _deferredNeighborPreload = false;
  DateTime? _initialInteractionUnlockAt;
  DateTime? _lastBackNavigationAt;
  DateTime? _lastReaderBackAt;

  ReaderInteractionRuntimeState get state => _state;
  bool get hasDeferredNeighborPreload => _deferredNeighborPreload;
  DateTime? get initialInteractionUnlockAt => _initialInteractionUnlockAt;
  DateTime? get lastBackNavigationAt => _lastBackNavigationAt;
  DateTime? get lastReaderBackAt => _lastReaderBackAt;

  bool get isLowPriorityWorkPaused =>
      _state == ReaderInteractionRuntimeState.dragging ||
      _state == ReaderInteractionRuntimeState.animating ||
      _state == ReaderInteractionRuntimeState.settling;

  ReaderInteractionStateTransition? setState(
    ReaderInteractionRuntimeState next,
  ) {
    if (_state == next) {
      return null;
    }
    final transition = ReaderInteractionStateTransition(from: _state, to: next);
    _state = next;
    return transition;
  }

  ReaderInteractionStateTransition? markBusy(
    ReaderInteractionRuntimeState next,
  ) {
    _settleTimer?.cancel();
    _settleTimer = null;
    return setState(next);
  }

  ReaderInteractionStateTransition? beginSettling({
    required void Function(ReaderInteractionStateTransition? transition)
    onSettled,
  }) {
    final transition = setState(ReaderInteractionRuntimeState.settling);
    _settleTimer?.cancel();
    _settleTimer = Timer(settleDuration, () {
      _settleTimer = null;
      onSettled(setState(ReaderInteractionRuntimeState.idle));
    });
    return transition;
  }

  void markDeferredNeighborPreload() {
    _deferredNeighborPreload = true;
  }

  void lockInitialInteractionUntil(DateTime unlockAt) {
    _initialInteractionUnlockAt = unlockAt;
  }

  bool isInitialInteractionCoolingDown(DateTime now) {
    final unlockAt = _initialInteractionUnlockAt;
    return unlockAt != null && now.isBefore(unlockAt);
  }

  void markBackNavigationTriggered(DateTime now) {
    _lastBackNavigationAt = now;
  }

  bool isBackNavigationCoolingDown(DateTime now, Duration cooldown) {
    final lastAt = _lastBackNavigationAt;
    return lastAt != null && now.difference(lastAt) < cooldown;
  }

  bool recordReaderBackAndShouldExit({
    required DateTime now,
    required Duration doubleBackWindow,
  }) {
    final previousBackAt = _lastReaderBackAt;
    _lastReaderBackAt = now;
    return previousBackAt != null &&
        now.difference(previousBackAt) <= doubleBackWindow;
  }

  bool consumeDeferredNeighborPreloadIfIdle() {
    if (_state != ReaderInteractionRuntimeState.idle ||
        !_deferredNeighborPreload) {
      return false;
    }
    _deferredNeighborPreload = false;
    return true;
  }

  void dispose() {
    _settleTimer?.cancel();
    _settleTimer = null;
  }
}

enum SourceRuntimeWarmState {
  cold,
  warming,
  warm,
  unstable,
}

class SourceRuntimeWarmStateService {
  SourceRuntimeWarmStateService();

  static final SourceRuntimeWarmStateService instance =
      SourceRuntimeWarmStateService();

  final Map<String, SourceRuntimeWarmState> _states =
      <String, SourceRuntimeWarmState>{};

  SourceRuntimeWarmState stateFor({
    required String sourceId,
    required String step,
  }) {
    return _states[_keyOf(sourceId: sourceId, step: step)] ??
        SourceRuntimeWarmState.cold;
  }

  bool isWarmed({
    required String sourceId,
    required String step,
  }) {
    return stateFor(sourceId: sourceId, step: step) ==
        SourceRuntimeWarmState.warm;
  }

  void markWarming({
    required String sourceId,
    required String step,
  }) {
    _states[_keyOf(sourceId: sourceId, step: step)] =
        SourceRuntimeWarmState.warming;
  }

  void markWarm({
    required String sourceId,
    required String step,
  }) {
    _states[_keyOf(sourceId: sourceId, step: step)] =
        SourceRuntimeWarmState.warm;
  }

  void markUnstable({
    required String sourceId,
    required String step,
  }) {
    _states[_keyOf(sourceId: sourceId, step: step)] =
        SourceRuntimeWarmState.unstable;
  }

  void resetStep({
    required String sourceId,
    required String step,
  }) {
    _states.remove(_keyOf(sourceId: sourceId, step: step));
  }

  void clearSource(String sourceId) {
    final normalized = sourceId.trim();
    if (normalized.isEmpty) {
      return;
    }
    _states.removeWhere((key, _) => key.startsWith('$normalized:'));
  }

  void clearAll() {
    _states.clear();
  }

  String _keyOf({
    required String sourceId,
    required String step,
  }) {
    return '${sourceId.trim()}:${step.trim()}';
  }
}

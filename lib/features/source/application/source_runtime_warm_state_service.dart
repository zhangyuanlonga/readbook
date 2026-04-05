class SourceRuntimeWarmStateService {
  SourceRuntimeWarmStateService();

  static final SourceRuntimeWarmStateService instance =
      SourceRuntimeWarmStateService();

  final Set<String> _warmedKeys = <String>{};

  bool isWarmed({
    required String sourceId,
    required String step,
  }) {
    return _warmedKeys.contains(_keyOf(sourceId: sourceId, step: step));
  }

  void markWarmed({
    required String sourceId,
    required String step,
  }) {
    _warmedKeys.add(_keyOf(sourceId: sourceId, step: step));
  }

  void clearSource(String sourceId) {
    final normalized = sourceId.trim();
    if (normalized.isEmpty) {
      return;
    }
    _warmedKeys.removeWhere((key) => key.startsWith('$normalized:'));
  }

  void clearAll() {
    _warmedKeys.clear();
  }

  String _keyOf({
    required String sourceId,
    required String step,
  }) {
    return '${sourceId.trim()}:${step.trim()}';
  }
}

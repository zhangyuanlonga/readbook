part of 'search_service.dart';

class _SearchRuntimeProfileService {
  _SearchRuntimeProfileService();

  static const Duration _cooldownDuration = Duration(minutes: 2);
  final Map<String, _SourceRuntimeHealth> _healthBySourceId =
      <String, _SourceRuntimeHealth>{};

  SearchExecutionProfile resolveProfile({
    required RegisteredSource source,
    required SearchPlanScenario scenario,
    required bool allowInteractiveChallenge,
  }) {
    final health = _healthBySourceId[source.runtime.id];
    final capabilities =
        source.definition.manifest.capabilities
            .map((item) => item.trim().toLowerCase())
            .where((item) => item.isNotEmpty)
            .toSet();
    final domains =
        source.definition.manifest.domains
            .map((item) => item.trim().toLowerCase())
            .where((item) => item.isNotEmpty)
            .toList(growable: false);

    final declaresBrowser =
        capabilities.contains('browser') ||
        capabilities.contains('webview') ||
        capabilities.contains('challenge');
    final declaresHeavy =
        capabilities.contains('js-heavy') ||
        capabilities.contains('script-heavy');
    final isLikelyBrowserHeavy =
        declaresBrowser &&
        (domains.length > 1 || scenario == SearchPlanScenario.globalSearch);
    final hasBrowserRisk = (health?.browserRiskCount ?? 0) > 0;
    final hasRepeatedFailures = (health?.totalFailures ?? 0) >= 2;

    if (!allowInteractiveChallenge && declaresBrowser) {
      return SearchExecutionProfile.browserHeavy;
    }
    if (isLikelyBrowserHeavy || hasBrowserRisk) {
      return SearchExecutionProfile.browserHeavy;
    }
    if (declaresBrowser) {
      return SearchExecutionProfile.browserCapable;
    }
    if (declaresHeavy || hasRepeatedFailures) {
      return SearchExecutionProfile.jsHeavy;
    }
    return SearchExecutionProfile.httpLight;
  }

  bool isCoolingDown(String sourceId) {
    final state = _healthBySourceId[sourceId];
    if (state == null) {
      return false;
    }
    final cooldownUntil = state.cooldownUntil;
    if (cooldownUntil == null) {
      return false;
    }
    if (DateTime.now().isAfter(cooldownUntil)) {
      state.cooldownUntil = null;
      state.consecutiveFailures = 0;
      return false;
    }
    return true;
  }

  void recordSuccess({required String sourceId}) {
    final state = _healthBySourceId.putIfAbsent(
      sourceId,
      () => _SourceRuntimeHealth(),
    );
    state.consecutiveFailures = 0;
    state.cooldownUntil = null;
    state.lastSuccessAt = DateTime.now();
  }

  void recordFailure({
    required String sourceId,
    required SearchExecutionProfile profile,
    required String message,
    required bool allowInteractiveChallenge,
  }) {
    final state = _healthBySourceId.putIfAbsent(
      sourceId,
      () => _SourceRuntimeHealth(),
    );
    state.totalFailures += 1;
    state.consecutiveFailures += 1;
    state.lastFailureAt = DateTime.now();

    final normalizedMessage = message.toLowerCase();
    final looksLikeBrowserRisk =
        !allowInteractiveChallenge ||
        profile == SearchExecutionProfile.browserCapable ||
        profile == SearchExecutionProfile.browserHeavy ||
        normalizedMessage.contains('challenge') ||
        normalizedMessage.contains('browser') ||
        normalizedMessage.contains('captcha');
    if (looksLikeBrowserRisk) {
      state.browserRiskCount += 1;
    }
    if (state.consecutiveFailures >= 2) {
      state.cooldownUntil = DateTime.now().add(_cooldownDuration);
    }
  }
}

class _SourceRuntimeHealth {
  int totalFailures = 0;
  int consecutiveFailures = 0;
  int browserRiskCount = 0;
  DateTime? cooldownUntil;
  DateTime? lastFailureAt;
  DateTime? lastSuccessAt;
}

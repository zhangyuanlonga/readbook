part of 'search_service.dart';

class _SearchRuntimeProfileService {
  _SearchRuntimeProfileService({required SourceHealthService healthService})
    : _healthService = healthService;

  final SourceHealthService _healthService;

  SearchExecutionProfile resolveProfile({
    required RegisteredSource source,
    required SearchPlanScenario scenario,
    required bool allowInteractiveChallenge,
  }) {
    final health = _healthService.snapshotFor(
      source.runtime.id,
      enabled: source.definition.manifest.enabled,
    );
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
    final hasBrowserRisk = health.browserRiskCount > 0;
    final hasRepeatedFailures = health.totalFailures >= 2;

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
    return _healthService.snapshotFor(sourceId).coolingDown;
  }

  bool isUnavailable(String sourceId) {
    return _healthService.snapshotFor(sourceId).level ==
        SourceHealthLevel.unavailable;
  }

  int healthPriority(String sourceId) {
    final snapshot = _healthService.snapshotFor(sourceId);
    return switch (snapshot.level) {
      SourceHealthLevel.healthy => 0,
      SourceHealthLevel.warning => 1,
      SourceHealthLevel.risky => 2,
      SourceHealthLevel.unavailable => 3,
    };
  }

  void recordSuccess({required String sourceId, int? latencyMs}) {
    _healthService.markSearchSuccess(
      sourceId: sourceId,
      latencyMs: latencyMs,
    );
  }

  void recordFailure({
    required String sourceId,
    required SearchExecutionProfile profile,
    required String message,
    required bool allowInteractiveChallenge,
    Object? error,
  }) {
    final looksLikeBrowserRisk =
        !allowInteractiveChallenge ||
        profile == SearchExecutionProfile.browserCapable ||
        profile == SearchExecutionProfile.browserHeavy;
    _healthService.markSearchFailure(
      sourceId: sourceId,
      message: message,
      error: error,
      markCooldown: looksLikeBrowserRisk,
    );
  }
}

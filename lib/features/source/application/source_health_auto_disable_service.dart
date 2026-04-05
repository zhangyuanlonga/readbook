import '../../../core/logging/app_logger.dart';
import 'source_health_action_policy_service.dart';
import 'source_health_service.dart';
import 'source_health_system_settings_service.dart';
import 'source_runtime_facade.dart';

class SourceHealthAutoDisableResult {
  const SourceHealthAutoDisableResult({required this.didDisable, this.reason});

  final bool didDisable;
  final String? reason;
}

class SourceHealthAutoDisableService {
  SourceHealthAutoDisableService({
    SourceRuntimeFacade? sourceRuntimeFacade,
    SourceHealthService? sourceHealthService,
    SourceHealthSystemSettingsService? settingsService,
    SourceHealthActionPolicyService? policyService,
    AppLogger? logger,
  }) : _sourceRuntimeFacade =
           sourceRuntimeFacade ?? SourceRuntimeFacade.instance,
       _sourceHealthService =
           sourceHealthService ?? SourceHealthService.instance,
       _settingsService =
           settingsService ?? SourceHealthSystemSettingsService(),
       _policyService =
           policyService ?? const SourceHealthActionPolicyService(),
       _logger = logger ?? AppLogger.instance;

  static final SourceHealthAutoDisableService instance =
      SourceHealthAutoDisableService();

  final SourceRuntimeFacade _sourceRuntimeFacade;
  final SourceHealthService _sourceHealthService;
  final SourceHealthSystemSettingsService _settingsService;
  final SourceHealthActionPolicyService _policyService;
  final AppLogger _logger;

  final Set<String> _disablingSourceIds = <String>{};

  Future<SourceHealthAutoDisableResult> evaluateSource({
    required String sourceId,
    String? sourceName,
    required String trigger,
  }) async {
    final normalizedSourceId = sourceId.trim();
    if (normalizedSourceId.isEmpty) {
      return const SourceHealthAutoDisableResult(didDisable: false);
    }
    final enabled =
        await _settingsService.loadAutoDisableHighRiskSourcesEnabled();
    if (!enabled) {
      return const SourceHealthAutoDisableResult(didDisable: false);
    }
    if (_disablingSourceIds.contains(normalizedSourceId)) {
      return const SourceHealthAutoDisableResult(didDisable: false);
    }

    final snapshot = _sourceHealthService.snapshotFor(normalizedSourceId);
    if (!_policyService.shouldAutoDisable(snapshot)) {
      return const SourceHealthAutoDisableResult(didDisable: false);
    }

    _disablingSourceIds.add(normalizedSourceId);
    final reason = _policyService.buildAutoDisableReason(snapshot);
    try {
      await _sourceRuntimeFacade.setScriptSourceEnabled(
        id: normalizedSourceId,
        enabled: false,
      );
      _logger.warn(
        'Source auto-disabled',
        context: <String, Object?>{
          'sourceId': normalizedSourceId,
          'sourceName': sourceName,
          'trigger': trigger,
          'reason': reason,
        },
      );
      return SourceHealthAutoDisableResult(didDisable: true, reason: reason);
    } finally {
      _disablingSourceIds.remove(normalizedSourceId);
    }
  }
}

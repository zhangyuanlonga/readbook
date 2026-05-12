import 'package:shuxiang_reading_next/domain/entities/script_source.dart';
import 'package:shuxiang_reading_next/domain/entities/source_health.dart';
import 'package:shuxiang_reading_next/domain/repositories/script_source_repository.dart';
import 'package:shuxiang_reading_next/features/source/application/source_health_action_policy_service.dart';
import 'package:shuxiang_reading_next/features/source/application/source_health_auto_disable_service.dart';
import 'package:shuxiang_reading_next/features/source/application/source_health_persistence_service.dart';
import 'package:shuxiang_reading_next/features/source/application/source_health_service.dart';
import 'package:shuxiang_reading_next/features/source/application/source_health_system_settings_service.dart';
import 'package:shuxiang_reading_next/features/source/application/source_runtime_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SourceHealthAutoDisableService', () {
    late SharedPreferences prefs;
    late SourceHealthService healthService;
    late _FakeRuntimeFacade runtimeFacade;
    late SourceHealthSystemSettingsService settingsService;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      prefs = await SharedPreferences.getInstance();
      settingsService = SourceHealthSystemSettingsService(preferences: prefs);
      healthService = SourceHealthService(
        persistenceService: SourceHealthPersistenceService(preferences: prefs),
      );
      runtimeFacade = _FakeRuntimeFacade();
    });

    test('does not auto disable when setting is off', () async {
      healthService.upsert(
        SourceHealthSnapshot(
          sourceId: 'source_a',
          level: SourceHealthLevel.unavailable,
          enabled: true,
          totalFailures: 4,
          consecutiveFailures: 2,
        ),
      );
      final service = SourceHealthAutoDisableService(
        sourceRuntimeFacade: runtimeFacade,
        sourceHealthService: healthService,
        settingsService: settingsService,
        policyService: const SourceHealthActionPolicyService(),
      );

      final result = await service.evaluateSource(
        sourceId: 'source_a',
        sourceName: '源A',
        trigger: 'search',
      );

      expect(result.didDisable, isFalse);
      expect(runtimeFacade.disabledSourceIds, isEmpty);
    });

    test(
      'auto disables unavailable high risk source when setting is on',
      () async {
        await settingsService.saveAutoDisableHighRiskSourcesEnabled(true);
        healthService.upsert(
          SourceHealthSnapshot(
            sourceId: 'source_a',
            level: SourceHealthLevel.unavailable,
            enabled: true,
            totalFailures: 4,
            consecutiveFailures: 2,
            browserRiskCount: 2,
          ),
        );
        final service = SourceHealthAutoDisableService(
          sourceRuntimeFacade: runtimeFacade,
          sourceHealthService: healthService,
          settingsService: settingsService,
          policyService: const SourceHealthActionPolicyService(),
        );

        final result = await service.evaluateSource(
          sourceId: 'source_a',
          sourceName: '源A',
          trigger: 'search',
        );

        expect(result.didDisable, isTrue);
        expect(runtimeFacade.disabledSourceIds, <String>['source_a']);
        expect(result.reason, isNotEmpty);
        final snapshot = healthService.snapshotFor('source_a');
        expect(snapshot.enabled, isFalse);
        expect(snapshot.lastAutoDisableReason, isNotNull);
      },
    );

    test('does not auto disable stale failure snapshot', () async {
      await settingsService.saveAutoDisableHighRiskSourcesEnabled(true);
      healthService.upsert(
        SourceHealthSnapshot(
          sourceId: 'source_a',
          level: SourceHealthLevel.unavailable,
          enabled: true,
          totalFailures: 4,
          consecutiveFailures: 3,
          browserRiskCount: 2,
          lastFailureAt: DateTime.now().subtract(const Duration(days: 2)),
        ),
      );
      final service = SourceHealthAutoDisableService(
        sourceRuntimeFacade: runtimeFacade,
        sourceHealthService: healthService,
        settingsService: settingsService,
        policyService: const SourceHealthActionPolicyService(),
      );

      final result = await service.evaluateSource(
        sourceId: 'source_a',
        sourceName: '源A',
        trigger: 'search',
      );

      expect(result.didDisable, isFalse);
      expect(runtimeFacade.disabledSourceIds, isEmpty);
    });
  });
}

class _FakeRuntimeFacade extends SourceRuntimeFacade {
  _FakeRuntimeFacade()
    : super(scriptSourceRepository: _FakeScriptSourceRepository());

  final List<String> disabledSourceIds = <String>[];

  @override
  Future<void> setScriptSourceEnabled({
    required String id,
    required bool enabled,
  }) async {
    if (!enabled) {
      disabledSourceIds.add(id);
    }
  }
}

class _FakeScriptSourceRepository implements ScriptSourceRepository {
  @override
  Future<void> clear() async {}

  @override
  Future<void> deleteById(String id) async {}

  @override
  Future<List<ScriptSource>> getAll() async => const <ScriptSource>[];

  @override
  Future<ScriptSource?> getById(String id) async => null;

  @override
  Future<void> setEnabled({required String id, required bool enabled}) async {}

  @override
  Future<void> upsert(ScriptSource source) async {}

  @override
  Stream<List<ScriptSource>> watchAll() =>
      const Stream<List<ScriptSource>>.empty();
}

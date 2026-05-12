import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/script_source.dart';
import 'package:shuxiang_reading_next/features/source/application/source_runtime_execution_policy_service.dart';
import 'package:shuxiang_reading_next/features/source/application/source_runtime_warm_state_service.dart';

void main() {
  group('SourceRuntimeExecutionPolicyService', () {
    const service = SourceRuntimeExecutionPolicyService();

    test('uses shared container when source is missing', () {
      final plan = service.resolve(
        source: null,
        step: SourceRuntimeExecutionStep.search,
        scene: SourceRuntimeExecutionScene.search,
        warmState: SourceRuntimeWarmState.cold,
      );

      expect(plan.containerKind, SourceRuntimeExecutionContainerKind.shared);
      expect(plan.serializeStartup, isFalse);
    });

    test('uses request isolated container for enabled search source', () {
      final plan = service.resolve(
        source: _buildSource(enabled: true),
        step: SourceRuntimeExecutionStep.search,
        scene: SourceRuntimeExecutionScene.search,
        warmState: SourceRuntimeWarmState.cold,
      );

      expect(
        plan.containerKind,
        SourceRuntimeExecutionContainerKind.requestIsolated,
      );
      expect(plan.serializeStartup, isTrue);
      expect(plan.markWarmOnSuccess, isTrue);
    });

    test('keeps startup serialization for warm search step', () {
      final plan = service.resolve(
        source: _buildSource(enabled: true),
        step: SourceRuntimeExecutionStep.search,
        scene: SourceRuntimeExecutionScene.search,
        warmState: SourceRuntimeWarmState.warm,
      );

      expect(
        plan.containerKind,
        SourceRuntimeExecutionContainerKind.requestIsolated,
      );
      expect(plan.serializeStartup, isTrue);
      expect(plan.markWarmOnSuccess, isTrue);
    });

    test('disables startup serialization for warm reading step', () {
      final plan = service.resolve(
        source: _buildSource(enabled: true),
        step: SourceRuntimeExecutionStep.content,
        scene: SourceRuntimeExecutionScene.reader,
        warmState: SourceRuntimeWarmState.warm,
      );

      expect(
        plan.containerKind,
        SourceRuntimeExecutionContainerKind.flowIsolated,
      );
      expect(plan.serializeStartup, isFalse);
      expect(plan.markWarmOnSuccess, isFalse);
    });

    test('uses flow isolated container for enabled reading step', () {
      final plan = service.resolve(
        source: _buildSource(enabled: true),
        step: SourceRuntimeExecutionStep.content,
        scene: SourceRuntimeExecutionScene.reader,
        warmState: SourceRuntimeWarmState.cold,
      );

      expect(
        plan.containerKind,
        SourceRuntimeExecutionContainerKind.flowIsolated,
      );
      expect(plan.serializeStartup, isTrue);
      expect(plan.markWarmOnSuccess, isTrue);
    });

    test('falls back to shared container for disabled host source', () {
      final plan = service.resolve(
        source: _buildSource(enabled: false),
        step: SourceRuntimeExecutionStep.detail,
        scene: SourceRuntimeExecutionScene.detail,
        warmState: SourceRuntimeWarmState.unstable,
      );

      expect(plan.containerKind, SourceRuntimeExecutionContainerKind.shared);
    });
  });
}

ScriptSource _buildSource({required bool enabled}) {
  final now = DateTime.parse('2026-04-06T00:00:00.000Z');
  return ScriptSource(
    id: 'source-1',
    name: '测试源',
    sourceCode: 'export default { meta: { name: "测试源" } }',
    enabled: enabled,
    createdAt: now,
    updatedAt: now,
  );
}

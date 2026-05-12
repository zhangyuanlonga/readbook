import '../../../domain/entities/script_source.dart';
import 'source_runtime_warm_state_service.dart';

enum SourceRuntimeExecutionStep {
  search,
  discoverCategories,
  discoverBooks,
  detail,
  chapters,
  content,
}

enum SourceRuntimeExecutionScene {
  search,
  discover,
  detail,
  reader,
  sourceCheck,
}

enum SourceRuntimeExecutionContainerKind {
  shared,
  requestIsolated,
  flowIsolated,
}

class SourceRuntimeExecutionPlan {
  const SourceRuntimeExecutionPlan({
    required this.containerKind,
    required this.warmState,
    this.serializeStartup = false,
    this.markWarmOnSuccess = false,
  });

  final SourceRuntimeExecutionContainerKind containerKind;
  final SourceRuntimeWarmState warmState;
  final bool serializeStartup;
  final bool markWarmOnSuccess;
}

class SourceRuntimeExecutionPolicyService {
  const SourceRuntimeExecutionPolicyService();

  static const SourceRuntimeExecutionPolicyService instance =
      SourceRuntimeExecutionPolicyService();

  SourceRuntimeExecutionPlan resolve({
    required ScriptSource? source,
    required SourceRuntimeExecutionStep step,
    required SourceRuntimeExecutionScene scene,
    required SourceRuntimeWarmState warmState,
  }) {
    if (source == null || !source.enabled) {
      return const SourceRuntimeExecutionPlan(
        containerKind: SourceRuntimeExecutionContainerKind.shared,
        warmState: SourceRuntimeWarmState.cold,
      );
    }

    switch (step) {
      case SourceRuntimeExecutionStep.search:
      case SourceRuntimeExecutionStep.discoverCategories:
      case SourceRuntimeExecutionStep.discoverBooks:
        return SourceRuntimeExecutionPlan(
          containerKind: SourceRuntimeExecutionContainerKind.requestIsolated,
          warmState: warmState,
          // Search/discover currently create fresh request containers, so their
          // startup is still treated conservatively even after a warm hit.
          serializeStartup: true,
          markWarmOnSuccess: true,
        );
      case SourceRuntimeExecutionStep.detail:
      case SourceRuntimeExecutionStep.chapters:
      case SourceRuntimeExecutionStep.content:
        return SourceRuntimeExecutionPlan(
          containerKind: SourceRuntimeExecutionContainerKind.flowIsolated,
          warmState: warmState,
          serializeStartup: warmState != SourceRuntimeWarmState.warm,
          markWarmOnSuccess: warmState != SourceRuntimeWarmState.warm,
        );
    }
  }
}

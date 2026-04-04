part of 'search_service.dart';

class _SearchScheduler {
  const _SearchScheduler({
    required this.maxBudgetCap,
    required this.runtimePlatform,
  });

  final int maxBudgetCap;
  final SearchRuntimePlatform runtimePlatform;

  int resolveBudget(SearchPlanScenario scenario) {
    final scenarioBudget = switch ((runtimePlatform, scenario)) {
      (SearchRuntimePlatform.android, SearchPlanScenario.globalSearch) => 6,
      (SearchRuntimePlatform.android, SearchPlanScenario.switchSource) => 3,
      (SearchRuntimePlatform.android, SearchPlanScenario.autoSwitchSource) => 2,
      (SearchRuntimePlatform.ios, SearchPlanScenario.globalSearch) => 4,
      (SearchRuntimePlatform.ios, SearchPlanScenario.switchSource) => 2,
      (SearchRuntimePlatform.ios, SearchPlanScenario.autoSwitchSource) => 1,
      (SearchRuntimePlatform.macos, SearchPlanScenario.globalSearch) => 3,
      (SearchRuntimePlatform.macos, SearchPlanScenario.switchSource) => 2,
      (SearchRuntimePlatform.macos, SearchPlanScenario.autoSwitchSource) => 1,
      (SearchRuntimePlatform.windows, SearchPlanScenario.globalSearch) => 5,
      (SearchRuntimePlatform.windows, SearchPlanScenario.switchSource) => 3,
      (SearchRuntimePlatform.windows, SearchPlanScenario.autoSwitchSource) => 2,
      (SearchRuntimePlatform.linux, SearchPlanScenario.globalSearch) => 5,
      (SearchRuntimePlatform.linux, SearchPlanScenario.switchSource) => 3,
      (SearchRuntimePlatform.linux, SearchPlanScenario.autoSwitchSource) => 2,
      (_, SearchPlanScenario.globalSearch) => 4,
      (_, SearchPlanScenario.switchSource) => 2,
      (_, SearchPlanScenario.autoSwitchSource) => 1,
    };
    final normalizedCap = maxBudgetCap < 1 ? 1 : maxBudgetCap;
    return scenarioBudget < normalizedCap ? scenarioBudget : normalizedCap;
  }

  int costOf(SearchExecutionProfile profile) {
    return switch (profile) {
      SearchExecutionProfile.httpLight => 1,
      SearchExecutionProfile.jsHeavy => 2,
      SearchExecutionProfile.browserCapable => 3,
      SearchExecutionProfile.browserHeavy => 4,
    };
  }

  Future<void> run({
    required _SearchPlan plan,
    required SearchPlanScenario scenario,
    required SearchCancellationToken? cancellationToken,
    required Future<void> Function(_SearchTarget source) onExecute,
  }) async {
    final totalBudget = resolveBudget(scenario);
    final pending = plan.targets.toList(growable: true);
    final completedCosts = <int>[];
    Completer<void>? completionSignal;
    var runningCount = 0;
    var runningBudget = 0;

    void launchReadyTasks() {
      while (pending.isNotEmpty) {
        if (cancellationToken?.isCancelled ?? false) {
          return;
        }

        final availableBudget = totalBudget - runningBudget;
        var selectedIndex = pending.indexWhere(
          (target) => costOf(target.profile) <= availableBudget,
        );
        if (selectedIndex == -1) {
          if (runningCount == 0) {
            selectedIndex = 0;
          } else {
            break;
          }
        }

        final target = pending.removeAt(selectedIndex);
        final reservedCost = _normalizedCost(target.profile, totalBudget);
        runningCount += 1;
        runningBudget += reservedCost;

        unawaited(() async {
          try {
            await onExecute(target);
          } finally {
            completedCosts.add(reservedCost);
            completionSignal?.complete();
            completionSignal = null;
          }
        }());
      }
    }

    launchReadyTasks();
    while (pending.isNotEmpty || runningCount > 0) {
      if ((cancellationToken?.isCancelled ?? false) && runningCount == 0) {
        break;
      }
      if (completedCosts.isEmpty) {
        completionSignal ??= Completer<void>();
        await completionSignal!.future;
      }
      if (completedCosts.isEmpty) {
        continue;
      }
      final releasedCost = completedCosts.removeAt(0);
      runningCount -= 1;
      runningBudget -= releasedCost;
      if (runningBudget < 0) {
        runningBudget = 0;
      }
      launchReadyTasks();
    }
  }

  int _normalizedCost(SearchExecutionProfile profile, int totalBudget) {
    final raw = costOf(profile);
    return raw > totalBudget ? totalBudget : raw;
  }
}

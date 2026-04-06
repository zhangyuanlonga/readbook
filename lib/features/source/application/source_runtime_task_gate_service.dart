import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../runtime/sources/source_registry.dart';
import 'source_health_service.dart';

enum SourceRuntimeTaskKind {
  detail,
  chapters,
  content,
  discoverCategories,
  discoverBooks,
}

enum SourceRuntimeExecutionProfile {
  httpLight,
  jsHeavy,
  browserCapable,
  browserHeavy,
}

enum SourceRuntimeTaskGatePlatform {
  android,
  ios,
  macos,
  windows,
  linux,
  web,
  unknown,
}

class SourceRuntimeTaskGateService {
  SourceRuntimeTaskGateService({
    SourceHealthService? healthService,
    SourceRuntimeTaskGatePlatform? runtimePlatform,
    int? maxBudgetCap,
  }) : _healthService = healthService ?? SourceHealthService.instance,
       _runtimePlatform = runtimePlatform ?? _inferRuntimePlatform(),
       _maxBudgetCap = maxBudgetCap;

  static final SourceRuntimeTaskGateService instance =
      SourceRuntimeTaskGateService();

  final SourceHealthService _healthService;
  final SourceRuntimeTaskGatePlatform _runtimePlatform;
  final int? _maxBudgetCap;
  final List<_PendingGateTask<dynamic>> _pending =
      <_PendingGateTask<dynamic>>[];

  int _runningBudget = 0;
  int _runningCount = 0;
  bool _pumpScheduled = false;

  Future<T> run<T>({
    required RegisteredSource source,
    required SourceRuntimeTaskKind taskKind,
    required Future<T> Function() action,
  }) {
    final profile = _resolveProfile(source: source, taskKind: taskKind);
    final task = _PendingGateTask<T>(
      sourceId: source.runtime.id,
      taskKind: taskKind,
      profile: profile,
      action: action,
    );
    _pending.add(task);
    _schedulePump();
    return task.completer.future;
  }

  SourceRuntimeExecutionProfile _resolveProfile({
    required RegisteredSource source,
    required SourceRuntimeTaskKind taskKind,
  }) {
    final manifest = source.definition.manifest;
    final capabilities =
        manifest.capabilities
            .map((item) => item.trim().toLowerCase())
            .where((item) => item.isNotEmpty)
            .toSet();
    final snapshot = _healthService.snapshotFor(source.runtime.id);

    final declaresBrowser =
        capabilities.contains('browser') ||
        capabilities.contains('webview') ||
        capabilities.contains('challenge');
    final declaresHeavy =
        capabilities.contains('js-heavy') ||
        capabilities.contains('script-heavy');
    final browserRisk = snapshot.browserRiskCount > 0;
    final repeatedFailures = snapshot.totalFailures >= 2;

    if (declaresBrowser || browserRisk) {
      if (taskKind == SourceRuntimeTaskKind.content ||
          taskKind == SourceRuntimeTaskKind.discoverBooks) {
        return SourceRuntimeExecutionProfile.browserHeavy;
      }
      return SourceRuntimeExecutionProfile.browserCapable;
    }
    if (declaresHeavy || repeatedFailures) {
      return SourceRuntimeExecutionProfile.jsHeavy;
    }
    return SourceRuntimeExecutionProfile.httpLight;
  }

  int _resolveBudget() {
    final platformBudget = switch (_runtimePlatform) {
      SourceRuntimeTaskGatePlatform.android => 4,
      SourceRuntimeTaskGatePlatform.ios => 2,
      SourceRuntimeTaskGatePlatform.macos => 2,
      SourceRuntimeTaskGatePlatform.windows => 3,
      SourceRuntimeTaskGatePlatform.linux => 3,
      _ => 2,
    };
    final cap = _maxBudgetCap;
    if (cap == null || cap < 1) {
      return platformBudget;
    }
    return platformBudget.clamp(1, cap);
  }

  int _costOf(SourceRuntimeExecutionProfile profile) {
    return switch (profile) {
      SourceRuntimeExecutionProfile.httpLight => 1,
      SourceRuntimeExecutionProfile.jsHeavy => 2,
      SourceRuntimeExecutionProfile.browserCapable => 3,
      SourceRuntimeExecutionProfile.browserHeavy => 4,
    };
  }

  void _schedulePump() {
    if (_pumpScheduled) {
      return;
    }
    _pumpScheduled = true;
    scheduleMicrotask(() {
      _pumpScheduled = false;
      _pumpQueue();
    });
  }

  void _pumpQueue() {
    if (_pending.isEmpty) {
      return;
    }
    final totalBudget = _resolveBudget();

    while (_pending.isNotEmpty) {
      final availableBudget = totalBudget - _runningBudget;
      var selectedIndex = _pending.indexWhere(
        (task) => _normalizedCost(task.profile, totalBudget) <= availableBudget,
      );
      if (selectedIndex == -1) {
        if (_runningCount == 0) {
          selectedIndex = 0;
        } else {
          return;
        }
      }

      final task = _pending.removeAt(selectedIndex);
      final reservedCost = _normalizedCost(task.profile, totalBudget);
      _runningCount += 1;
      _runningBudget += reservedCost;

      unawaited(() async {
        try {
          task.completer.complete(await task.action());
        } catch (error, stackTrace) {
          task.completer.completeError(error, stackTrace);
        } finally {
          _runningCount -= 1;
          _runningBudget -= reservedCost;
          if (_runningBudget < 0) {
            _runningBudget = 0;
          }
          _schedulePump();
        }
      }());
    }
  }

  int _normalizedCost(SourceRuntimeExecutionProfile profile, int totalBudget) {
    final raw = _costOf(profile);
    return raw > totalBudget ? totalBudget : raw;
  }

  static SourceRuntimeTaskGatePlatform _inferRuntimePlatform() {
    if (kIsWeb) {
      return SourceRuntimeTaskGatePlatform.web;
    }
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => SourceRuntimeTaskGatePlatform.android,
      TargetPlatform.iOS => SourceRuntimeTaskGatePlatform.ios,
      TargetPlatform.macOS => SourceRuntimeTaskGatePlatform.macos,
      TargetPlatform.windows => SourceRuntimeTaskGatePlatform.windows,
      TargetPlatform.linux => SourceRuntimeTaskGatePlatform.linux,
      _ => SourceRuntimeTaskGatePlatform.unknown,
    };
  }
}

class _PendingGateTask<T> {
  _PendingGateTask({
    required this.sourceId,
    required this.taskKind,
    required this.profile,
    required this.action,
  });

  final String sourceId;
  final SourceRuntimeTaskKind taskKind;
  final SourceRuntimeExecutionProfile profile;
  final Future<T> Function() action;
  final Completer<T> completer = Completer<T>();
}

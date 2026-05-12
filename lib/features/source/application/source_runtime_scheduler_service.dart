import 'dart:async';

import '../../../core/logging/app_logger.dart';

enum SourceRuntimeSchedulerScene {
  bookshelfBackground,
  detail,
  reader,
  discover,
  search,
  browserInteractive,
  sourceCheck,
}

enum SourceRuntimeTaskPriority {
  backgroundRefresh,
  diagnostic,
  foregroundInteractive,
  foregroundCritical,
}

enum SourceRuntimeTaskDisposition { run, queue, reuse, cancel }

class SourceRuntimeSchedulerService {
  SourceRuntimeSchedulerService({AppLogger? logger})
    : _logger = logger ?? AppLogger.instance;

  static final SourceRuntimeSchedulerService instance =
      SourceRuntimeSchedulerService();

  final AppLogger _logger;
  final Map<String, int> _backgroundEpochByKey = <String, int>{};
  final List<_ActiveScheduledTask> _activeTasks = <_ActiveScheduledTask>[];

  SourceRuntimeTaskPriority priorityOf(SourceRuntimeSchedulerScene scene) {
    return switch (scene) {
      SourceRuntimeSchedulerScene.bookshelfBackground =>
        SourceRuntimeTaskPriority.backgroundRefresh,
      SourceRuntimeSchedulerScene.sourceCheck =>
        SourceRuntimeTaskPriority.diagnostic,
      SourceRuntimeSchedulerScene.detail ||
      SourceRuntimeSchedulerScene.discover ||
      SourceRuntimeSchedulerScene.search =>
        SourceRuntimeTaskPriority.foregroundInteractive,
      SourceRuntimeSchedulerScene.browserInteractive ||
      SourceRuntimeSchedulerScene.reader =>
        SourceRuntimeTaskPriority.foregroundCritical,
    };
  }

  SourceRuntimeTaskDisposition resolveForegroundDisposition({
    required SourceRuntimeSchedulerScene requestingScene,
    required SourceRuntimeSchedulerScene conflictingScene,
  }) {
    final requestingPriority = priorityOf(requestingScene);
    final conflictingPriority = priorityOf(conflictingScene);
    if (requestingPriority.index > conflictingPriority.index) {
      return SourceRuntimeTaskDisposition.cancel;
    }
    if (requestingPriority == conflictingPriority) {
      return SourceRuntimeTaskDisposition.queue;
    }
    return SourceRuntimeTaskDisposition.run;
  }

  String conflictKeyForSource(String sourceId) {
    return sourceId.trim();
  }

  String conflictKeyForBook({
    required String sourceId,
    required String detailUrl,
    required String bookId,
  }) {
    final normalizedSourceId = sourceId.trim();
    final normalizedDetailUrl = detailUrl.trim();
    if (normalizedSourceId.isEmpty) {
      return '';
    }
    if (normalizedDetailUrl.isNotEmpty) {
      return '$normalizedSourceId::detail:${Uri.encodeComponent(normalizedDetailUrl)}';
    }
    final normalizedBookId = bookId.trim();
    if (normalizedBookId.isNotEmpty) {
      return '$normalizedSourceId::book:${Uri.encodeComponent(normalizedBookId)}';
    }
    return normalizedSourceId;
  }

  Future<SourceRuntimeTaskLease?> acquire({
    required SourceRuntimeSchedulerScene scene,
    required Iterable<String> conflictKeys,
    bool cancelIfBlockedByHigherPriority = false,
  }) async {
    final normalizedKeys = conflictKeys
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (normalizedKeys.isEmpty) {
      return null;
    }

    final priority = priorityOf(scene);
    while (true) {
      _purgeReleasedTasks();
      final conflicts = _activeTasks
          .where((task) => task.conflictKeys.any(normalizedKeys.contains))
          .toList(growable: false);
      if (conflicts.isEmpty) {
        return _acquireFreshLease(
          scene: scene,
          priority: priority,
          normalizedKeys: normalizedKeys,
        );
      }

      _ActiveScheduledTask? reusableTask;
      for (final task in conflicts) {
        if (_canReuseWith(task, scene, normalizedKeys)) {
          reusableTask = task;
          break;
        }
      }
      if (reusableTask != null) {
        final blockingNonReusable = conflicts
            .where(
              (task) =>
                  !identical(task, reusableTask) &&
                  !task.released &&
                  task.priority.index >= priority.index,
            )
            .toList(growable: false);
        if (blockingNonReusable.isEmpty) {
          return _acquireReuseLease(
            task: reusableTask,
            scene: scene,
            priority: priority,
            normalizedKeys: normalizedKeys,
          );
        }
      }

      final lowerPriorityConflicts = conflicts
          .where((task) => priority.index > task.priority.index)
          .toList(growable: false);
      if (lowerPriorityConflicts.isNotEmpty) {
        for (final key in normalizedKeys) {
          cancelLowerPriorityWorkFor(conflictKey: key, byScene: scene);
        }
      }

      final blockingConflicts = conflicts
          .where((task) => !task.released && task.priority.index >= priority.index)
          .toList(growable: false);

      if (blockingConflicts.isEmpty && lowerPriorityConflicts.isNotEmpty) {
        await Future.wait<void>(
          lowerPriorityConflicts
              .map((task) => task.done.future)
              .cast<Future<void>>()
              .toList(growable: false),
        );
        continue;
      }

      if (cancelIfBlockedByHigherPriority) {
        _logger.info(
          'Skipped source runtime task lease acquisition',
          context: <String, Object?>{
            'scene': scene.name,
            'priority': priority.name,
            'conflictKeys': normalizedKeys.join(','),
          },
        );
        return null;
      }

      await Future.any<void>(
        conflicts
            .map((task) => task.done.future)
            .cast<Future<void>>()
            .toList(growable: false),
      );
    }
  }

  int captureBackgroundEpoch(String conflictKey) {
    final normalized = conflictKey.trim();
    if (normalized.isEmpty) {
      return 0;
    }
    return _backgroundEpochByKey[normalized] ?? 0;
  }

  bool hasBackgroundConflictAdvanced({
    required String conflictKey,
    required int capturedEpoch,
  }) {
    final normalized = conflictKey.trim();
    if (normalized.isEmpty) {
      return false;
    }
    return (_backgroundEpochByKey[normalized] ?? 0) != capturedEpoch;
  }

  void cancelLowerPriorityWorkFor({
    required String conflictKey,
    required SourceRuntimeSchedulerScene byScene,
  }) {
    final normalized = conflictKey.trim();
    if (normalized.isEmpty) {
      return;
    }
    final nextEpoch = (_backgroundEpochByKey[normalized] ?? 0) + 1;
    _backgroundEpochByKey[normalized] = nextEpoch;
    _logger.info(
      'Cancelled lower-priority background source task',
      context: <String, Object?>{
        'conflictKey': normalized,
        'byScene': byScene.name,
        'priority': priorityOf(byScene).name,
        'epoch': nextEpoch,
      },
    );
  }

  void clearAll() {
    _backgroundEpochByKey.clear();
    for (final task in _activeTasks) {
      while (!task.released) {
        task.releaseHolder();
      }
    }
    _activeTasks.clear();
  }

  void _purgeReleasedTasks() {
    _activeTasks.removeWhere((task) => task.released);
  }

  bool _canReuseWith(
    _ActiveScheduledTask task,
    SourceRuntimeSchedulerScene scene,
    List<String> normalizedKeys,
  ) {
    if (!_isReusableScene(scene) || !_isReusableScene(task.scene)) {
      return false;
    }
    if (task.conflictKeys.length != normalizedKeys.length) {
      return false;
    }
    return task.conflictKeys.every(normalizedKeys.contains);
  }

  bool _isReusableScene(SourceRuntimeSchedulerScene scene) {
    return scene == SourceRuntimeSchedulerScene.detail ||
        scene == SourceRuntimeSchedulerScene.reader;
  }

  SourceRuntimeTaskLease _acquireFreshLease({
    required SourceRuntimeSchedulerScene scene,
    required SourceRuntimeTaskPriority priority,
    required List<String> normalizedKeys,
  }) {
    final task = _ActiveScheduledTask(
      scene: scene,
      priority: priority,
      conflictKeys: normalizedKeys,
    );
    _activeTasks.add(task);
    _logger.info(
      'Acquired source runtime task lease',
      context: <String, Object?>{
        'scene': scene.name,
        'priority': priority.name,
        'disposition': SourceRuntimeTaskDisposition.run.name,
        'conflictKeys': normalizedKeys.join(','),
      },
    );
    return SourceRuntimeTaskLease._(
      onRelease: () {
        if (task.released) {
          return;
        }
        task.releaseHolder();
        _purgeReleasedTasks();
        _logger.info(
          'Released source runtime task lease',
          context: <String, Object?>{
            'scene': scene.name,
            'priority': priority.name,
            'conflictKeys': normalizedKeys.join(','),
          },
        );
      },
    );
  }

  SourceRuntimeTaskLease _acquireReuseLease({
    required _ActiveScheduledTask task,
    required SourceRuntimeSchedulerScene scene,
    required SourceRuntimeTaskPriority priority,
    required List<String> normalizedKeys,
  }) {
    task.acquireHolder();
    _logger.info(
      'Reused source runtime task lease',
      context: <String, Object?>{
        'scene': scene.name,
        'priority': priority.name,
        'disposition': SourceRuntimeTaskDisposition.reuse.name,
        'conflictKeys': normalizedKeys.join(','),
        'ownerScene': task.scene.name,
      },
    );
    return SourceRuntimeTaskLease._(
      onRelease: () {
        if (task.released) {
          return;
        }
        task.releaseHolder();
        _purgeReleasedTasks();
        _logger.info(
          'Released source runtime task lease',
          context: <String, Object?>{
            'scene': scene.name,
            'priority': priority.name,
            'conflictKeys': normalizedKeys.join(','),
          },
        );
      },
    );
  }
}

class SourceRuntimeTaskLease {
  SourceRuntimeTaskLease._({required void Function() onRelease})
    : _onRelease = onRelease;

  final void Function() _onRelease;
  bool _released = false;

  void release() {
    if (_released) {
      return;
    }
    _released = true;
    _onRelease();
  }
}

class _ActiveScheduledTask {
  _ActiveScheduledTask({
    required this.scene,
    required this.priority,
    required this.conflictKeys,
  }) : _holderCount = 1;

  final SourceRuntimeSchedulerScene scene;
  final SourceRuntimeTaskPriority priority;
  final List<String> conflictKeys;
  final Completer<void> done = Completer<void>();
  bool released = false;
  int _holderCount;

  void acquireHolder() {
    if (released) {
      return;
    }
    _holderCount += 1;
  }

  void releaseHolder() {
    if (released) {
      return;
    }
    _holderCount -= 1;
    if (_holderCount > 0) {
      return;
    }
    released = true;
    if (!done.isCompleted) {
      done.complete();
    }
  }
}

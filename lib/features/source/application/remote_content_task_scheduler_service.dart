import 'dart:async';

import '../../../core/logging/app_logger.dart';

enum RemoteContentTaskScene {
  bookshelfBackground,
  detail,
  reader,
  discover,
  search,
  browserInteractive,
  sourceCheck,
}

enum RemoteContentTaskPriority {
  backgroundRefresh,
  diagnostic,
  foregroundInteractive,
  foregroundCritical,
}

enum RemoteContentTaskDisposition { run, queue, reuse, cancel }

class RemoteContentTaskSchedulerService {
  RemoteContentTaskSchedulerService({AppLogger? logger})
    : _logger = logger ?? AppLogger.instance;

  static final RemoteContentTaskSchedulerService instance =
      RemoteContentTaskSchedulerService();

  final AppLogger _logger;
  final Map<String, int> _backgroundEpochByKey = <String, int>{};
  final List<_ActiveScheduledTask> _activeTasks = <_ActiveScheduledTask>[];

  RemoteContentTaskPriority priorityOf(RemoteContentTaskScene scene) {
    return switch (scene) {
      RemoteContentTaskScene.bookshelfBackground =>
        RemoteContentTaskPriority.backgroundRefresh,
      RemoteContentTaskScene.sourceCheck =>
        RemoteContentTaskPriority.diagnostic,
      RemoteContentTaskScene.detail ||
      RemoteContentTaskScene.discover ||
      RemoteContentTaskScene
          .search => RemoteContentTaskPriority.foregroundInteractive,
      RemoteContentTaskScene.browserInteractive ||
      RemoteContentTaskScene
          .reader => RemoteContentTaskPriority.foregroundCritical,
    };
  }

  RemoteContentTaskDisposition resolveForegroundDisposition({
    required RemoteContentTaskScene requestingScene,
    required RemoteContentTaskScene conflictingScene,
  }) {
    final requestingPriority = priorityOf(requestingScene);
    final conflictingPriority = priorityOf(conflictingScene);
    if (requestingPriority.index > conflictingPriority.index) {
      return RemoteContentTaskDisposition.cancel;
    }
    if (requestingPriority == conflictingPriority) {
      return RemoteContentTaskDisposition.queue;
    }
    return RemoteContentTaskDisposition.run;
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

  Future<RemoteContentTaskLease?> acquire({
    required RemoteContentTaskScene scene,
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
          .where(
            (task) => !task.released && task.priority.index >= priority.index,
          )
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
          'Skipped remote content task lease acquisition',
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
    required RemoteContentTaskScene byScene,
  }) {
    final normalized = conflictKey.trim();
    if (normalized.isEmpty) {
      return;
    }
    final nextEpoch = (_backgroundEpochByKey[normalized] ?? 0) + 1;
    _backgroundEpochByKey[normalized] = nextEpoch;
    _logger.info(
      'Cancelled lower-priority background remote content task',
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
    RemoteContentTaskScene scene,
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

  bool _isReusableScene(RemoteContentTaskScene scene) {
    return scene == RemoteContentTaskScene.detail ||
        scene == RemoteContentTaskScene.reader;
  }

  RemoteContentTaskLease _acquireFreshLease({
    required RemoteContentTaskScene scene,
    required RemoteContentTaskPriority priority,
    required List<String> normalizedKeys,
  }) {
    final task = _ActiveScheduledTask(
      scene: scene,
      priority: priority,
      conflictKeys: normalizedKeys,
    );
    _activeTasks.add(task);
    _logger.info(
      'Acquired remote content task lease',
      context: <String, Object?>{
        'scene': scene.name,
        'priority': priority.name,
        'disposition': RemoteContentTaskDisposition.run.name,
        'conflictKeys': normalizedKeys.join(','),
      },
    );
    return RemoteContentTaskLease._(
      onRelease: () {
        if (task.released) {
          return;
        }
        task.releaseHolder();
        _purgeReleasedTasks();
        _logger.info(
          'Released remote content task lease',
          context: <String, Object?>{
            'scene': scene.name,
            'priority': priority.name,
            'conflictKeys': normalizedKeys.join(','),
          },
        );
      },
    );
  }

  RemoteContentTaskLease _acquireReuseLease({
    required _ActiveScheduledTask task,
    required RemoteContentTaskScene scene,
    required RemoteContentTaskPriority priority,
    required List<String> normalizedKeys,
  }) {
    task.acquireHolder();
    _logger.info(
      'Reused remote content task lease',
      context: <String, Object?>{
        'scene': scene.name,
        'priority': priority.name,
        'disposition': RemoteContentTaskDisposition.reuse.name,
        'conflictKeys': normalizedKeys.join(','),
        'ownerScene': task.scene.name,
      },
    );
    return RemoteContentTaskLease._(
      onRelease: () {
        if (task.released) {
          return;
        }
        task.releaseHolder();
        _purgeReleasedTasks();
        _logger.info(
          'Released remote content task lease',
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

class RemoteContentTaskLease {
  RemoteContentTaskLease._({required void Function() onRelease})
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

  final RemoteContentTaskScene scene;
  final RemoteContentTaskPriority priority;
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

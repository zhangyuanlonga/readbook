import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/app_task_status.dart';

enum AppTaskPriority { immediate, userInitiated, background }

enum AppTaskChannel {
  reader,
  localBookImport,
  localBookIndex,
  resourceImport,
  resourceScan,
  sync,
  maintenance,
  other,
}

@immutable
class AppTaskSnapshot {
  const AppTaskSnapshot({
    required this.id,
    required this.status,
    required this.channel,
    required this.priority,
    required this.createdAt,
    required this.updatedAt,
    this.canCancel = false,
    this.canRetry = false,
    this.recoveryKey,
  });

  final String id;
  final AppTaskStatusData status;
  final AppTaskChannel channel;
  final AppTaskPriority priority;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool canCancel;
  final bool canRetry;
  final String? recoveryKey;

  bool get isFinished => status.isFinished;

  AppTaskSnapshot copyWith({
    AppTaskStatusData? status,
    AppTaskChannel? channel,
    AppTaskPriority? priority,
    DateTime? updatedAt,
    bool? canCancel,
    bool? canRetry,
    Object? recoveryKey = _sentinel,
  }) {
    return AppTaskSnapshot(
      id: id,
      status: status ?? this.status,
      channel: channel ?? this.channel,
      priority: priority ?? this.priority,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      canCancel: canCancel ?? this.canCancel,
      canRetry: canRetry ?? this.canRetry,
      recoveryKey:
          identical(recoveryKey, _sentinel)
              ? this.recoveryKey
              : recoveryKey as String?,
    );
  }
}

class AppTaskManager extends ChangeNotifier {
  AppTaskManager({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  final Map<String, AppTaskSnapshot> _tasks = <String, AppTaskSnapshot>{};

  List<AppTaskSnapshot> get tasks {
    final items = _tasks.values.toList(growable: false);
    items.sort(_compareTasks);
    return items;
  }

  AppTaskSnapshot? taskById(String id) => _tasks[id];

  AppTaskSnapshot? get activeTask {
    for (final task in tasks) {
      if (!task.isFinished) {
        return task;
      }
    }
    return null;
  }

  AppTaskSnapshot startTask({
    required String id,
    required AppTaskStatusData status,
    required AppTaskChannel channel,
    AppTaskPriority priority = AppTaskPriority.userInitiated,
    bool canCancel = false,
    bool canRetry = false,
    String? recoveryKey,
  }) {
    final now = _now();
    final task = AppTaskSnapshot(
      id: id,
      status: status,
      channel: channel,
      priority: priority,
      createdAt: _tasks[id]?.createdAt ?? now,
      updatedAt: now,
      canCancel: canCancel,
      canRetry: canRetry,
      recoveryKey: recoveryKey,
    );
    _tasks[id] = task;
    notifyListeners();
    return task;
  }

  AppTaskSnapshot? updateTask(
    String id,
    AppTaskStatusData status, {
    bool? canCancel,
    bool? canRetry,
    Object? recoveryKey = _sentinel,
  }) {
    final current = _tasks[id];
    if (current == null) {
      return null;
    }
    final next = current.copyWith(
      status: status,
      updatedAt: _now(),
      canCancel: canCancel,
      canRetry: canRetry,
      recoveryKey: recoveryKey,
    );
    _tasks[id] = next;
    notifyListeners();
    return next;
  }

  AppTaskSnapshot? cancelTask(String id, {String message = '任务已取消'}) {
    final current = _tasks[id];
    if (current == null || current.isFinished) {
      return current;
    }
    return updateTask(
      id,
      current.status.copyWith(
        message: message,
        result: AppTaskStatusResult.cancelled,
      ),
      canCancel: false,
    );
  }

  AppTaskSnapshot? removeTask(String id) {
    final removed = _tasks.remove(id);
    if (removed != null) {
      notifyListeners();
    }
    return removed;
  }

  void clearFinished() {
    final before = _tasks.length;
    _tasks.removeWhere((_, task) => task.isFinished);
    if (_tasks.length != before) {
      notifyListeners();
    }
  }

  int _compareTasks(AppTaskSnapshot a, AppTaskSnapshot b) {
    final priorityCompare = _priorityRank(
      a.priority,
    ).compareTo(_priorityRank(b.priority));
    if (priorityCompare != 0) {
      return priorityCompare;
    }
    return b.updatedAt.compareTo(a.updatedAt);
  }

  int _priorityRank(AppTaskPriority priority) {
    return switch (priority) {
      AppTaskPriority.immediate => 0,
      AppTaskPriority.userInitiated => 1,
      AppTaskPriority.background => 2,
    };
  }
}

const Object _sentinel = Object();

final appTaskManagerProvider = ChangeNotifierProvider<AppTaskManager>((ref) {
  return AppTaskManager();
});

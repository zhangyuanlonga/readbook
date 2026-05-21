import 'dart:math';

import 'reader_resource_budget.dart';

enum ReaderPreloadTaskType { content, pagination, image }

enum ReaderPreloadTaskPriority { current, nearby, far }

class ReaderPreloadTask {
  const ReaderPreloadTask({
    required this.type,
    required this.chapterIndex,
    required this.priority,
  });

  final ReaderPreloadTaskType type;
  final int chapterIndex;
  final ReaderPreloadTaskPriority priority;

  String get identity => identityFor(type: type, chapterIndex: chapterIndex);

  static String identityFor({
    required ReaderPreloadTaskType type,
    required int chapterIndex,
  }) {
    return '${type.name}:$chapterIndex';
  }
}

class ReaderPreloadPlan {
  const ReaderPreloadPlan(this.tasks);

  final List<ReaderPreloadTask> tasks;

  bool get isEmpty => tasks.isEmpty;

  Iterable<int> chapterIndexesFor(ReaderPreloadTaskType type) sync* {
    final seen = <int>{};
    for (final task in tasks) {
      if (task.type == type && seen.add(task.chapterIndex)) {
        yield task.chapterIndex;
      }
    }
  }
}

class ReaderPreloadFailureMemory {
  ReaderPreloadFailureMemory({
    this.maxFailureCount = 2,
    this.cooldown = const Duration(minutes: 5),
  });

  final int maxFailureCount;
  final Duration cooldown;
  final Map<String, _ReaderPreloadFailure> _failures = {};

  bool shouldSkip(String identity, {DateTime? now}) {
    final failure = _failures[identity];
    if (failure == null || failure.count < maxFailureCount) {
      return false;
    }
    final effectiveNow = now ?? DateTime.now();
    if (effectiveNow.difference(failure.lastFailureAt) >= cooldown) {
      _failures.remove(identity);
      return false;
    }
    return true;
  }

  void recordFailure(String identity, {DateTime? now}) {
    final effectiveNow = now ?? DateTime.now();
    final previous = _failures[identity];
    _failures[identity] = _ReaderPreloadFailure(
      count: (previous?.count ?? 0) + 1,
      lastFailureAt: effectiveNow,
    );
  }

  void recordSuccess(String identity) {
    _failures.remove(identity);
  }

  int failureCount(String identity) => _failures[identity]?.count ?? 0;
}

class ReaderPreloadController {
  const ReaderPreloadController();

  int maxConcurrentTasksFor(
    ReaderPreloadTaskType type,
    ReaderResourceBudget budget,
  ) {
    return switch (type) {
      ReaderPreloadTaskType.content => budget.chapterDownloadConcurrency,
      ReaderPreloadTaskType.pagination =>
        budget.webViewConcurrency <= 0 ? 0 : 1,
      ReaderPreloadTaskType.image =>
        budget.chapterDownloadConcurrency <= 0
            ? 0
            : min(2, budget.chapterDownloadConcurrency),
    };
  }

  ReaderPreloadPlan buildChapterPlan({
    required int currentChapterIndex,
    required int chapterCount,
    required ReaderResourceBudget budget,
    required bool isLocalSource,
    required bool isInBookshelf,
    required int maxForwardChapterCount,
    required int maxBackwardChapterCount,
    required int bookshelfForwardChapterCount,
    bool includeCurrentChapter = false,
    bool includePaginationWarmup = true,
    bool includeImageWarmup = false,
    ReaderPreloadFailureMemory? failureMemory,
    DateTime? now,
  }) {
    if (chapterCount <= 0 ||
        currentChapterIndex < 0 ||
        currentChapterIndex >= chapterCount) {
      return const ReaderPreloadPlan(<ReaderPreloadTask>[]);
    }

    final forwardCount =
        !isLocalSource && isInBookshelf && budget.allowFarPrefetch
            ? bookshelfForwardChapterCount
            : min(maxForwardChapterCount, budget.forwardPreloadChapterCount);
    final backwardCount = min(
      maxBackwardChapterCount,
      budget.backwardPreloadChapterCount,
    );
    final effectiveForwardCount = isLocalSource ? min(forwardCount, 2) : forwardCount;
    final effectiveBackwardCount =
        isLocalSource ? min(backwardCount, 1) : backwardCount;

    final chapterTargets = <_ReaderPreloadChapterTarget>[];
    final seenIndexes = <int>{};

    void addTarget(int index, ReaderPreloadTaskPriority priority) {
      if (index >= 0 && index < chapterCount && seenIndexes.add(index)) {
        chapterTargets.add(
          _ReaderPreloadChapterTarget(index: index, priority: priority),
        );
      }
    }

    if (includeCurrentChapter) {
      addTarget(currentChapterIndex, ReaderPreloadTaskPriority.current);
    }

    final maxDistance = max(effectiveForwardCount, effectiveBackwardCount);
    for (var offset = 1; offset <= maxDistance; offset++) {
      final priority =
          offset == 1
              ? ReaderPreloadTaskPriority.nearby
              : ReaderPreloadTaskPriority.far;
      if (offset <= effectiveForwardCount) {
        addTarget(currentChapterIndex + offset, priority);
      }
      if (offset <= effectiveBackwardCount) {
        addTarget(currentChapterIndex - offset, priority);
      }
    }

    final taskTypes = <ReaderPreloadTaskType>[
      ReaderPreloadTaskType.content,
      if (includePaginationWarmup) ReaderPreloadTaskType.pagination,
      if (includeImageWarmup) ReaderPreloadTaskType.image,
    ];
    final tasks = <ReaderPreloadTask>[];
    final effectiveNow = now ?? DateTime.now();
    for (final target in chapterTargets) {
      for (final type in taskTypes) {
        final identity = ReaderPreloadTask.identityFor(
          type: type,
          chapterIndex: target.index,
        );
        if (failureMemory?.shouldSkip(identity, now: effectiveNow) ?? false) {
          continue;
        }
        tasks.add(
          ReaderPreloadTask(
            type: type,
            chapterIndex: target.index,
            priority: target.priority,
          ),
        );
      }
    }

    return ReaderPreloadPlan(List<ReaderPreloadTask>.unmodifiable(tasks));
  }
}

class _ReaderPreloadChapterTarget {
  const _ReaderPreloadChapterTarget({
    required this.index,
    required this.priority,
  });

  final int index;
  final ReaderPreloadTaskPriority priority;
}

class _ReaderPreloadFailure {
  const _ReaderPreloadFailure({
    required this.count,
    required this.lastFailureAt,
  });

  final int count;
  final DateTime lastFailureAt;
}

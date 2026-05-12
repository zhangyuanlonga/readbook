import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_preload_controller.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_resource_budget.dart';

void main() {
  group('ReaderPreloadController', () {
    const controller = ReaderPreloadController();

    test(
      'prioritizes current and forward nearby chapters before older ones',
      () {
        final plan = controller.buildChapterPlan(
          currentChapterIndex: 5,
          chapterCount: 10,
          budget: const ReaderResourceBudgetResolver().resolve(
            const ReaderResourceBudgetInput(),
          ),
          isLocalSource: false,
          isInBookshelf: false,
          maxForwardChapterCount: 3,
          maxBackwardChapterCount: 1,
          bookshelfForwardChapterCount: 8,
          includeCurrentChapter: true,
          includePaginationWarmup: false,
        );

        expect(plan.chapterIndexesFor(ReaderPreloadTaskType.content), <int>[
          5,
          6,
          4,
          7,
          8,
        ]);
        expect(plan.tasks.first.priority, ReaderPreloadTaskPriority.current);
      },
    );

    test('low battery budget constrains background preload range', () {
      final plan = controller.buildChapterPlan(
        currentChapterIndex: 5,
        chapterCount: 10,
        budget: const ReaderResourceBudgetResolver().resolve(
          const ReaderResourceBudgetInput(
            batteryTier: ReaderBatteryTier.lowBattery,
            scene: ReaderWorkScene.backgroundPrefetch,
          ),
        ),
        isLocalSource: false,
        isInBookshelf: false,
        maxForwardChapterCount: 3,
        maxBackwardChapterCount: 1,
        bookshelfForwardChapterCount: 8,
      );

      expect(plan.chapterIndexesFor(ReaderPreloadTaskType.content), <int>[6]);
    });

    test('splits content pagination and image warmup tasks', () {
      final plan = controller.buildChapterPlan(
        currentChapterIndex: 1,
        chapterCount: 4,
        budget: const ReaderResourceBudgetResolver().resolve(
          const ReaderResourceBudgetInput(),
        ),
        isLocalSource: false,
        isInBookshelf: false,
        maxForwardChapterCount: 1,
        maxBackwardChapterCount: 0,
        bookshelfForwardChapterCount: 8,
        includeImageWarmup: true,
      );

      expect(plan.tasks.map((task) => task.type), <ReaderPreloadTaskType>[
        ReaderPreloadTaskType.content,
        ReaderPreloadTaskType.pagination,
        ReaderPreloadTaskType.image,
      ]);
    });

    test('exposes per task type concurrency from resource budget', () {
      final budget = const ReaderResourceBudgetResolver().resolve(
        const ReaderResourceBudgetInput(),
      );

      expect(
        controller.maxConcurrentTasksFor(ReaderPreloadTaskType.content, budget),
        budget.chapterDownloadConcurrency,
      );
      expect(
        controller.maxConcurrentTasksFor(
          ReaderPreloadTaskType.pagination,
          budget,
        ),
        1,
      );
      expect(
        controller.maxConcurrentTasksFor(ReaderPreloadTaskType.image, budget),
        lessThanOrEqualTo(2),
      );
    });

    test('failure memory suppresses repeated failing task during cooldown', () {
      final memory = ReaderPreloadFailureMemory(
        maxFailureCount: 2,
        cooldown: const Duration(minutes: 5),
      );
      final now = DateTime(2026, 5, 9, 10);
      final identity = ReaderPreloadTask.identityFor(
        type: ReaderPreloadTaskType.content,
        chapterIndex: 2,
      );
      memory
        ..recordFailure(identity, now: now)
        ..recordFailure(identity, now: now.add(const Duration(seconds: 1)));

      final suppressed = controller.buildChapterPlan(
        currentChapterIndex: 1,
        chapterCount: 4,
        budget: const ReaderResourceBudgetResolver().resolve(
          const ReaderResourceBudgetInput(),
        ),
        isLocalSource: false,
        isInBookshelf: false,
        maxForwardChapterCount: 1,
        maxBackwardChapterCount: 0,
        bookshelfForwardChapterCount: 8,
        includePaginationWarmup: false,
        failureMemory: memory,
        now: now.add(const Duration(minutes: 1)),
      );

      expect(suppressed.tasks, isEmpty);

      final retried = controller.buildChapterPlan(
        currentChapterIndex: 1,
        chapterCount: 4,
        budget: const ReaderResourceBudgetResolver().resolve(
          const ReaderResourceBudgetInput(),
        ),
        isLocalSource: false,
        isInBookshelf: false,
        maxForwardChapterCount: 1,
        maxBackwardChapterCount: 0,
        bookshelfForwardChapterCount: 8,
        includePaginationWarmup: false,
        failureMemory: memory,
        now: now.add(const Duration(minutes: 6)),
      );

      expect(retried.chapterIndexesFor(ReaderPreloadTaskType.content), <int>[
        2,
      ]);
    });
  });
}

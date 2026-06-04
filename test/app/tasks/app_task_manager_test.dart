import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/app/tasks/app_task_manager.dart';
import 'package:shuxiang_reading_next/app/widgets/app_task_status.dart';

void main() {
  test('orders active tasks by priority then update time', () {
    var now = DateTime(2026, 5, 13, 9);
    final manager = AppTaskManager(now: () => now);

    manager.startTask(
      id: 'background',
      channel: AppTaskChannel.resourceScan,
      priority: AppTaskPriority.background,
      status: const AppTaskStatusData(title: '扫描资源', message: '后台扫描中'),
    );
    now = now.add(const Duration(seconds: 1));
    manager.startTask(
      id: 'reader',
      channel: AppTaskChannel.reader,
      priority: AppTaskPriority.immediate,
      status: const AppTaskStatusData(title: '打开阅读', message: '正在打开章节'),
    );

    expect(manager.tasks.first.id, 'reader');
    expect(manager.activeTask?.id, 'reader');
  });

  test('updates, cancels, and clears finished tasks', () {
    final manager = AppTaskManager(now: () => DateTime(2026, 5, 13, 9));

    manager.startTask(
      id: 'import',
      channel: AppTaskChannel.localBookImport,
      priority: AppTaskPriority.userInitiated,
      canCancel: true,
      recoveryKey: 'batch-1',
      status: const AppTaskStatusData(title: '导入图书', message: '准备导入'),
    );

    manager.updateTask(
      'import',
      const AppTaskStatusData(title: '导入图书', message: '正在导入', progress: 0.5),
    );
    expect(manager.taskById('import')?.status.progress, 0.5);

    manager.cancelTask('import');
    expect(
      manager.taskById('import')?.status.result,
      AppTaskStatusResult.cancelled,
    );

    manager.clearFinished();
    expect(manager.taskById('import'), isNull);
  });

  test('keeps failed long tasks retryable with progress context', () {
    var now = DateTime(2026, 6, 4, 10);
    final manager = AppTaskManager(now: () => now);

    final started = manager.startTask(
      id: 'local-book-index',
      channel: AppTaskChannel.localBookIndex,
      priority: AppTaskPriority.userInitiated,
      canCancel: true,
      recoveryKey: 'book-42',
      status: const AppTaskStatusData(
        title: 'Index local book',
        message: 'Scanning chapters',
        progress: 0.25,
        progressLabel: '1/4',
      ),
    );

    now = now.add(const Duration(seconds: 2));
    final failed = manager.updateTask(
      'local-book-index',
      started.status.copyWith(
        message: 'Chapter scan failed',
        detail: 'chapter-2.xhtml',
        result: AppTaskStatusResult.failure,
      ),
      canCancel: false,
      canRetry: true,
    );

    expect(failed?.status.result, AppTaskStatusResult.failure);
    expect(failed?.status.progress, 0.25);
    expect(failed?.status.progressLabel, '1/4');
    expect(failed?.status.detail, 'chapter-2.xhtml');
    expect(failed?.canCancel, isFalse);
    expect(failed?.canRetry, isTrue);
    expect(failed?.recoveryKey, 'book-42');
    expect(manager.activeTask, isNull);
  });

  test('assigns recovery policies by task channel and allows overrides', () {
    final manager = AppTaskManager(now: () => DateTime(2026, 5, 13, 9));

    manager.startTask(
      id: 'scan',
      channel: AppTaskChannel.resourceScan,
      priority: AppTaskPriority.background,
      status: const AppTaskStatusData(title: '扫描资源', message: '后台扫描中'),
    );
    expect(
      manager.taskById('scan')?.recoveryPolicy,
      AppTaskRecoveryPolicy.interruptedNotice,
    );

    manager.startTask(
      id: 'import',
      channel: AppTaskChannel.resourceImport,
      priority: AppTaskPriority.userInitiated,
      recoveryPolicy: AppTaskRecoveryPolicy.resumable,
      status: const AppTaskStatusData(title: '导入资源', message: '正在导入'),
    );
    expect(
      manager.taskById('import')?.recoveryPolicy,
      AppTaskRecoveryPolicy.resumable,
    );
  });
}

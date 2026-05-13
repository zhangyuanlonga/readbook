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
}

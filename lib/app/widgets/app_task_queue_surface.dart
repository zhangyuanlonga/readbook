import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../layout/app_adaptive.dart';
import '../layout/app_layout.dart';
import '../tasks/app_task_manager.dart';
import 'adaptive_bottom_sheet.dart';
import 'app_empty_state_card.dart';
import 'app_task_bottom_sheet.dart';
import 'app_task_status.dart';
import 'foundation/foundation.dart';

class AppTaskQueueButton extends ConsumerWidget {
  const AppTaskQueueButton({super.key, this.bottom = 24, this.right = 16});

  final double bottom;
  final double right;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskManager = ref.watch(appTaskManagerProvider);
    final tasks = taskManager.tasks;
    if (tasks.isEmpty) {
      return const SizedBox.shrink();
    }
    final activeCount = tasks.where((task) => !task.isFinished).length;
    final colorScheme = Theme.of(context).colorScheme;

    return Positioned(
      right: right,
      bottom: bottom,
      child: SafeArea(
        child: Material(
          elevation: 8,
          color: colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(999),
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => showAppTaskQueueSurface(context),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      activeCount > 0
                          ? Icons.sync_rounded
                          : Icons.task_alt_rounded,
                      color: colorScheme.onPrimaryContainer,
                    ),
                    if (activeCount > 0) ...[
                      const SizedBox(width: 8),
                      Text(
                        '$activeCount',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showAppTaskQueueSurface(BuildContext context) {
  final desktopLike =
      AppLayout.isDesktopLike(context, platform: Theme.of(context).platform) ||
      kIsWeb ||
      AppAdaptiveMetrics.of(context).isMediumUpWindow;
  return showAdaptiveRawSurface<void>(
    context: context,
    mode:
        desktopLike
            ? AdaptiveActionSurfaceMode.desktopDialog
            : AdaptiveActionSurfaceMode.mobileSheet,
    mobileBackgroundColor: Colors.transparent,
    builder: (context) => const _AppTaskQueuePanel(),
  );
}

class _AppTaskQueuePanel extends ConsumerWidget {
  const _AppTaskQueuePanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskManager = ref.watch(appTaskManagerProvider);
    final tasks = taskManager.tasks;
    final activeCount = tasks.where((task) => !task.isFinished).length;
    final finishedCount = tasks.length - activeCount;

    return AppTaskBottomSheet(
      title: '任务队列',
      maxHeightFactor: 0.82,
      trailing:
          finishedCount > 0
              ? IconButton(
                tooltip: '清除已完成',
                onPressed:
                    () => _clearFinishedTasks(context, ref, finishedCount),
                icon: const Icon(Icons.cleaning_services_outlined),
              )
              : null,
      header: _AppTaskQueueSummary(
        totalCount: tasks.length,
        activeCount: activeCount,
        finishedCount: finishedCount,
      ),
      body:
          tasks.isEmpty
              ? const AppEmptyStateCard(
                icon: Icons.task_alt_rounded,
                title: '暂无任务',
                description: '导入、扫描和清理任务会在这里集中展示。',
              )
              : ListView.separated(
                itemCount: tasks.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  return _AppTaskQueueItem(task: tasks[index]);
                },
              ),
    );
  }

  void _clearFinishedTasks(BuildContext context, WidgetRef ref, int count) {
    ref.read(appTaskManagerProvider).clearFinished();
    AppFeedback.showSnackBar(
      context,
      message: '已清除 $count 个已完成任务。',
      tone: AppFeedbackTone.success,
    );
  }
}

class _AppTaskQueueSummary extends StatelessWidget {
  const _AppTaskQueueSummary({
    required this.totalCount,
    required this.activeCount,
    required this.finishedCount,
  });

  final int totalCount;
  final int activeCount;
  final int finishedCount;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _TaskChip(label: '全部 $totalCount'),
        _TaskChip(label: '运行中 $activeCount'),
        _TaskChip(label: '已结束 $finishedCount'),
      ],
    );
  }
}

class _AppTaskQueueItem extends ConsumerWidget {
  const _AppTaskQueueItem({required this.task});

  final AppTaskSnapshot task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final status = task.status;
    final progress = status.progress?.clamp(0.0, 1.0);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TaskStatusIcon(status: status),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        status.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        status.message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                if (task.canCancel && !task.isFinished)
                  IconButton(
                    tooltip: '取消任务',
                    onPressed: () => _cancelTask(context, ref),
                    icon: const Icon(Icons.close_rounded),
                  ),
              ],
            ),
            if ((status.detail ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                status.detail!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (!status.isFinished) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 7,
                  backgroundColor: colorScheme.surfaceContainer,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _TaskChip(label: _channelLabel(task.channel)),
                _TaskChip(label: _priorityLabel(task.priority)),
                _TaskChip(label: task.recoveryPolicy.label),
                if ((status.progressLabel ?? '').trim().isNotEmpty)
                  _TaskChip(label: status.progressLabel!),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _cancelTask(BuildContext context, WidgetRef ref) {
    final cancelled = ref.read(appTaskManagerProvider).cancelTask(task.id);
    if (cancelled == null) {
      AppFeedback.showSnackBar(
        context,
        message: '任务已结束，无法取消。',
        tone: AppFeedbackTone.warning,
      );
      return;
    }
    AppFeedback.showSnackBar(
      context,
      message: '已取消「${task.status.title}」。',
      tone: AppFeedbackTone.info,
    );
  }

  String _channelLabel(AppTaskChannel channel) {
    return switch (channel) {
      AppTaskChannel.reader => '阅读',
      AppTaskChannel.localBookImport => '图书导入',
      AppTaskChannel.localBookIndex => '目录索引',
      AppTaskChannel.resourceImport => '资源导入',
      AppTaskChannel.resourceScan => '资源扫描',
      AppTaskChannel.sync => '同步',
      AppTaskChannel.maintenance => '维护',
      AppTaskChannel.other => '其他',
    };
  }

  String _priorityLabel(AppTaskPriority priority) {
    return switch (priority) {
      AppTaskPriority.immediate => '即时',
      AppTaskPriority.userInitiated => '用户触发',
      AppTaskPriority.background => '后台',
    };
  }
}

class _TaskStatusIcon extends StatelessWidget {
  const _TaskStatusIcon({required this.status});

  final AppTaskStatusData status;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final icon = switch (status.result) {
      AppTaskStatusResult.success => Icons.check_rounded,
      AppTaskStatusResult.failure => Icons.error_outline_rounded,
      AppTaskStatusResult.cancelled => Icons.block_rounded,
      AppTaskStatusResult.idle ||
      AppTaskStatusResult.running => Icons.sync_rounded,
    };
    final color = switch (status.result) {
      AppTaskStatusResult.success => colorScheme.primary,
      AppTaskStatusResult.failure => colorScheme.error,
      AppTaskStatusResult.cancelled => colorScheme.onSurfaceVariant,
      AppTaskStatusResult.idle ||
      AppTaskStatusResult.running => colorScheme.primary,
    };

    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 19),
    );
  }
}

class _TaskChip extends StatelessWidget {
  const _TaskChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

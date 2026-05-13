import 'package:flutter/material.dart';

import '../motion/app_motion.dart';
import 'import_export_task_overlay.dart';

class ImportExportProgressCard extends StatelessWidget {
  const ImportExportProgressCard({
    super.key,
    required this.status,
    this.bottomPadding = 0,
  });

  final ImportExportTaskStatus status;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final motionDuration = AppMotion.durationOf(context, AppMotion.medium);

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 8, 12, 12 + bottomPadding),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
          decoration: _taskCardDecoration(colorScheme),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: CircularProgressIndicator(strokeWidth: 2.1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedSwitcher(
                      duration: motionDuration,
                      child: Text(
                        status.message,
                        key: ValueKey<String>(status.message),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if ((status.progressLabel ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      AnimatedSwitcher(
                        duration: motionDuration,
                        child: Text(
                          status.progressLabel!,
                          key: ValueKey<String>(status.progressLabel!),
                          style: Theme.of(
                            context,
                          ).textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                    if ((status.detail ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      AnimatedSwitcher(
                        duration: motionDuration,
                        child: Text(
                          '执行阶段：${status.detail!}',
                          key: ValueKey<String>(status.detail!),
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ImportExportTaskSheet extends StatelessWidget {
  const ImportExportTaskSheet({
    super.key,
    required this.status,
    this.primaryAction,
    this.secondaryAction,
    this.bottomPadding = 0,
  });

  final ImportExportTaskStatus status;
  final Widget? primaryAction;
  final Widget? secondaryAction;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final motionDuration = AppMotion.durationOf(context, AppMotion.medium);
    final statusVisual = _taskResultVisual(status.result, colorScheme);

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 8, 12, 12 + bottomPadding),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
          decoration: _taskCardDecoration(colorScheme),
          child: Row(
            children: [
              AnimatedContainer(
                duration: motionDuration,
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: statusVisual.color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: AnimatedSwitcher(
                  duration: motionDuration,
                  child: Icon(
                    statusVisual.icon,
                    key: ValueKey<ImportExportTaskResult>(status.result),
                    color: statusVisual.color,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AnimatedSwitcher(
                  duration: motionDuration,
                  child: Text(
                    statusVisual.label,
                    key: ValueKey<ImportExportTaskResult>(status.result),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

({IconData icon, Color color, String label}) _taskResultVisual(
  ImportExportTaskResult result,
  ColorScheme colorScheme,
) {
  return switch (result) {
    ImportExportTaskResult.failure => (
      icon: Icons.close_rounded,
      color: colorScheme.error,
      label: '处理失败',
    ),
    ImportExportTaskResult.cancelled => (
      icon: Icons.block_rounded,
      color: colorScheme.onSurfaceVariant,
      label: '已取消',
    ),
    ImportExportTaskResult.running => (
      icon: Icons.sync_rounded,
      color: colorScheme.primary,
      label: '处理中',
    ),
    ImportExportTaskResult.idle => (
      icon: Icons.hourglass_empty_rounded,
      color: colorScheme.onSurfaceVariant,
      label: '等待中',
    ),
    ImportExportTaskResult.success => (
      icon: Icons.check_rounded,
      color: colorScheme.primary,
      label: '已完成',
    ),
  };
}

BoxDecoration _taskCardDecoration(ColorScheme colorScheme) {
  return BoxDecoration(
    color: colorScheme.surfaceContainerLow,
    borderRadius: BorderRadius.circular(24),
    border: Border.all(
      color: colorScheme.outlineVariant.withValues(alpha: 0.4),
    ),
  );
}

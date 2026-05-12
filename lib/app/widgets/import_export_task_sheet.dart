import 'package:flutter/material.dart';

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
                    Text(
                      status.message,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if ((status.progressLabel ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        status.progressLabel!,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    if ((status.detail ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        '执行阶段：${status.detail!}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.45,
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
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_rounded,
                  color: colorScheme.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '已完成',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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

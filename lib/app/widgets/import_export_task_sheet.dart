import 'package:flutter/material.dart';

import 'import_export_task_overlay.dart';

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
    final progress = status.progress?.clamp(0.0, 1.0);

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 8, 12, 12 + bottomPadding),
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.4),
              ),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withValues(alpha: 0.14),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        status.title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if ((status.progressLabel ?? '').trim().isNotEmpty)
                      Text(
                        status.progressLabel!,
                        style: Theme.of(
                          context,
                        ).textTheme.labelMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  status.message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
                if ((status.detail ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    status.detail!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 8,
                    value: progress,
                    backgroundColor: colorScheme.surfaceContainer,
                  ),
                ),
                if (primaryAction != null || secondaryAction != null) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      if (primaryAction != null) primaryAction!,
                      if (secondaryAction != null) secondaryAction!,
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

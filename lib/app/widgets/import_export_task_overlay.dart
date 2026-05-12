import 'package:flutter/material.dart';

import '../motion/app_motion_widgets.dart';
import 'app_task_status.dart';

enum ImportExportTaskPresentation { overlay, inlineCompact, queuePanel }

enum ImportExportTaskResult { idle, running, success, failure, cancelled }

class ImportExportTaskStatus {
  const ImportExportTaskStatus({
    required this.title,
    required this.message,
    this.progress,
    this.progressLabel,
    this.detail,
    this.presentation = ImportExportTaskPresentation.overlay,
    this.result = ImportExportTaskResult.running,
  });

  final String title;
  final String message;
  final double? progress;
  final String? progressLabel;
  final String? detail;
  final ImportExportTaskPresentation presentation;
  final ImportExportTaskResult result;

  factory ImportExportTaskStatus.fromAppTaskStatus(AppTaskStatusData status) {
    return ImportExportTaskStatus(
      title: status.title,
      message: status.message,
      progress: status.progress,
      progressLabel: status.progressLabel,
      detail: status.detail,
      presentation: _importExportPresentationFrom(status.presentation),
      result: _importExportResultFrom(status.result),
    );
  }

  bool get isFinished =>
      result == ImportExportTaskResult.success ||
      result == ImportExportTaskResult.failure ||
      result == ImportExportTaskResult.cancelled;

  ImportExportTaskStatus copyWith({
    String? title,
    String? message,
    Object? progress = _sentinel,
    Object? progressLabel = _sentinel,
    Object? detail = _sentinel,
    ImportExportTaskPresentation? presentation,
    ImportExportTaskResult? result,
  }) {
    return ImportExportTaskStatus(
      title: title ?? this.title,
      message: message ?? this.message,
      progress:
          identical(progress, _sentinel) ? this.progress : progress as double?,
      progressLabel:
          identical(progressLabel, _sentinel)
              ? this.progressLabel
              : progressLabel as String?,
      detail: identical(detail, _sentinel) ? this.detail : detail as String?,
      presentation: presentation ?? this.presentation,
      result: result ?? this.result,
    );
  }

  AppTaskStatusData toAppTaskStatusData({
    AppTaskStatusKind kind = AppTaskStatusKind.other,
  }) {
    return AppTaskStatusData(
      title: title,
      message: message,
      kind: kind,
      progress: progress,
      progressLabel: progressLabel,
      detail: detail,
      presentation: _appTaskPresentationFrom(presentation),
      result: _appTaskResultFrom(result),
    );
  }
}

const Object _sentinel = Object();

ImportExportTaskPresentation _importExportPresentationFrom(
  AppTaskStatusPresentation presentation,
) {
  return switch (presentation) {
    AppTaskStatusPresentation.overlay => ImportExportTaskPresentation.overlay,
    AppTaskStatusPresentation.inlineCompact =>
      ImportExportTaskPresentation.inlineCompact,
    AppTaskStatusPresentation.queuePanel =>
      ImportExportTaskPresentation.queuePanel,
  };
}

ImportExportTaskResult _importExportResultFrom(AppTaskStatusResult result) {
  return switch (result) {
    AppTaskStatusResult.idle => ImportExportTaskResult.idle,
    AppTaskStatusResult.running => ImportExportTaskResult.running,
    AppTaskStatusResult.success => ImportExportTaskResult.success,
    AppTaskStatusResult.failure => ImportExportTaskResult.failure,
    AppTaskStatusResult.cancelled => ImportExportTaskResult.cancelled,
  };
}

AppTaskStatusPresentation _appTaskPresentationFrom(
  ImportExportTaskPresentation presentation,
) {
  return switch (presentation) {
    ImportExportTaskPresentation.overlay => AppTaskStatusPresentation.overlay,
    ImportExportTaskPresentation.inlineCompact =>
      AppTaskStatusPresentation.inlineCompact,
    ImportExportTaskPresentation.queuePanel =>
      AppTaskStatusPresentation.queuePanel,
  };
}

AppTaskStatusResult _appTaskResultFrom(ImportExportTaskResult result) {
  return switch (result) {
    ImportExportTaskResult.idle => AppTaskStatusResult.idle,
    ImportExportTaskResult.running => AppTaskStatusResult.running,
    ImportExportTaskResult.success => AppTaskStatusResult.success,
    ImportExportTaskResult.failure => AppTaskStatusResult.failure,
    ImportExportTaskResult.cancelled => AppTaskStatusResult.cancelled,
  };
}

class ImportExportTaskOverlay extends StatelessWidget {
  const ImportExportTaskOverlay({super.key, required this.child, this.status});

  final Widget child;
  final ImportExportTaskStatus? status;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            ignoring: status == null,
            child: AppAnimatedSwitcher(
              child:
                  status == null
                      ? const SizedBox.shrink(key: ValueKey<bool>(false))
                      : _ImportExportTaskPane(
                        key: const ValueKey<bool>(true),
                        status: status!,
                      ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ImportExportTaskPane extends StatelessWidget {
  const _ImportExportTaskPane({super.key, required this.status});

  final ImportExportTaskStatus status;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final progress = status.progress?.clamp(0.0, 1.0);

    return ColoredBox(
      color: colorScheme.scrim.withValues(alpha: 0.12),
      child: Center(
        child: SafeArea(
          minimum: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                decoration: BoxDecoration(
                  color: colorScheme.surface.withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.shadow.withValues(alpha: 0.16),
                      blurRadius: 28,
                      offset: const Offset(0, 10),
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
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            child: Text(
                              status.title,
                              key: ValueKey<String>(status.title),
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                        if ((status.progressLabel ?? '').trim().isNotEmpty)
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            child: Text(
                              status.progressLabel!,
                              key: ValueKey<String>(status.progressLabel!),
                              style: Theme.of(
                                context,
                              ).textTheme.labelMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: Column(
                        key: ValueKey<String>(
                          '${status.message}::${status.detail ?? ''}',
                        ),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            status.message,
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              height: 1.5,
                            ),
                          ),
                          if ((status.detail ?? '').trim().isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              status.detail!,
                              style: Theme.of(
                                context,
                              ).textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child:
                          progress == null
                              ? LinearProgressIndicator(
                                minHeight: 8,
                                backgroundColor: colorScheme.surfaceContainer,
                              )
                              : TweenAnimationBuilder<double>(
                                tween: Tween<double>(begin: 0, end: progress),
                                duration: const Duration(milliseconds: 220),
                                curve: Curves.easeOutCubic,
                                builder: (context, value, _) {
                                  return LinearProgressIndicator(
                                    value: value,
                                    minHeight: 8,
                                    backgroundColor:
                                        colorScheme.surfaceContainer,
                                  );
                                },
                              ),
                    ),
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

class ImportExportInlineStatus extends StatelessWidget {
  const ImportExportInlineStatus({
    super.key,
    required this.status,
    this.padding = const EdgeInsets.fromLTRB(12, 10, 12, 10),
  });

  final ImportExportTaskStatus status;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final progress = status.progress?.clamp(0.0, 1.0);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: padding,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  value:
                      status.isFinished && progress != null ? progress : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  status.title,
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if ((status.progressLabel ?? '').trim().isNotEmpty)
                Text(
                  status.progressLabel!,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            status.message,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          if ((status.detail ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              status.detail!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
          if (progress != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 6,
                value: progress,
                backgroundColor: colorScheme.surface,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

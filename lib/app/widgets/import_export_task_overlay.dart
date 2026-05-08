import 'package:flutter/material.dart';

class ImportExportTaskStatus {
  const ImportExportTaskStatus({
    required this.title,
    required this.message,
    this.progress,
    this.progressLabel,
  });

  final String title;
  final String message;
  final double? progress;
  final String? progressLabel;
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
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              reverseDuration: const Duration(milliseconds: 180),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                final fade = CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                );
                final slide = Tween<Offset>(
                  begin: const Offset(0, 0.02),
                  end: Offset.zero,
                ).animate(fade);
                return FadeTransition(
                  opacity: fade,
                  child: SlideTransition(position: slide, child: child),
                );
              },
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
                      child: Text(
                        status.message,
                        key: ValueKey<String>(status.message),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.5,
                        ),
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

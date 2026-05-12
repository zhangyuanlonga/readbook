import 'package:flutter/material.dart';

enum RuntimeFeedbackTone { loading, info, warning, error }

class RuntimeFeedbackCard extends StatelessWidget {
  const RuntimeFeedbackCard({
    super.key,
    required this.title,
    required this.message,
    this.icon,
    this.tone = RuntimeFeedbackTone.info,
    this.actions = const <Widget>[],
    this.compact = false,
  });

  final String title;
  final String message;
  final IconData? icon;
  final RuntimeFeedbackTone tone;
  final List<Widget> actions;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final resolvedIcon = icon ?? _defaultIconForTone(tone);
    final (background, foreground, border) = switch (tone) {
      RuntimeFeedbackTone.loading => (
        colorScheme.surfaceContainerLow,
        colorScheme.onSurface,
        colorScheme.outlineVariant.withValues(alpha: 0.5),
      ),
      RuntimeFeedbackTone.info => (
        colorScheme.surfaceContainerLow,
        colorScheme.onSurface,
        colorScheme.outlineVariant.withValues(alpha: 0.5),
      ),
      RuntimeFeedbackTone.warning => (
        colorScheme.tertiaryContainer,
        colorScheme.onTertiaryContainer,
        colorScheme.tertiary.withValues(alpha: 0.35),
      ),
      RuntimeFeedbackTone.error => (
        colorScheme.errorContainer,
        colorScheme.onErrorContainer,
        colorScheme.error.withValues(alpha: 0.35),
      ),
    };

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          color: background,
          border: Border.all(color: border),
        ),
        child: Padding(
          padding: EdgeInsets.all(compact ? 14 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (tone == RuntimeFeedbackTone.loading)
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: foreground,
                      ),
                    )
                  else
                    Icon(resolvedIcon, color: foreground, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(
                            context,
                          ).textTheme.titleSmall?.copyWith(
                            color: foreground,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          message,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(color: foreground),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: actions),
              ],
            ],
          ),
        ),
      ),
    );
  }

  IconData _defaultIconForTone(RuntimeFeedbackTone tone) {
    return switch (tone) {
      RuntimeFeedbackTone.loading => Icons.hourglass_top_rounded,
      RuntimeFeedbackTone.info => Icons.info_outline_rounded,
      RuntimeFeedbackTone.warning => Icons.warning_amber_rounded,
      RuntimeFeedbackTone.error => Icons.error_outline_rounded,
    };
  }
}

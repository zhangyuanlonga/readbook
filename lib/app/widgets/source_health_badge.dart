import 'package:flutter/material.dart';

import '../../domain/entities/source_health.dart';

class SourceHealthBadge extends StatelessWidget {
  const SourceHealthBadge({
    super.key,
    required this.level,
    this.compact = false,
  });

  final SourceHealthLevel level;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (label, background, foreground) = switch (level) {
      SourceHealthLevel.healthy => (
        '正常',
        colorScheme.primaryContainer,
        colorScheme.onPrimaryContainer,
      ),
      SourceHealthLevel.warning => (
        '注意',
        colorScheme.tertiaryContainer,
        colorScheme.onTertiaryContainer,
      ),
      SourceHealthLevel.risky => (
        '高风险',
        colorScheme.errorContainer,
        colorScheme.onErrorContainer,
      ),
      SourceHealthLevel.unavailable => (
        '不可用',
        colorScheme.error,
        colorScheme.onError,
      ),
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 8,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

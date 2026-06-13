import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/app_component_theme_tokens.dart';
import 'app_haptics.dart';

enum AppFeedbackTone { success, info, warning, error, loading }

class AppFeedback {
  const AppFeedback._();

  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showSnackBar(
    BuildContext context, {
    required String message,
    AppFeedbackTone tone = AppFeedbackTone.info,
    SnackBarAction? action,
    Duration? duration,
    bool clearPrevious = true,
    bool useHaptics = true,
  }) {
    if (useHaptics) {
      unawaited(_triggerHapticForTone(tone));
    }

    final messenger = ScaffoldMessenger.of(context);
    if (clearPrevious) {
      messenger.hideCurrentSnackBar();
    }
    final palette = _AppFeedbackPalette.resolve(context, tone);
    return messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: duration ?? _durationForTone(tone),
        backgroundColor: palette.background,
        content: Row(
          children: [
            Icon(palette.icon, color: palette.foreground, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: palette.foreground),
              ),
            ),
          ],
        ),
        action: action,
      ),
    );
  }

  static Duration _durationForTone(AppFeedbackTone tone) {
    return switch (tone) {
      AppFeedbackTone.loading => const Duration(seconds: 10),
      AppFeedbackTone.error => const Duration(seconds: 5),
      AppFeedbackTone.success ||
      AppFeedbackTone.info ||
      AppFeedbackTone.warning => const Duration(seconds: 4),
    };
  }

  static Future<void> _triggerHapticForTone(AppFeedbackTone tone) {
    return switch (tone) {
      AppFeedbackTone.success => AppHaptics.success(),
      AppFeedbackTone.warning => AppHaptics.warning(),
      AppFeedbackTone.error => AppHaptics.danger(),
      AppFeedbackTone.info || AppFeedbackTone.loading => AppHaptics.selection(),
    };
  }
}

class AppInlineFeedback extends StatelessWidget {
  const AppInlineFeedback({
    super.key,
    required this.message,
    this.title,
    this.tone = AppFeedbackTone.info,
    this.action,
    this.compact = false,
  });

  final String? title;
  final String message;
  final AppFeedbackTone tone;
  final Widget? action;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tokens = appComponentThemeTokensOf(context);
    final theme = Theme.of(context);
    final palette = _AppFeedbackPalette.resolve(context, tone);
    final padding = compact ? 12.0 : 14.0;

    return Semantics(
      liveRegion:
          tone == AppFeedbackTone.error || tone == AppFeedbackTone.warning,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: palette.container,
          borderRadius: BorderRadius.circular(tokens.card.radius * 0.72),
          border: Border.all(color: palette.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(palette.icon, color: palette.accent, size: compact ? 18 : 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null) ...[
                    Text(
                      title!,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: palette.foreground,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    message,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: palette.foreground,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            if (action != null) ...[const SizedBox(width: 10), action!],
          ],
        ),
      ),
    );
  }
}

class _AppFeedbackPalette {
  const _AppFeedbackPalette({
    required this.icon,
    required this.background,
    required this.container,
    required this.foreground,
    required this.accent,
    required this.border,
  });

  final IconData icon;
  final Color background;
  final Color container;
  final Color foreground;
  final Color accent;
  final Color border;

  static _AppFeedbackPalette resolve(
    BuildContext context,
    AppFeedbackTone tone,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return switch (tone) {
      AppFeedbackTone.success => _AppFeedbackPalette(
        icon: Icons.check_circle_outline_rounded,
        background: colorScheme.primaryContainer,
        container: colorScheme.primaryContainer.withValues(alpha: 0.58),
        foreground: colorScheme.onPrimaryContainer,
        accent: colorScheme.primary,
        border: colorScheme.primary.withValues(alpha: 0.26),
      ),
      AppFeedbackTone.info => _AppFeedbackPalette(
        icon: Icons.info_outline_rounded,
        background: colorScheme.inverseSurface,
        container: colorScheme.surfaceContainerLow,
        foreground: colorScheme.onSurfaceVariant,
        accent: colorScheme.primary,
        border: colorScheme.outlineVariant.withValues(alpha: 0.52),
      ),
      AppFeedbackTone.warning => _AppFeedbackPalette(
        icon: Icons.warning_amber_rounded,
        background: colorScheme.tertiaryContainer,
        container: colorScheme.tertiaryContainer.withValues(alpha: 0.72),
        foreground: colorScheme.onTertiaryContainer,
        accent: colorScheme.tertiary,
        border: colorScheme.tertiary.withValues(alpha: 0.28),
      ),
      AppFeedbackTone.error => _AppFeedbackPalette(
        icon: Icons.error_outline_rounded,
        background: colorScheme.errorContainer,
        container: colorScheme.errorContainer.withValues(alpha: 0.64),
        foreground: colorScheme.onErrorContainer,
        accent: colorScheme.error,
        border: colorScheme.error.withValues(alpha: 0.3),
      ),
      AppFeedbackTone.loading => _AppFeedbackPalette(
        icon: Icons.hourglass_top_rounded,
        background: colorScheme.surfaceContainerHighest,
        container: colorScheme.surfaceContainerLow,
        foreground: colorScheme.onSurfaceVariant,
        accent: colorScheme.primary,
        border: colorScheme.outlineVariant.withValues(alpha: 0.52),
      ),
    };
  }
}

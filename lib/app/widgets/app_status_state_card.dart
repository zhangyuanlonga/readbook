import 'package:flutter/material.dart';

import 'foundation/app_button.dart';
import 'foundation/app_surface.dart';

enum AppStatusStateTone { neutral, error, warning }

const double _kStatusStatePadding = 18;
const double _kStatusStateCompactPadding = 14;
const double _kStatusStateIconSize = 20;
const double _kStatusStateCompactIconSize = 18;
const double _kStatusStateSectionGap = 12;
const double _kStatusStateDescriptionGap = 6;

class AppStatusStateCard extends StatelessWidget {
  const AppStatusStateCard({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.tone = AppStatusStateTone.neutral,
    this.actionLabel,
    this.onAction,
    this.compact = false,
    this.footer,
  });

  final IconData icon;
  final String title;
  final String message;
  final AppStatusStateTone tone;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final palette = _resolvePalette(colorScheme);

    return SizedBox(
      width: double.infinity,
      child: AppSurface(
        tone: AppSurfaceTone.muted,
        padding: EdgeInsets.fromLTRB(
          compact ? _kStatusStateCompactPadding : _kStatusStatePadding,
          compact ? _kStatusStateCompactPadding : _kStatusStatePadding,
          compact ? _kStatusStateCompactPadding : _kStatusStatePadding,
          compact ? _kStatusStateCompactPadding : _kStatusStatePadding,
        ),
        backgroundColor: palette.background,
        borderColor: palette.border,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  icon,
                  size:
                      compact
                          ? _kStatusStateCompactIconSize
                          : _kStatusStateIconSize,
                  color: palette.accent,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: palette.foreground,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: _kStatusStateDescriptionGap),
                      Text(
                        message,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: palette.foreground,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: _kStatusStateSectionGap),
              Align(
                alignment: Alignment.centerLeft,
                child: AppButton(
                  variant: AppButtonVariant.tonal,
                  size: AppButtonSize.compact,
                  onPressed: onAction,
                  style: const ButtonStyle(
                    visualDensity: VisualDensity(horizontal: -1, vertical: -1),
                  ),
                  label: actionLabel!,
                ),
              ),
            ],
            if (footer != null) ...[
              const SizedBox(height: _kStatusStateSectionGap),
              footer!,
            ],
          ],
        ),
      ),
    );
  }

  _AppStatusPalette _resolvePalette(ColorScheme colorScheme) {
    return switch (tone) {
      AppStatusStateTone.neutral => _AppStatusPalette(
        background: colorScheme.surfaceContainerLow,
        border: colorScheme.outlineVariant.withValues(alpha: 0.35),
        accent: colorScheme.primary,
        foreground: colorScheme.onSurfaceVariant,
      ),
      AppStatusStateTone.error => _AppStatusPalette(
        background: colorScheme.errorContainer.withValues(alpha: 0.52),
        border: colorScheme.error.withValues(alpha: 0.28),
        accent: colorScheme.error,
        foreground: colorScheme.onErrorContainer,
      ),
      AppStatusStateTone.warning => _AppStatusPalette(
        background: colorScheme.tertiaryContainer.withValues(alpha: 0.72),
        border: colorScheme.tertiary.withValues(alpha: 0.24),
        accent: colorScheme.tertiary,
        foreground: colorScheme.onTertiaryContainer,
      ),
    };
  }
}

class _AppStatusPalette {
  const _AppStatusPalette({
    required this.background,
    required this.border,
    required this.accent,
    required this.foreground,
  });

  final Color background;
  final Color border;
  final Color accent;
  final Color foreground;
}

import 'package:flutter/material.dart';

class AdvancedThemeWallpaperResourceCard extends StatelessWidget {
  const AdvancedThemeWallpaperResourceCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.preview,
    required this.onTap,
    this.badges = const <String>[],
  });

  final String title;
  final String subtitle;
  final Widget preview;
  final VoidCallback onTap;
  final List<String> badges;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          decoration: BoxDecoration(
            color: colorScheme.surface.withValues(alpha: 0.84),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.34),
            ),
          ),
          child: Column(
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (badges.isNotEmpty) ...[
                const SizedBox(height: 5),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 5,
                  runSpacing: 5,
                  children: [
                    for (final badge in badges)
                      _AdvancedThemeResourceBadge(label: badge),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Center(child: preview),
              const SizedBox(height: 8),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdvancedThemeResourceBadge extends StatelessWidget {
  const _AdvancedThemeResourceBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.56),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

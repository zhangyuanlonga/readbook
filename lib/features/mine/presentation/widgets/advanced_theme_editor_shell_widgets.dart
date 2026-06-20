import 'package:flutter/material.dart';

class AdvancedThemeSectionLabel extends StatelessWidget {
  const AdvancedThemeSectionLabel({
    super.key,
    required this.title,
    this.tooltipMessage,
  });

  final String title;
  final String? tooltipMessage;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: _AdvancedThemeSectionHeading(
        title: title,
        description: tooltipMessage,
      ),
    );
  }
}

class AdvancedThemeExpandableSectionHeader extends StatelessWidget {
  const AdvancedThemeExpandableSectionHeader({
    super.key,
    required this.title,
    required this.expanded,
    required this.onToggle,
    this.tooltipMessage,
  });

  final String title;
  final String? tooltipMessage;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(2, 6, 2, 6),
        child: Row(
          children: [
            Expanded(
              child: _AdvancedThemeSectionHeading(
                title: title,
                description: tooltipMessage,
              ),
            ),
            Icon(
              expanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class AdvancedThemePanel extends StatelessWidget {
  const AdvancedThemePanel({
    super.key,
    required this.child,
    this.backgroundColor,
    this.padding = const EdgeInsets.fromLTRB(10, 8, 10, 8),
  });

  final Widget child;
  final Color? backgroundColor;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: child,
    );
  }
}

class AdvancedThemeListSectionBody extends StatelessWidget {
  const AdvancedThemeListSectionBody({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.28),
        ),
      ),
      child: child,
    );
  }
}

class _AdvancedThemeSectionHeading extends StatelessWidget {
  const _AdvancedThemeSectionHeading({
    required this.title,
    required this.description,
  });

  final String title;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final normalizedDescription = description?.trim();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AdvancedThemeSectionTitle(title: title),
        if (normalizedDescription != null &&
            normalizedDescription.isNotEmpty) ...[
          const SizedBox(height: 2),
          _AdvancedThemeSectionDescription(description: normalizedDescription),
        ],
      ],
    );
  }
}

class _AdvancedThemeSectionTitle extends StatelessWidget {
  const _AdvancedThemeSectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _AdvancedThemeSectionDescription extends StatelessWidget {
  const _AdvancedThemeSectionDescription({required this.description});

  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      description,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

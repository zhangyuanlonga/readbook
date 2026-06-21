import 'package:flutter/material.dart';

import '../../../../app/theme/app_component_theme_tokens.dart';

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
    final normalizedDescription = tooltipMessage?.trim();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Semantics(
        hint:
            normalizedDescription == null || normalizedDescription.isEmpty
                ? null
                : normalizedDescription,
        child: _AdvancedThemeSectionHeading(title: title),
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
    final componentTokens = appComponentThemeTokensOf(context);
    final normalizedDescription = tooltipMessage?.trim();
    return Semantics(
      button: true,
      hint:
          normalizedDescription == null || normalizedDescription.isEmpty
              ? null
              : normalizedDescription,
      child: InkWell(
        borderRadius: BorderRadius.all(
          Radius.circular(componentTokens.card.radius),
        ),
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(2, 6, 2, 6),
          child: Row(
            children: [
              Expanded(child: _AdvancedThemeSectionHeading(title: title)),
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
    final componentTokens = appComponentThemeTokensOf(context);
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.all(
          Radius.circular(componentTokens.card.radius),
        ),
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
    final componentTokens = appComponentThemeTokensOf(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.52),
        borderRadius: BorderRadius.all(
          Radius.circular(componentTokens.card.radius),
        ),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.28),
        ),
      ),
      child: child,
    );
  }
}

class _AdvancedThemeSectionHeading extends StatelessWidget {
  const _AdvancedThemeSectionHeading({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return _AdvancedThemeSectionTitle(title: title);
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

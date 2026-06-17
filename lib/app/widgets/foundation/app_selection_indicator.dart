import 'package:flutter/material.dart';

class AppSelectionIndicator extends StatelessWidget {
  const AppSelectionIndicator({
    super.key,
    required this.selected,
    this.enabled = true,
    this.size = 24,
    this.semanticLabel,
  });

  final bool selected;
  final bool enabled;
  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final iconColor =
        enabled
            ? selected
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant
            : colorScheme.onSurface.withValues(alpha: 0.32);

    final indicator = AnimatedSwitcher(
      duration: const Duration(milliseconds: 150),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: Icon(
        selected
            ? Icons.radio_button_checked_rounded
            : Icons.radio_button_unchecked_rounded,
        key: ValueKey<bool>(selected),
        size: size,
        color: iconColor,
      ),
    );

    if (semanticLabel == null) {
      return indicator;
    }
    return Semantics(
      label: semanticLabel,
      checked: selected,
      enabled: enabled,
      child: indicator,
    );
  }
}

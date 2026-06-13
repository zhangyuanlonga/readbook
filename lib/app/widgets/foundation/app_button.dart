import 'package:flutter/material.dart';

import '../../theme/app_component_theme_tokens.dart';

enum AppButtonVariant { primary, secondary, tonal, danger, ghost, text }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.expanded = false,
    this.tooltip,
    this.style,
    this.autofocus = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final Widget? icon;
  final bool isLoading;
  final bool expanded;
  final String? tooltip;
  final ButtonStyle? style;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed = isLoading ? null : onPressed;
    final child = _AppButtonChild(
      label: label,
      icon: icon,
      isLoading: isLoading,
      variant: variant,
    );
    final button = switch (variant) {
      AppButtonVariant.primary => FilledButton(
        onPressed: effectiveOnPressed,
        style: style,
        autofocus: autofocus,
        child: child,
      ),
      AppButtonVariant.secondary => OutlinedButton(
        onPressed: effectiveOnPressed,
        style: style,
        autofocus: autofocus,
        child: child,
      ),
      AppButtonVariant.tonal => FilledButton.tonal(
        onPressed: effectiveOnPressed,
        style: style,
        autofocus: autofocus,
        child: child,
      ),
      AppButtonVariant.danger => FilledButton(
        onPressed: effectiveOnPressed,
        style: _dangerStyle(context).merge(style),
        autofocus: autofocus,
        child: child,
      ),
      AppButtonVariant.ghost => TextButton(
        onPressed: effectiveOnPressed,
        style: style,
        autofocus: autofocus,
        child: child,
      ),
      AppButtonVariant.text => TextButton(
        onPressed: effectiveOnPressed,
        style: style,
        autofocus: autofocus,
        child: child,
      ),
    };
    final content =
        expanded ? SizedBox(width: double.infinity, child: button) : button;
    if (tooltip == null) {
      return content;
    }
    return Tooltip(message: tooltip!, child: content);
  }

  ButtonStyle _dangerStyle(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return FilledButton.styleFrom(
      backgroundColor: colorScheme.error,
      foregroundColor: colorScheme.onError,
    );
  }
}

class _AppButtonChild extends StatelessWidget {
  const _AppButtonChild({
    required this.label,
    required this.icon,
    required this.isLoading,
    required this.variant,
  });

  final String label;
  final Widget? icon;
  final bool isLoading;
  final AppButtonVariant variant;

  @override
  Widget build(BuildContext context) {
    final componentTokens = appComponentThemeTokensOf(context);
    final colorScheme = Theme.of(context).colorScheme;
    final effectiveIcon =
        isLoading
            ? SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: _progressColor(colorScheme),
              ),
            )
            : icon;
    if (effectiveIcon == null) {
      return Text(label);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconTheme.merge(
          data: const IconThemeData(size: 18),
          child: effectiveIcon,
        ),
        SizedBox(width: componentTokens.button.horizontalPadding * 0.45),
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
      ],
    );
  }

  Color _progressColor(ColorScheme colorScheme) {
    return switch (variant) {
      AppButtonVariant.primary => colorScheme.onPrimary,
      AppButtonVariant.danger => colorScheme.onError,
      AppButtonVariant.tonal => colorScheme.onSecondaryContainer,
      AppButtonVariant.secondary ||
      AppButtonVariant.ghost ||
      AppButtonVariant.text => colorScheme.primary,
    };
  }
}

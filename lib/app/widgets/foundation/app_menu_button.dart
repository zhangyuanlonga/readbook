import 'package:flutter/material.dart';

import '../../theme/app_component_theme_tokens.dart';

class AppMenuAction<T> {
  const AppMenuAction({
    required this.value,
    required this.label,
    this.icon,
    this.trailingIcon,
    this.child,
    this.dividerBefore = false,
    this.enabled = true,
    this.destructive = false,
  });

  final T value;
  final String label;
  final IconData? icon;
  final Widget? trailingIcon;
  final Widget? child;
  final bool dividerBefore;
  final bool enabled;
  final bool destructive;
}

class AppMenuButton<T> extends StatelessWidget {
  const AppMenuButton({
    super.key,
    required this.actions,
    required this.onSelected,
    this.tooltip,
    this.icon = Icons.more_vert_rounded,
    this.iconSize,
    this.iconColor,
    this.padding,
    this.child,
    this.enabled = true,
    this.menuStyle,
  });

  final List<AppMenuAction<T>> actions;
  final ValueChanged<T> onSelected;
  final String? tooltip;
  final IconData icon;
  final double? iconSize;
  final Color? iconColor;
  final EdgeInsetsGeometry? padding;
  final Widget? child;
  final bool enabled;
  final MenuStyle? menuStyle;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) {
      return child ?? const SizedBox.shrink();
    }
    final tokens = appComponentThemeTokensOf(context);
    final effectiveEnabled = enabled && actions.any((action) => action.enabled);
    final defaultMenuStyle = MenuStyle(
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.overlay.radius),
        ),
      ),
    );

    return MenuAnchor(
      consumeOutsideTap: true,
      style: menuStyle ?? defaultMenuStyle,
      menuChildren: [
        for (final action in actions) ...[
          if (action.dividerBefore) const Divider(height: 1),
          _AppMenuItem<T>(
            action: action,
            enabled: effectiveEnabled,
            onSelected: onSelected,
          ),
        ],
      ],
      builder: (context, controller, menuChild) {
        void toggleMenu() {
          if (controller.isOpen) {
            controller.close();
            return;
          }
          controller.open();
        }

        if (menuChild != null) {
          final trigger = Semantics(
            button: true,
            enabled: effectiveEnabled,
            child: InkWell(
              borderRadius: BorderRadius.circular(tokens.input.radius),
              onTap: effectiveEnabled ? toggleMenu : null,
              child: menuChild,
            ),
          );
          if (tooltip == null) {
            return trigger;
          }
          return Tooltip(message: tooltip!, child: trigger);
        }

        return IconButton(
          tooltip: tooltip,
          padding: padding,
          onPressed: effectiveEnabled ? toggleMenu : null,
          icon: Icon(icon, size: iconSize, color: iconColor),
        );
      },
      child: child,
    );
  }
}

class _AppMenuItem<T> extends StatelessWidget {
  const _AppMenuItem({
    required this.action,
    required this.enabled,
    required this.onSelected,
  });

  final AppMenuAction<T> action;
  final bool enabled;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final enabledForeground =
        action.destructive ? colorScheme.error : colorScheme.onSurface;
    final disabledForeground = colorScheme.onSurface.withValues(alpha: 0.38);
    final itemEnabled = enabled && action.enabled;
    final foreground = itemEnabled ? enabledForeground : disabledForeground;

    return MenuItemButton(
      onPressed: itemEnabled ? () => onSelected(action.value) : null,
      leadingIcon:
          action.icon == null ? null : Icon(action.icon, color: foreground),
      trailingIcon: action.trailingIcon,
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return disabledForeground;
          }
          return enabledForeground;
        }),
      ),
      child: action.child ?? Text(action.label),
    );
  }
}

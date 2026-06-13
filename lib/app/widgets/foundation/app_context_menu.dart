import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../theme/app_component_theme_tokens.dart';

class AppContextMenuAction {
  const AppContextMenuAction({
    required this.label,
    required this.onPressed,
    this.icon,
    this.destructive = false,
    this.enabled = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool destructive;
  final bool enabled;
}

class AppContextMenu extends StatelessWidget {
  const AppContextMenu({
    super.key,
    required this.child,
    required this.actions,
    this.enabled = true,
  });

  final Widget child;
  final List<AppContextMenuAction> actions;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) {
      return child;
    }
    final tokens = appComponentThemeTokensOf(context);
    return MenuAnchor(
      consumeOutsideTap: true,
      style: MenuStyle(
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.overlay.radius),
          ),
        ),
      ),
      menuChildren:
          actions.map((action) {
            final colorScheme = Theme.of(context).colorScheme;
            final foreground =
                action.destructive ? colorScheme.error : colorScheme.onSurface;
            return MenuItemButton(
              onPressed:
                  enabled && action.enabled && action.onPressed != null
                      ? action.onPressed
                      : null,
              leadingIcon:
                  action.icon == null
                      ? null
                      : Icon(action.icon, color: foreground),
              style: ButtonStyle(
                foregroundColor: WidgetStatePropertyAll(foreground),
              ),
              child: Text(action.label),
            );
          }).toList(),
      builder: (context, controller, menuChild) {
        return Listener(
          onPointerDown: (event) {
            if (!enabled || event.buttons != kSecondaryMouseButton) {
              return;
            }
            controller.open(position: event.localPosition);
          },
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onLongPress: enabled ? () => controller.open() : null,
            child: menuChild,
          ),
        );
      },
      child: child,
    );
  }
}

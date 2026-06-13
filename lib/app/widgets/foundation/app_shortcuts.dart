import 'package:flutter/material.dart';

class AppShortcutAction {
  const AppShortcutAction({
    required this.activator,
    required this.onInvoke,
    this.enabled = true,
  });

  final ShortcutActivator activator;
  final VoidCallback onInvoke;
  final bool enabled;
}

class AppShortcuts extends StatelessWidget {
  const AppShortcuts({
    super.key,
    required this.actions,
    required this.child,
    this.autofocus = true,
    this.focusNode,
  });

  final List<AppShortcutAction> actions;
  final Widget child;
  final bool autofocus;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) {
      return child;
    }

    final shortcuts = <ShortcutActivator, Intent>{};
    for (var index = 0; index < actions.length; index += 1) {
      shortcuts[actions[index].activator] = _AppShortcutIntent(index);
    }

    return Shortcuts(
      shortcuts: shortcuts,
      child: Actions(
        actions: <Type, Action<Intent>>{
          _AppShortcutIntent: CallbackAction<_AppShortcutIntent>(
            onInvoke: (intent) {
              final action = actions[intent.index];
              if (action.enabled) {
                action.onInvoke();
              }
              return null;
            },
          ),
        },
        child: Focus(autofocus: autofocus, focusNode: focusNode, child: child),
      ),
    );
  }
}

class _AppShortcutIntent extends Intent {
  const _AppShortcutIntent(this.index);

  final int index;
}

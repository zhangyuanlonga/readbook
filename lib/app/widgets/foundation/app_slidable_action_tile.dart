import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../theme/app_component_theme_tokens.dart';

enum AppSlidableActionTone { neutral, destructive }

class AppSlidableAction {
  const AppSlidableAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.tone = AppSlidableActionTone.neutral,
    this.enabled = true,
    this.autoClose = true,
    this.flex = 1,
  }) : assert(flex > 0);

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final AppSlidableActionTone tone;
  final bool enabled;
  final bool autoClose;
  final int flex;
}

class AppSlidableActionGroup extends StatelessWidget {
  const AppSlidableActionGroup({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SlidableAutoCloseBehavior(child: child);
  }
}

class AppSlidableActionTile extends StatelessWidget {
  const AppSlidableActionTile({
    super.key,
    required this.child,
    this.actions = const <AppSlidableAction>[],
    this.leadingActions = const <AppSlidableAction>[],
    this.enabled = true,
    this.groupTag,
    this.closeOnScroll = true,
    this.extentRatio,
    this.leadingExtentRatio,
  });

  final Widget child;
  final List<AppSlidableAction> actions;
  final List<AppSlidableAction> leadingActions;
  final bool enabled;
  final Object? groupTag;
  final bool closeOnScroll;
  final double? extentRatio;
  final double? leadingExtentRatio;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty && leadingActions.isEmpty) {
      return child;
    }

    return Slidable(
      groupTag: groupTag,
      enabled: enabled,
      closeOnScroll: closeOnScroll,
      startActionPane: _buildActionPane(
        context,
        leadingActions,
        leadingExtentRatio,
      ),
      endActionPane: _buildActionPane(context, actions, extentRatio),
      child: child,
    );
  }

  ActionPane? _buildActionPane(
    BuildContext context,
    List<AppSlidableAction> actionItems,
    double? ratio,
  ) {
    if (actionItems.isEmpty) {
      return null;
    }

    return ActionPane(
      motion: const ScrollMotion(),
      extentRatio: _resolveExtentRatio(actionItems, ratio),
      children:
          actionItems.map((action) {
            final colors = _AppSlidableActionColors.resolve(context, action);
            final tokens = appComponentThemeTokensOf(context);
            return SlidableAction(
              flex: action.flex,
              onPressed:
                  enabled && action.enabled && action.onPressed != null
                      ? (_) => action.onPressed!()
                      : null,
              icon: action.icon,
              label: action.label,
              autoClose: action.autoClose,
              backgroundColor: colors.background,
              foregroundColor: colors.foreground,
              borderRadius: BorderRadius.circular(tokens.card.radius),
            );
          }).toList(),
    );
  }

  double _resolveExtentRatio(
    List<AppSlidableAction> actionItems,
    double? ratio,
  ) {
    if (ratio != null) {
      return ratio;
    }
    return (actionItems.length * 0.22).clamp(0.24, 0.56).toDouble();
  }
}

class _AppSlidableActionColors {
  const _AppSlidableActionColors({
    required this.background,
    required this.foreground,
  });

  final Color background;
  final Color foreground;

  static _AppSlidableActionColors resolve(
    BuildContext context,
    AppSlidableAction action,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return switch (action.tone) {
      AppSlidableActionTone.neutral => _AppSlidableActionColors(
        background: colorScheme.secondaryContainer,
        foreground: colorScheme.onSecondaryContainer,
      ),
      AppSlidableActionTone.destructive => _AppSlidableActionColors(
        background: colorScheme.error,
        foreground: colorScheme.onError,
      ),
    };
  }
}

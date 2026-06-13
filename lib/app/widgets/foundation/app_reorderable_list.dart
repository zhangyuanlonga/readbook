import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../../theme/app_component_theme_tokens.dart';

class AppReorderableList extends StatelessWidget {
  const AppReorderableList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    required this.onReorder,
    this.padding,
    this.scrollController,
    this.physics,
    this.shrinkWrap = false,
    this.buildDefaultDragHandles = true,
    this.proxyDecorator,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final ReorderCallback onReorder;
  final EdgeInsets? padding;
  final ScrollController? scrollController;
  final ScrollPhysics? physics;
  final bool shrinkWrap;
  final bool buildDefaultDragHandles;
  final ReorderItemProxyDecorator? proxyDecorator;

  @override
  Widget build(BuildContext context) {
    return ReorderableListView.builder(
      itemCount: itemCount,
      itemBuilder: itemBuilder,
      onReorderItem: onReorder,
      padding: padding,
      scrollController: scrollController,
      physics: physics,
      shrinkWrap: shrinkWrap,
      buildDefaultDragHandles: buildDefaultDragHandles,
      proxyDecorator: proxyDecorator ?? _defaultProxyDecorator,
    );
  }

  Widget _defaultProxyDecorator(
    Widget child,
    int index,
    Animation<double> animation,
  ) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final tokens = appComponentThemeTokensOf(context);
        final elevation = lerpDouble(0, 8, animation.value) ?? 0;
        return Material(
          elevation: elevation,
          color: Colors.transparent,
          shadowColor: Theme.of(context).colorScheme.shadow,
          borderRadius: BorderRadius.circular(tokens.card.radius),
          child: child,
        );
      },
    );
  }
}

class AppReorderableDragHandle extends StatelessWidget {
  const AppReorderableDragHandle({
    super.key,
    required this.index,
    this.enabled = true,
    this.tooltip = '拖拽排序',
  });

  final int index;
  final bool enabled;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final icon = Tooltip(
      message: tooltip,
      child: Icon(
        Icons.drag_indicator_rounded,
        color:
            enabled
                ? colorScheme.onSurfaceVariant
                : colorScheme.onSurface.withValues(alpha: 0.38),
      ),
    );
    if (!enabled) {
      return icon;
    }
    return ReorderableDragStartListener(index: index, child: icon);
  }
}

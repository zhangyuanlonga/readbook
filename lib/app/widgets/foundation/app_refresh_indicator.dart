import 'package:flutter/material.dart';

class AppRefreshIndicator extends StatelessWidget {
  const AppRefreshIndicator({
    super.key,
    required this.child,
    required this.onRefresh,
    this.notificationPredicate = defaultScrollNotificationPredicate,
    this.triggerMode = RefreshIndicatorTriggerMode.onEdge,
    this.displacement = 40,
    this.edgeOffset = 0,
    this.semanticsLabel,
    this.semanticsValue,
  });

  final Widget child;
  final RefreshCallback onRefresh;
  final ScrollNotificationPredicate notificationPredicate;
  final RefreshIndicatorTriggerMode triggerMode;
  final double displacement;
  final double edgeOffset;
  final String? semanticsLabel;
  final String? semanticsValue;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return RefreshIndicator(
      color: colorScheme.primary,
      backgroundColor: colorScheme.surface,
      strokeWidth: 2.6,
      displacement: displacement,
      edgeOffset: edgeOffset,
      notificationPredicate: notificationPredicate,
      triggerMode: triggerMode,
      semanticsLabel: semanticsLabel,
      semanticsValue: semanticsValue,
      onRefresh: onRefresh,
      child: child,
    );
  }
}

class AppRefreshScrollView extends StatelessWidget {
  const AppRefreshScrollView({
    super.key,
    required this.onRefresh,
    required this.child,
    this.padding,
    this.physics,
    this.controller,
    this.semanticsLabel,
  });

  final RefreshCallback onRefresh;
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final ScrollPhysics? physics;
  final ScrollController? controller;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return AppRefreshIndicator(
      onRefresh: onRefresh,
      semanticsLabel: semanticsLabel,
      child: ListView(
        controller: controller,
        padding: padding,
        physics: AlwaysScrollableScrollPhysics(parent: physics),
        children: [child],
      ),
    );
  }
}

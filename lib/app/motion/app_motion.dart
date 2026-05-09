import 'package:flutter/widgets.dart';

class AppMotion {
  const AppMotion._();

  static const Duration instant = Duration.zero;
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration medium = Duration(milliseconds: 180);
  static const Duration slow = Duration(milliseconds: 260);
  static const Duration page = Duration(milliseconds: 300);

  static const Curve standard = Curves.easeOutCubic;
  static const Curve emphasized = Curves.easeInOutCubic;
  static const Curve decelerate = Curves.easeOutQuart;
  static const Curve accelerate = Curves.easeInCubic;

  static const Offset pageEnterOffset = Offset(0, 0.035);
  static const Offset sectionEnterOffset = Offset(0, 0.02);
  static const Offset microOffset = Offset(0, 0.008);

  static bool enabledOf(BuildContext context, {bool enabled = true}) {
    if (!enabled) {
      return false;
    }
    final scoped = AppMotionScope.maybeOf(context);
    if (scoped != null && !scoped.enabled) {
      return false;
    }
    return !(MediaQuery.maybeOf(context)?.disableAnimations ?? false);
  }

  static Duration durationOf(
    BuildContext context,
    Duration duration, {
    bool enabled = true,
  }) {
    return enabledOf(context, enabled: enabled) ? duration : instant;
  }
}

class AppMotionScope extends InheritedWidget {
  const AppMotionScope({
    super.key,
    required this.enabled,
    required super.child,
  });

  final bool enabled;

  static AppMotionScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppMotionScope>();
  }

  static bool enabledOf(BuildContext context) {
    return AppMotion.enabledOf(context);
  }

  @override
  bool updateShouldNotify(AppMotionScope oldWidget) {
    return enabled != oldWidget.enabled;
  }
}

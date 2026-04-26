import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

CustomTransitionPage<void> buildFadeSlideTransitionPage({
  required GoRouterState state,
  required Widget child,
  Duration transitionDuration = const Duration(milliseconds: 220),
  Duration reverseTransitionDuration = const Duration(milliseconds: 180),
  Offset beginOffset = const Offset(0, 0.02),
  double beginOpacity = 0.82,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    transitionDuration: transitionDuration,
    reverseTransitionDuration: reverseTransitionDuration,
    child: child,
    transitionsBuilder: (
      context,
      animation,
      secondaryAnimation,
      transitionChild,
    ) {
      final curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: Tween<double>(
          begin: beginOpacity,
          end: 1,
        ).animate(curvedAnimation),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: beginOffset,
            end: Offset.zero,
          ).animate(curvedAnimation),
          child: transitionChild,
        ),
      );
    },
  );
}

CustomTransitionPage<void> buildFadeTransitionPage({
  required GoRouterState state,
  required Widget child,
  Duration transitionDuration = const Duration(milliseconds: 320),
  Duration reverseTransitionDuration = const Duration(milliseconds: 220),
  double beginOpacity = 0.2,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    transitionDuration: transitionDuration,
    reverseTransitionDuration: reverseTransitionDuration,
    child: child,
    transitionsBuilder: (
      context,
      animation,
      secondaryAnimation,
      transitionChild,
    ) {
      final curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: Tween<double>(
          begin: beginOpacity,
          end: 1,
        ).animate(curvedAnimation),
        child: transitionChild,
      );
    },
  );
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router_transitions.dart';
import 'presentation/search_page.dart';

final List<RouteBase> searchRoutes = <RouteBase>[
  GoRoute(
    path: '/search',
    name: 'search',
    pageBuilder: (context, state) {
      final entry = state.uri.queryParameters['entry']?.trim().toLowerCase();
      final child = SearchPage(entry: entry);

      if (entry == 'dock') {
        return NoTransitionPage<void>(key: state.pageKey, child: child);
      }

      if (entry == 'bookshelf_top') {
        return CustomTransitionPage<void>(
          key: state.pageKey,
          transitionDuration: Duration.zero,
          reverseTransitionDuration: const Duration(milliseconds: 220),
          child: child,
          transitionsBuilder: (
            context,
            animation,
            secondaryAnimation,
            transitionChild,
          ) {
            if (animation.status != AnimationStatus.reverse) {
              return transitionChild;
            }
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            return FadeTransition(
              opacity: curved,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.985, end: 1).animate(curved),
                child: transitionChild,
              ),
            );
          },
        );
      }

      return buildFadeTransitionPage(state: state, child: child);
    },
  ),
];

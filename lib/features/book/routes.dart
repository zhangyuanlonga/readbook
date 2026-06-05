import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../app/router_transitions.dart';
import '../../domain/entities/book.dart';
import 'presentation/book_detail_page.dart';
import 'presentation/book_detail_route.dart';

final List<RouteBase> bookRoutes = <RouteBase>[
  GoRoute(
    path: BookDetailRouteData.pathPattern,
    name: BookDetailRouteData.routeName,
    pageBuilder: (context, state) {
      final route = BookDetailRouteData.fromUri(state.uri);
      final initialBook = state.extra is Book ? state.extra as Book : null;
      final child = BookDetailPage(
        bookId: route.bookId,
        initialBook: initialBook,
        sourceId: route.sourceId,
        detailUrl: route.detailUrl,
        title: route.title,
        author: route.author,
        coverUrl: route.coverUrl,
        heroTag: route.heroTag,
        titleHeroTag: route.titleHeroTag,
        metaHeroTag: route.metaHeroTag,
        initialEditMode: route.initialEditMode,
      );

      if (route.revealTransition) {
        return NoTransitionPage<void>(key: state.pageKey, child: child);
      }

      return buildFadeSlideTransitionPage(
        state: state,
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 240),
        beginOffset: const Offset(0, 0.03),
        beginOpacity: 0.78,
        child: child,
      );
    },
  ),
];

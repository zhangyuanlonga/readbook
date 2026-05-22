import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../app/router_transitions.dart';
import 'presentation/book_detail_page.dart';

final List<RouteBase> bookRoutes = <RouteBase>[
  GoRoute(
    path: '/book/:bookId',
    name: 'book',
    pageBuilder: (context, state) {
      final bookId = state.pathParameters['bookId'] ?? 'unknown-book';
      final sourceId = state.uri.queryParameters['sourceId'];
      final detailUrl = state.uri.queryParameters['detailUrl'];
      final title = state.uri.queryParameters['title'];
      final author = state.uri.queryParameters['author'];
      final coverUrl = state.uri.queryParameters['coverUrl'];
      final heroTag = state.uri.queryParameters['heroTag'];
      final titleHeroTag = state.uri.queryParameters['titleHeroTag'];
      final metaHeroTag = state.uri.queryParameters['metaHeroTag'];

      return buildFadeSlideTransitionPage(
        state: state,
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 240),
        beginOffset: const Offset(0, 0.03),
        beginOpacity: 0.78,
        child: BookDetailPage(
          bookId: bookId,
          sourceId: sourceId,
          detailUrl: detailUrl,
          title: title,
          author: author,
          coverUrl: coverUrl,
          heroTag: heroTag,
          titleHeroTag: titleHeroTag,
          metaHeroTag: metaHeroTag,
        ),
      );
    },
  ),
];

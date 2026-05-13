import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/composition/app_providers.dart' as app_providers;
import '../../app/router_transitions.dart';
import '../../app/widgets/feature_disabled_page.dart';
import '../../features/reader/application/local/local_reader_identity.dart';
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
      final sourceRuntime =
          ProviderScope.containerOf(
            context,
            listen: false,
          ).read(app_providers.appCapabilitiesProvider).sourceRuntime;
      final isOnlineSource =
          sourceId != null &&
          sourceId.trim().isNotEmpty &&
          !LocalReaderIdentity.isLocalSourceId(sourceId);

      if (isOnlineSource && !sourceRuntime.isSupported) {
        return buildFadeSlideTransitionPage(
          state: state,
          transitionDuration: const Duration(milliseconds: 260),
          reverseTransitionDuration: const Duration(milliseconds: 200),
          child: FeatureDisabledPages.onlineBookDetail(
            capability: sourceRuntime,
          ),
        );
      }

      return buildFadeSlideTransitionPage(
        state: state,
        transitionDuration: const Duration(milliseconds: 260),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        child: BookDetailPage(
          bookId: bookId,
          sourceId: sourceId,
          detailUrl: detailUrl,
          title: title,
          author: author,
          coverUrl: coverUrl,
          heroTag: heroTag,
        ),
      );
    },
  ),
];

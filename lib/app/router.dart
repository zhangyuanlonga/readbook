import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/book/presentation/book_detail_page.dart';
import '../features/book/presentation/local_book_detail_page.dart';
import '../features/bookshelf/presentation/bookshelf_page.dart';
import '../features/discover/presentation/discover_page.dart';
import '../features/mine/presentation/mine_page.dart';
import '../features/mine/presentation/cache_management_page.dart';
import '../features/reader/presentation/local_reader_page.dart';
import '../features/reader/presentation/reader_page.dart';
import '../features/search/presentation/search_page.dart';
import '../features/source/presentation/source_page.dart';
import '../features/source/presentation/source_diagnostics_page.dart';
import 'shell_scaffold.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

GlobalKey<NavigatorState> get appRootNavigatorKey => _rootNavigatorKey;

final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/bookshelf',
  routes: [
    ShellRoute(
      builder: (context, state, child) {
        return ShellScaffold(location: state.matchedLocation, child: child);
      },
      routes: [
        GoRoute(
          path: '/bookshelf',
          name: 'bookshelf',
          builder: (context, state) => const BookshelfPage(),
        ),
        GoRoute(
          path: '/discover',
          name: 'discover',
          builder: (context, state) => const DiscoverPage(),
        ),
        GoRoute(
          path: '/source',
          name: 'source',
          builder: (context, state) => const SourcePage(),
        ),
        GoRoute(
          path: '/mine',
          name: 'mine',
          builder: (context, state) => const MinePage(),
        ),
      ],
    ),
    GoRoute(
      path: '/cache',
      name: 'cache',
      builder: (context, state) => const CacheManagementPage(),
    ),
    GoRoute(
      path: '/search',
      name: 'search',
      builder: (context, state) => const SearchPage(),
    ),
    GoRoute(
      path: '/source-diagnostics',
      name: 'source-diagnostics',
      builder: (context, state) => const SourceDiagnosticsPage(),
    ),

    GoRoute(
      path: '/local/book/:bookId',
      name: 'local-book',
      builder: (context, state) {
        final bookId = state.pathParameters['bookId'] ?? 'unknown-local-book';
        return LocalBookDetailPage(bookId: bookId);
      },
    ),
    GoRoute(
      path: '/local/reader/:bookId/:chapterId',
      name: 'local-reader',
      builder: (context, state) {
        final bookId = state.pathParameters['bookId'] ?? 'unknown-local-book';
        final chapterId =
            state.pathParameters['chapterId'] ?? 'unknown-local-chapter';
        return LocalReaderPage(bookId: bookId, chapterId: chapterId);
      },
    ),
    GoRoute(
      path: '/book/:bookId',
      name: 'book',
      builder: (context, state) {
        final bookId = state.pathParameters['bookId'] ?? 'unknown-book';
        final sourceId = state.uri.queryParameters['sourceId'];
        final detailUrl = state.uri.queryParameters['detailUrl'];
        final title = state.uri.queryParameters['title'];
        final heroTag = state.uri.queryParameters['heroTag'];

        return BookDetailPage(
          bookId: bookId,
          sourceId: sourceId,
          detailUrl: detailUrl,
          title: title,
          heroTag: heroTag,
        );
      },
    ),
    GoRoute(
      path: '/reader/:bookId/:chapterId',
      name: 'reader',
      builder: (context, state) {
        final bookId = state.pathParameters['bookId'] ?? 'unknown-book';
        final chapterId =
            state.pathParameters['chapterId'] ?? 'unknown-chapter';
        final chapterUrl = state.uri.queryParameters['chapterUrl'];
        final chapterTitle = state.uri.queryParameters['chapterTitle'];
        final sourceId = state.uri.queryParameters['sourceId'];
        final detailUrl = state.uri.queryParameters['detailUrl'];
        final chapterIndex = int.tryParse(
          state.uri.queryParameters['chapterIndex'] ?? '',
        );

        return ReaderPage(
          bookId: bookId,
          chapterId: chapterId,
          chapterUrl: chapterUrl,
          chapterTitle: chapterTitle,
          sourceId: sourceId,
          detailUrl: detailUrl,
          chapterIndex: chapterIndex,
        );
      },
    ),
  ],
);

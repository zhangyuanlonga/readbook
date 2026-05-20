import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/navigation/global_navigator.dart';
import '../features/announcement/routes.dart';
import '../features/auth/routes.dart';
import '../features/book/routes.dart';
import '../features/bookshelf/routes.dart';
import '../features/discover/routes.dart';
import '../features/home/routes.dart';
import '../features/mine/routes.dart';
import '../features/mine/providers.dart';
import '../features/reader/routes.dart';
import '../features/search/routes.dart';
import '../features/sync/routes.dart';
import 'shell_scaffold.dart';

GlobalKey<NavigatorState> get appRootNavigatorKey => globalRootNavigatorKey;

final GoRouter appRouter = GoRouter(
  navigatorKey: globalRootNavigatorKey,
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      redirect: (context, state) => resolveMinePageStartupLocation(),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return ShellScaffold(
          location: state.matchedLocation,
          navigationShell: navigationShell,
        );
      },
      branches: [
        homeShellBranch,
        bookshelfShellBranch,
        discoverShellBranch,
        readerStatsShellBranch,
        mineShellBranch,
      ],
    ),
    ...mineRoutes,
    ...announcementRoutes,
    ...authRoutes,
    ...syncRoutes,
    ...searchRoutes,
    ...bookshelfRoutes,
    ...bookRoutes,
    ...readerRoutes,
  ],
);

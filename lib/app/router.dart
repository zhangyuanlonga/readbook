import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/auth/auth_session_secret_store.dart';
import '../core/auth/auth_session_storage_keys.dart';
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
import '../features/source/routes.dart';
import 'layout/app_layout.dart';
import 'shell_scaffold.dart';

GlobalKey<NavigatorState> get appRootNavigatorKey => globalRootNavigatorKey;

final GoRouter appRouter = GoRouter(
  navigatorKey: globalRootNavigatorKey,
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      redirect: (context, state) => resolveAppRootStartupLocation(context),
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
    ...searchRoutes,
    ...sourceRoutes,
    ...bookshelfRoutes,
    ...bookRoutes,
    ...readerRoutes,
  ],
);

String resolveAppRootStartupLocation(BuildContext context) {
  if (AppLayout.isDesktopLike(
    context,
    isWeb: kIsWeb,
    platform: Theme.of(context).platform,
  )) {
    final hasDisplaySession =
        AuthSessionSnapshotBootstrap.hasDisplaySessionSync();
    final hasFallbackSecrets =
        AuthSessionSnapshotBootstrap.hasFallbackSecretsSync();
    if (hasDisplaySession || hasFallbackSecrets) {
      return resolveMinePageStartupLocation();
    }
    return '/auth';
  }
  return resolveMinePageStartupLocation();
}

class AuthSessionSnapshotBootstrap {
  AuthSessionSnapshotBootstrap._();

  static SharedPreferences? _primedPreferences;

  static void prime(SharedPreferences prefs) {
    _primedPreferences = prefs;
  }

  static bool hasDisplaySessionSync() {
    final prefs = _primedPreferences;
    if (prefs == null) {
      return false;
    }
    return (prefs.getString(authUserIdStorageKey)?.trim().isNotEmpty ??
            false) ||
        (prefs.getString(authUsernameStorageKey)?.trim().isNotEmpty ?? false) ||
        (prefs.getString(authAccountStorageKey)?.trim().isNotEmpty ?? false) ||
        (prefs.getString(authDisplayNameStorageKey)?.trim().isNotEmpty ??
            false);
  }

  static bool hasFallbackSecretsSync() {
    final prefs = _primedPreferences;
    if (prefs == null) {
      return false;
    }
    return hasPersistedFallbackAuthSecretsSync(prefs);
  }
}

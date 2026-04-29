import 'package:go_router/go_router.dart';

import 'presentation/pages/sync_history_page.dart';
import 'presentation/pages/sync_settings_page.dart';

final List<RouteBase> syncRoutes = <RouteBase>[
  GoRoute(
    path: '/sync',
    name: 'sync',
    builder: (context, state) => const SyncSettingsPage(),
  ),
  GoRoute(
    path: '/sync/history',
    name: 'sync-history',
    builder: (context, state) => const SyncHistoryPage(),
  ),
];

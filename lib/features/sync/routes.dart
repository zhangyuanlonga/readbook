import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/platform/app_platform_capabilities.dart';
import '../../app/widgets/feature_disabled_page.dart';
import 'presentation/pages/sync_history_page.dart';
import 'presentation/pages/sync_settings_page.dart';

final List<RouteBase> syncRoutes = <RouteBase>[
  GoRoute(
    path: '/sync',
    name: 'sync',
    builder:
        (context, state) => Consumer(
          builder: (context, ref, _) {
            final capabilities = ref.watch(appPlatformCapabilitiesProvider);
            if (!capabilities.webDavSync.isSupported) {
              return FeatureDisabledPages.webDavSync(
                capability: capabilities.webDavSync,
              );
            }
            return const SyncSettingsPage();
          },
        ),
  ),
  GoRoute(
    path: '/sync/history',
    name: 'sync-history',
    builder:
        (context, state) => Consumer(
          builder: (context, ref, _) {
            final capabilities = ref.watch(appPlatformCapabilitiesProvider);
            if (!capabilities.webDavSync.isSupported) {
              return FeatureDisabledPages.syncHistory(
                capability: capabilities.webDavSync,
              );
            }
            return const SyncHistoryPage();
          },
        ),
  ),
];

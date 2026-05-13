import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/composition/app_providers.dart' as app_providers;
import '../../app/widgets/feature_disabled_page.dart';
import 'presentation/discover_page.dart';

final StatefulShellBranch discoverShellBranch = StatefulShellBranch(
  routes: [
    GoRoute(
      path: '/discover',
      name: 'discover',
      builder: (context, state) {
        final sourceRuntime =
            ProviderScope.containerOf(
              context,
              listen: false,
            ).read(app_providers.appCapabilitiesProvider).sourceRuntime;
        if (!sourceRuntime.isSupported) {
          return FeatureDisabledPages.discover(capability: sourceRuntime);
        }
        return const DiscoverPage();
      },
    ),
  ],
);

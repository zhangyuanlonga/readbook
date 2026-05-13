import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/composition/app_providers.dart' as app_providers;
import '../../app/router_transitions.dart';
import '../../app/widgets/feature_disabled_page.dart';
import 'presentation/search_page.dart';

final List<RouteBase> searchRoutes = <RouteBase>[
  GoRoute(
    path: '/search',
    name: 'search',
    pageBuilder: (context, state) {
      final sourceRuntime =
          ProviderScope.containerOf(
            context,
            listen: false,
          ).read(app_providers.appCapabilitiesProvider).sourceRuntime;
      return buildFadeTransitionPage(
        state: state,
        child:
            sourceRuntime.isSupported
                ? const SearchPage()
                : FeatureDisabledPages.onlineSearch(capability: sourceRuntime),
      );
    },
  ),
];

import 'package:go_router/go_router.dart';

import '../../app/router_transitions.dart';
import 'presentation/search_page.dart';

final List<RouteBase> searchRoutes = <RouteBase>[
  GoRoute(
    path: '/search',
    name: 'search',
    pageBuilder:
        (context, state) =>
            buildFadeTransitionPage(state: state, child: const SearchPage()),
  ),
];

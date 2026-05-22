import 'package:go_router/go_router.dart';
import 'presentation/search_page.dart';

final List<RouteBase> searchRoutes = <RouteBase>[
  GoRoute(
    path: '/search',
    name: 'search',
    pageBuilder:
        (context, state) => NoTransitionPage<void>(
          key: state.pageKey,
          child: const SearchPage(),
        ),
  ),
];

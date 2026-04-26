import 'package:go_router/go_router.dart';

import 'presentation/discover_page.dart';

final StatefulShellBranch discoverShellBranch = StatefulShellBranch(
  routes: [
    GoRoute(
      path: '/discover',
      name: 'discover',
      builder: (context, state) => const DiscoverPage(),
    ),
  ],
);

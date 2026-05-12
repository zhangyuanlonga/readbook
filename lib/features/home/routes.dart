import 'package:go_router/go_router.dart';

import 'presentation/home_page.dart';

final StatefulShellBranch homeShellBranch = StatefulShellBranch(
  routes: [
    GoRoute(
      path: '/home',
      name: 'home',
      builder: (context, state) => const HomePage(),
    ),
  ],
);

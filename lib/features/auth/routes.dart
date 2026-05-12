import 'package:go_router/go_router.dart';

import 'presentation/auth_page.dart';
import 'presentation/user_profile_page.dart';

final List<RouteBase> authRoutes = <RouteBase>[
  GoRoute(
    path: '/auth',
    name: 'auth',
    builder: (context, state) => const AuthPage(),
  ),
  GoRoute(
    path: '/profile',
    name: 'profile',
    builder: (context, state) => const UserProfilePage(),
  ),
];

import 'package:go_router/go_router.dart';

import 'presentation/onboarding_page.dart';

final List<RouteBase> onboardingRoutes = <RouteBase>[
  GoRoute(
    path: '/onboarding',
    builder: (context, state) => const OnboardingPage(),
  ),
];

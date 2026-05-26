import 'package:go_router/go_router.dart';

import 'presentation/discover_category_books_page.dart';
import 'presentation/discover_page.dart';

final StatefulShellBranch discoverShellBranch = StatefulShellBranch(
  routes: [
    GoRoute(
      path: '/discover',
      name: 'discover',
      builder: (context, state) => const DiscoverPage(),
      routes: [
        GoRoute(
          path: 'source/:sourceId/category/:categoryId',
          name: 'discover-category-books',
          pageBuilder: (context, state) {
            return NoTransitionPage<void>(
              key: state.pageKey,
              child: DiscoverCategoryBooksPage(
                sourceId: state.pathParameters['sourceId'] ?? '',
                categoryId: state.pathParameters['categoryId'] ?? '',
              ),
            );
          },
        ),
      ],
    ),
  ],
);

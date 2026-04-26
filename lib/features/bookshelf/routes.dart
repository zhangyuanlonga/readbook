import 'package:go_router/go_router.dart';

import '../book/presentation/book_detail_page.dart';
import 'application/local_book_import_service.dart';
import 'presentation/bookshelf_page.dart';
import 'presentation/local_library_page.dart';

final StatefulShellBranch bookshelfShellBranch = StatefulShellBranch(
  routes: [
    GoRoute(
      path: '/bookshelf',
      name: 'bookshelf',
      builder: (context, state) => const BookshelfPage(),
    ),
  ],
);

final List<RouteBase> bookshelfRoutes = <RouteBase>[
  GoRoute(
    path: '/local-library',
    name: 'local-library',
    builder: (context, state) => const LocalLibraryPage(),
  ),
  GoRoute(
    path: '/local/book/:bookId',
    name: 'local-book',
    redirect: (context, state) {
      final bookId = state.pathParameters['bookId'] ?? 'unknown-local-book';
      final query = Map<String, String>.from(state.uri.queryParameters);
      query['sourceId'] = LocalBookImportService.localBookSourceId;
      query['detailUrl'] = 'local://book/$bookId';
      return Uri(path: '/book/$bookId', queryParameters: query).toString();
    },
    builder: (context, state) {
      final bookId = state.pathParameters['bookId'] ?? 'unknown-local-book';
      return BookDetailPage(
        bookId: bookId,
        sourceId: LocalBookImportService.localBookSourceId,
        detailUrl: 'local://book/$bookId',
      );
    },
  ),
];

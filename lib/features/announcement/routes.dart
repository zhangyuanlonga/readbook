import 'package:go_router/go_router.dart';

import 'presentation/announcement_detail_page.dart';
import 'presentation/announcement_list_page.dart';

final List<RouteBase> announcementRoutes = <RouteBase>[
  GoRoute(
    path: '/announcements',
    name: 'announcements',
    builder: (context, state) => const AnnouncementListPage(),
  ),
  GoRoute(
    path: '/announcements/:id',
    name: 'announcement-detail',
    builder: (context, state) {
      final id = state.pathParameters['id'] ?? '';
      return AnnouncementDetailPage(announcementId: id);
    },
  ),
];

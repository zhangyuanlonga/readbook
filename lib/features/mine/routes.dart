import 'package:go_router/go_router.dart';

import 'presentation/about_page.dart';
import 'presentation/advanced_theme_editor_page.dart';
import 'presentation/advanced_theme_list_page.dart';
import 'presentation/appearance_page.dart';
import 'presentation/bookmarks_page.dart';
import 'presentation/bottom_nav_icon_gallery_editor_page.dart';
import 'presentation/bottom_nav_icon_gallery_page.dart';
import 'presentation/cache_management_page.dart';
import 'presentation/cover_gallery_editor_page.dart';
import 'presentation/cover_gallery_page.dart';
import 'presentation/feedback_page.dart';
import 'presentation/font_management_page.dart';
import 'presentation/launch_image_gallery_editor_page.dart';
import 'presentation/launch_image_gallery_page.dart';
import 'presentation/membership_center_page.dart';
import 'presentation/mine_management_page.dart';
import 'presentation/mine_page.dart';
import 'presentation/reader_background_page.dart';
import 'presentation/system_settings_page.dart';
import '../error/presentation/error_center_page.dart';

final StatefulShellBranch mineShellBranch = StatefulShellBranch(
  routes: [
    GoRoute(
      path: '/mine',
      name: 'mine',
      builder: (context, state) => const MinePage(),
    ),
  ],
);

final List<RouteBase> mineRoutes = <RouteBase>[
  GoRoute(
    path: '/appearance',
    name: 'appearance',
    builder: (context, state) {
      final section = switch (state.uri.queryParameters['section']) {
        'appearance' => AppearanceSection.appearance,
        'tab-bar' => AppearanceSection.tabBar,
        'cover' => AppearanceSection.cover,
        'background' => AppearanceSection.background,
        _ => AppearanceSection.appearance,
      };
      return AppearancePage(section: section);
    },
  ),
  GoRoute(
    path: '/appearance/reader-background',
    name: 'reader-background',
    builder: (context, state) => const ReaderBackgroundPage(),
  ),
  GoRoute(
    path: '/appearance/launch-image',
    name: 'launch-image',
    builder: (context, state) => const LaunchImageGalleryPage(),
  ),
  GoRoute(
    path: '/appearance/launch-image/editor',
    name: 'launch-image-editor',
    builder: (context, state) {
      final galleryId = state.uri.queryParameters['id'] ?? '';
      return LaunchImageGalleryEditorPage(galleryId: galleryId);
    },
  ),
  GoRoute(
    path: '/appearance/advanced-themes',
    name: 'advanced-themes',
    builder: (context, state) => const AdvancedThemeListPage(),
  ),
  GoRoute(
    path: '/appearance/advanced-themes/editor',
    name: 'advanced-theme-editor',
    builder: (context, state) {
      final themeId = state.uri.queryParameters['id'];
      return AdvancedThemeEditorPage(themeId: themeId);
    },
  ),
  GoRoute(
    path: '/bottom-nav-icon-galleries',
    name: 'bottom-nav-icon-galleries',
    builder: (context, state) => const BottomNavIconGalleryPage(),
  ),
  GoRoute(
    path: '/bottom-nav-icon-galleries/editor',
    name: 'bottom-nav-icon-gallery-editor',
    builder: (context, state) {
      final galleryId = state.uri.queryParameters['id'] ?? '';
      return BottomNavIconGalleryEditorPage(galleryId: galleryId);
    },
  ),
  GoRoute(
    path: '/cover-galleries',
    name: 'cover-galleries',
    builder: (context, state) => const CoverGalleryPage(),
  ),
  GoRoute(
    path: '/cover-galleries/editor',
    name: 'cover-gallery-editor',
    builder: (context, state) {
      final galleryId = state.uri.queryParameters['id'] ?? '';
      return CoverGalleryEditorPage(galleryId: galleryId);
    },
  ),
  GoRoute(
    path: '/cache',
    name: 'cache',
    builder: (context, state) => const CacheManagementPage(),
  ),
  GoRoute(
    path: '/mine/tags',
    name: 'mine-tags',
    builder:
        (context, state) => const MineManagementPage(
          section: MineManagementSection.tagManagement,
        ),
  ),
  GoRoute(
    path: '/mine/categories',
    name: 'mine-categories',
    builder:
        (context, state) => const MineManagementPage(
          section: MineManagementSection.categoryManagement,
        ),
  ),
  GoRoute(
    path: '/membership',
    name: 'membership',
    builder: (context, state) => const MembershipCenterPage(),
  ),
  GoRoute(
    path: '/about',
    name: 'about',
    builder: (context, state) => const AboutPage(),
  ),
  GoRoute(
    path: '/system-settings',
    name: 'system-settings',
    builder: (context, state) => const SystemSettingsPage(),
  ),
  GoRoute(
    path: '/font-management',
    name: 'font-management',
    builder: (context, state) => const FontManagementPage(),
  ),
  GoRoute(
    path: '/bookmarks',
    name: 'bookmarks',
    builder: (context, state) => const BookmarksPage(),
  ),
  GoRoute(
    path: '/error-center',
    name: 'error-center',
    builder: (context, state) => const ErrorCenterPage(),
  ),
  GoRoute(
    path: '/feedback',
    name: 'feedback',
    builder: (context, state) => const FeedbackPage(),
  ),
  GoRoute(
    path: '/feedback/:id',
    name: 'feedback-detail',
    builder: (context, state) {
      final id = state.pathParameters['id'] ?? '';
      return FeedbackDetailPage(feedbackId: id);
    },
  ),
  GoRoute(
    path: '/feedback/compose',
    name: 'feedback-compose',
    builder: (context, state) => const FeedbackComposePage(),
  ),
];

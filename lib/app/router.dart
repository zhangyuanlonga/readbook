import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/navigation/global_navigator.dart';
import '../features/book/presentation/book_detail_page.dart';
import '../features/bookshelf/application/local_book_import_service.dart';
import '../features/bookshelf/presentation/bookshelf_page.dart';
import '../features/bookshelf/presentation/local_library_page.dart';
import '../features/discover/presentation/discover_page.dart';
import '../features/announcement/presentation/announcement_detail_page.dart';
import '../features/announcement/presentation/announcement_list_page.dart';
import '../features/mine/presentation/mine_page.dart';
import '../features/mine/presentation/appearance_page.dart';
import '../features/mine/presentation/cache_management_page.dart';
import '../features/mine/presentation/mine_management_page.dart';
import '../features/mine/presentation/membership_center_page.dart';
import '../features/mine/presentation/about_page.dart';
import '../features/mine/presentation/advanced_theme_editor_page.dart';
import '../features/mine/presentation/advanced_theme_list_page.dart';
import '../features/mine/presentation/bookmarks_page.dart';
import '../features/mine/presentation/bottom_nav_icon_gallery_page.dart';
import '../features/mine/presentation/bottom_nav_icon_gallery_editor_page.dart';
import '../features/mine/presentation/cover_gallery_editor_page.dart';
import '../features/mine/presentation/cover_gallery_page.dart';
import '../features/mine/presentation/feedback_page.dart';
import '../features/mine/presentation/feature_placeholder_page.dart';
import '../features/mine/presentation/system_settings_page.dart';
import '../features/auth/presentation/auth_page.dart';
import '../features/auth/presentation/user_profile_page.dart';
import '../features/reader/presentation/reader_page.dart';
import '../features/reader/presentation/reader_route.dart';
import '../features/search/presentation/search_page.dart';
import '../features/source/presentation/source_page.dart';
import '../features/source/presentation/script_source_editor_page.dart';
import '../features/source/presentation/script_source_paste_import_page.dart';
import '../features/reader/presentation/reading_records_page.dart';
import 'shell_scaffold.dart';
import 'theme/app_interface_typography_provider.dart';
import 'theme/app_theme.dart';

GlobalKey<NavigatorState> get appRootNavigatorKey => globalRootNavigatorKey;

final GoRouter appRouter = GoRouter(
  navigatorKey: globalRootNavigatorKey,
  initialLocation: '/bookshelf',
  redirect: (context, state) {
    final scheme = state.uri.scheme.toLowerCase();
    if (scheme == 'file' || scheme == 'content') {
      return '/source';
    }
    return null;
  },
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return ShellScaffold(
          location: state.matchedLocation,
          navigationShell: navigationShell,
        );
      },
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/bookshelf',
              name: 'bookshelf',
              builder: (context, state) => const BookshelfPage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/discover',
              name: 'discover',
              builder: (context, state) => const DiscoverPage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/stats',
              name: 'stats',
              builder: (context, state) => const ReadingRecordsPage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/mine',
              name: 'mine',
              builder: (context, state) => const MinePage(),
            ),
          ],
        ),
      ],
    ),
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
      builder:
          (context, state) => const FeaturePlaceholderPage(
            kind: FeaturePlaceholderKind.readerBackground,
          ),
    ),
    GoRoute(
      path: '/appearance/launch-image',
      name: 'launch-image',
      builder:
          (context, state) => const FeaturePlaceholderPage(
            kind: FeaturePlaceholderKind.launchImage,
          ),
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
      path: '/mine/chapter-rules',
      name: 'mine-chapter-rules',
      builder:
          (context, state) => const MineManagementPage(
            section: MineManagementSection.chapterRuleManagement,
          ),
    ),
    GoRoute(
      path: '/mine/content-cleanup',
      name: 'mine-content-cleanup',
      builder:
          (context, state) => const MineManagementPage(
            section: MineManagementSection.contentCleanup,
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
    GoRoute(
      path: '/system-settings',
      name: 'system-settings',
      builder: (context, state) => const SystemSettingsPage(),
    ),
    GoRoute(
      path: '/font-management',
      name: 'font-management',
      builder:
          (context, state) => const FeaturePlaceholderPage(
            kind: FeaturePlaceholderKind.fontManagement,
          ),
    ),
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
    GoRoute(
      path: '/bookmarks',
      name: 'bookmarks',
      builder: (context, state) => const BookmarksPage(),
    ),
    GoRoute(
      path: '/read-records',
      name: 'read-records',
      redirect: (context, state) => '/stats',
    ),
    GoRoute(
      path: '/source',
      name: 'source',
      builder: (context, state) => const SourcePage(),
    ),
    GoRoute(
      path: '/source/script-editor',
      name: 'script-source-editor',
      pageBuilder:
          (context, state) => CustomTransitionPage<void>(
            key: state.pageKey,
            transitionDuration: const Duration(milliseconds: 220),
            reverseTransitionDuration: const Duration(milliseconds: 180),
            child: ScriptSourceEditorPage(
              scriptSourceId: state.uri.queryParameters['id'],
            ),
            transitionsBuilder: (
              context,
              animation,
              secondaryAnimation,
              child,
            ) {
              final curvedAnimation = CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
                reverseCurve: Curves.easeInCubic,
              );
              return FadeTransition(
                opacity: Tween<double>(
                  begin: 0.82,
                  end: 1,
                ).animate(curvedAnimation),
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.02),
                    end: Offset.zero,
                  ).animate(curvedAnimation),
                  child: child,
                ),
              );
            },
          ),
    ),
    GoRoute(
      path: '/source/paste-import',
      name: 'script-source-paste-import',
      pageBuilder:
          (context, state) => CustomTransitionPage<void>(
            key: state.pageKey,
            transitionDuration: const Duration(milliseconds: 220),
            reverseTransitionDuration: const Duration(milliseconds: 180),
            child: const ScriptSourcePasteImportPage(),
            transitionsBuilder: (
              context,
              animation,
              secondaryAnimation,
              child,
            ) {
              final curvedAnimation = CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
                reverseCurve: Curves.easeInCubic,
              );
              return FadeTransition(
                opacity: Tween<double>(
                  begin: 0.82,
                  end: 1,
                ).animate(curvedAnimation),
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.02),
                    end: Offset.zero,
                  ).animate(curvedAnimation),
                  child: child,
                ),
              );
            },
          ),
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
    GoRoute(
      path: '/search',
      name: 'search',
      pageBuilder:
          (context, state) => CustomTransitionPage<void>(
            key: state.pageKey,
            transitionDuration: const Duration(milliseconds: 320),
            reverseTransitionDuration: const Duration(milliseconds: 220),
            child: const SearchPage(),
            transitionsBuilder: (
              context,
              animation,
              secondaryAnimation,
              child,
            ) {
              final curved = CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
                reverseCurve: Curves.easeInCubic,
              );
              return FadeTransition(
                opacity: Tween<double>(begin: 0.2, end: 1).animate(curved),
                child: child,
              );
            },
          ),
    ),
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
    GoRoute(
      path: '/local/reader/:bookId/:chapterId',
      name: 'local-reader',
      redirect: (context, state) {
        final bookId = state.pathParameters['bookId'] ?? 'unknown-local-book';
        final chapterId =
            state.pathParameters['chapterId'] ?? 'unknown-local-chapter';
        final query = Map<String, String>.from(state.uri.queryParameters);
        query['sourceId'] = LocalBookImportService.localBookSourceId;
        query['detailUrl'] = 'local://book/$bookId';
        query['chapterUrl'] = 'local://chapter/$chapterId';
        return buildReaderRoute(
          bookId: bookId,
          chapterId: chapterId,
          chapterUrl: query['chapterUrl'],
          chapterTitle: query['chapterTitle'],
          sourceId: query['sourceId'],
          detailUrl: query['detailUrl'],
          chapterIndex: int.tryParse(query['chapterIndex'] ?? ''),
          bookmarkId: query['bookmarkId'],
        );
      },
      builder: (context, state) {
        final bookId = state.pathParameters['bookId'] ?? 'unknown-local-book';
        final chapterId =
            state.pathParameters['chapterId'] ?? 'unknown-local-chapter';
        final bookmarkId = state.uri.queryParameters['bookmarkId'];
        return Consumer(
          builder: (context, ref, _) {
            final interfaceTextScale = ref.watch(appInterfaceTextScaleProvider);
            final currentScale = MediaQuery.textScalerOf(context).scale(1);
            final baseScale =
                (currentScale / interfaceTextScale).clamp(0.6, 1.5).toDouble();
            return MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(baseScale)),
              child: Theme(
                data: AppTheme.build(Theme.of(context).colorScheme),
                child: ReaderPage(
                  bookId: bookId,
                  chapterId: chapterId,
                  sourceId: LocalBookImportService.localBookSourceId,
                  detailUrl: 'local://book/$bookId',
                  chapterUrl: 'local://chapter/$chapterId',
                  bookmarkId: bookmarkId,
                ),
              ),
            );
          },
        );
      },
    ),
    GoRoute(
      path: '/book/:bookId',
      name: 'book',
      builder: (context, state) {
        final bookId = state.pathParameters['bookId'] ?? 'unknown-book';
        final sourceId = state.uri.queryParameters['sourceId'];
        final detailUrl = state.uri.queryParameters['detailUrl'];
        final title = state.uri.queryParameters['title'];
        final heroTag = state.uri.queryParameters['heroTag'];

        return BookDetailPage(
          bookId: bookId,
          sourceId: sourceId,
          detailUrl: detailUrl,
          title: title,
          heroTag: heroTag,
        );
      },
    ),
    GoRoute(
      path: '/reader/:bookId/:chapterId',
      name: 'reader',
      builder: (context, state) {
        final bookId = state.pathParameters['bookId'] ?? 'unknown-book';
        final chapterId =
            state.pathParameters['chapterId'] ?? 'unknown-chapter';
        final chapterUrl = state.uri.queryParameters['chapterUrl'];
        final chapterTitle = state.uri.queryParameters['chapterTitle'];
        final sourceId = state.uri.queryParameters['sourceId'];
        final detailUrl = state.uri.queryParameters['detailUrl'];
        final bookmarkId = state.uri.queryParameters['bookmarkId'];
        final chapterIndex = int.tryParse(
          state.uri.queryParameters['chapterIndex'] ?? '',
        );

        return Consumer(
          builder: (context, ref, _) {
            final interfaceTextScale = ref.watch(appInterfaceTextScaleProvider);
            final currentScale = MediaQuery.textScalerOf(context).scale(1);
            final baseScale =
                (currentScale / interfaceTextScale).clamp(0.6, 1.5).toDouble();
            return MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(baseScale)),
              child: Theme(
                data: AppTheme.build(Theme.of(context).colorScheme),
                child: ReaderPage(
                  bookId: bookId,
                  chapterId: chapterId,
                  chapterUrl: chapterUrl,
                  chapterTitle: chapterTitle,
                  sourceId: sourceId,
                  detailUrl: detailUrl,
                  chapterIndex: chapterIndex,
                  bookmarkId: bookmarkId,
                ),
              ),
            );
          },
        );
      },
    ),
  ],
);

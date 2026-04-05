import 'package:flutter/material.dart';
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
import '../features/mine/presentation/about_page.dart';
import '../features/mine/presentation/bookmarks_page.dart';
import '../features/mine/presentation/feedback_page.dart';
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

GlobalKey<NavigatorState> get appRootNavigatorKey => globalRootNavigatorKey;

final GoRouter appRouter = GoRouter(
  navigatorKey: globalRootNavigatorKey,
  initialLocation: '/bookshelf',
  redirect: (context, state) {
    if (state.uri.scheme == 'file') {
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
      builder: (context, state) => const AppearancePage(),
    ),
    GoRoute(
      path: '/cache',
      name: 'cache',
      builder: (context, state) => const CacheManagementPage(),
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
      builder: (context, state) => const ReadingRecordsPage(),
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
      path: '/feedback/compose',
      name: 'feedback-compose',
      builder: (context, state) => const FeedbackComposePage(),
    ),
    GoRoute(
      path: '/search',
      name: 'search',
      builder: (context, state) => const SearchPage(),
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
        return ReaderPage(
          bookId: bookId,
          chapterId: chapterId,
          sourceId: LocalBookImportService.localBookSourceId,
          detailUrl: 'local://book/$bookId',
          chapterUrl: 'local://chapter/$chapterId',
          bookmarkId: bookmarkId,
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

        return ReaderPage(
          bookId: bookId,
          chapterId: chapterId,
          chapterUrl: chapterUrl,
          chapterTitle: chapterTitle,
          sourceId: sourceId,
          detailUrl: detailUrl,
          chapterIndex: chapterIndex,
          bookmarkId: bookmarkId,
        );
      },
    ),
  ],
);

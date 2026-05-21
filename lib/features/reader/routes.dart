import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router_transitions.dart';
import '../../app/theme/app_interface_typography_provider.dart';
import '../../domain/entities/book_identity.dart';
import '../bookshelf/application/local_book_import_service.dart';
import 'presentation/reader_page.dart';
import 'presentation/reader_route.dart';
import 'presentation/reading_records_page.dart';

final StatefulShellBranch readerStatsShellBranch = StatefulShellBranch(
  routes: [
    GoRoute(
      path: '/stats',
      name: 'stats',
      builder: (context, state) => const ReadingRecordsPage(),
    ),
  ],
);

final List<RouteBase> readerRoutes = <RouteBase>[
  GoRoute(
    path: '/read-records',
    name: 'read-records',
    redirect: (context, state) => '/stats',
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
      query['detailUrl'] = buildLocalBookDetailUrl(bookId);
      query['chapterUrl'] = buildLocalChapterUrl(chapterId);
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
    pageBuilder: (context, state) {
      final bookId = state.pathParameters['bookId'] ?? 'unknown-local-book';
      final chapterId =
          state.pathParameters['chapterId'] ?? 'unknown-local-chapter';
      final bookmarkId = state.uri.queryParameters['bookmarkId'];
      final heroTag = state.uri.queryParameters['heroTag'];
      return buildFadeTransitionPage(
        state: state,
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 180),
        beginOpacity: 0.88,
        child: _buildReaderRoutePage(
          context,
          bookId: bookId,
          chapterId: chapterId,
          sourceId: LocalBookImportService.localBookSourceId,
          detailUrl: buildLocalBookDetailUrl(bookId),
          chapterUrl: buildLocalChapterUrl(chapterId),
          bookmarkId: bookmarkId,
          heroTag: heroTag,
        ),
      );
    },
  ),
  GoRoute(
    path: '/reader/:bookId/:chapterId',
    name: 'reader',
    pageBuilder: (context, state) {
      final bookId = state.pathParameters['bookId'] ?? 'unknown-book';
      final chapterId = state.pathParameters['chapterId'] ?? 'unknown-chapter';
      final chapterUrl = state.uri.queryParameters['chapterUrl'];
      final chapterTitle = state.uri.queryParameters['chapterTitle'];
      final sourceId = state.uri.queryParameters['sourceId'];
      final detailUrl = state.uri.queryParameters['detailUrl'];
      final bookmarkId = state.uri.queryParameters['bookmarkId'];
      final openRequestedAtMs = int.tryParse(
        state.uri.queryParameters['openRequestedAtMs'] ?? '',
      );
      final openRouteKind = state.uri.queryParameters['openRouteKind'];
      final heroTag = state.uri.queryParameters['heroTag'];
      final chapterIndex = int.tryParse(
        state.uri.queryParameters['chapterIndex'] ?? '',
      );

      return buildFadeTransitionPage(
        state: state,
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 180),
        beginOpacity: 0.88,
        child: _buildReaderRoutePage(
          context,
          bookId: bookId,
          chapterId: chapterId,
          chapterUrl: chapterUrl,
          chapterTitle: chapterTitle,
          sourceId: sourceId,
          detailUrl: detailUrl,
          chapterIndex: chapterIndex,
          bookmarkId: bookmarkId,
          openRequestedAtMs: openRequestedAtMs,
          openRouteKind: openRouteKind,
          heroTag: heroTag,
        ),
      );
    },
  ),
];

Widget _buildReaderRoutePage(
  BuildContext context, {
  required String bookId,
  required String chapterId,
  String? chapterUrl,
  String? chapterTitle,
  String? sourceId,
  String? detailUrl,
  int? chapterIndex,
  String? bookmarkId,
  int? openRequestedAtMs,
  String? openRouteKind,
  String? heroTag,
}) {
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
        child: ReaderPage(
          bookId: bookId,
          chapterId: chapterId,
          chapterUrl: chapterUrl,
          chapterTitle: chapterTitle,
          sourceId: sourceId,
          detailUrl: detailUrl,
          chapterIndex: chapterIndex,
          bookmarkId: bookmarkId,
          openRequestedAtMs: openRequestedAtMs,
          openRouteKind: openRouteKind,
          heroTag: heroTag,
        ),
      );
    },
  );
}

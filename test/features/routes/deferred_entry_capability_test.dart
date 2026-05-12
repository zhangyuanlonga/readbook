import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shuxiang_reading_next/app/composition/app_providers.dart'
    as app_providers;
import 'package:shuxiang_reading_next/app/platform/app_platform_capabilities.dart';
import 'package:shuxiang_reading_next/app/widgets/feature_disabled_page.dart';
import 'package:shuxiang_reading_next/features/book/routes.dart';
import 'package:shuxiang_reading_next/features/discover/routes.dart';
import 'package:shuxiang_reading_next/features/reader/routes.dart';
import 'package:shuxiang_reading_next/features/search/routes.dart';
import 'package:shuxiang_reading_next/features/source/routes.dart';

void main() {
  testWidgets('source, search, and discover routes show disabled pages', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/source',
      routes: <RouteBase>[
        ...sourceRoutes,
        ...searchRoutes,
        discoverShellBranch.routes.first,
        GoRoute(
          path: '/bookshelf',
          builder: (context, state) => const Placeholder(),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(_buildTestApp(router));
    await tester.pumpAndSettle();
    expect(find.byType(FeatureDisabledPage), findsOneWidget);
    expect(find.text('书源功能暂未启用'), findsWidgets);

    router.go('/search');
    await tester.pumpAndSettle();
    expect(find.byType(FeatureDisabledPage), findsOneWidget);
    expect(find.text('在线搜索暂未启用'), findsWidgets);

    router.go('/discover');
    await tester.pumpAndSettle();
    expect(find.byType(FeatureDisabledPage), findsOneWidget);
    expect(find.text('发现暂未启用'), findsWidgets);
  });

  testWidgets(
    'online book and reader routes are disabled without source runtime',
    (tester) async {
      final router = GoRouter(
        initialLocation:
            '/book/book_a?sourceId=source_a&detailUrl=https%3A%2F%2Fexample.com%2Fdetail',
        routes: <RouteBase>[
          ...bookRoutes,
          ...readerRoutes,
          GoRoute(
            path: '/bookshelf',
            builder: (context, state) => const Placeholder(),
          ),
          GoRoute(
            path: '/stats',
            builder: (context, state) => const Placeholder(),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(_buildTestApp(router));
      await tester.pumpAndSettle();
      expect(find.byType(FeatureDisabledPage), findsOneWidget);
      expect(find.text('在线详情暂未启用'), findsWidgets);

      router.go(
        '/reader/book_a/chapter_a'
        '?sourceId=source_a'
        '&detailUrl=https%3A%2F%2Fexample.com%2Fdetail'
        '&chapterUrl=https%3A%2F%2Fexample.com%2Fc1',
      );
      await tester.pumpAndSettle();
      expect(find.byType(FeatureDisabledPage), findsOneWidget);
      expect(find.text('在线章节暂未启用'), findsWidgets);
    },
  );
}

Widget _buildTestApp(GoRouter router) {
  return ProviderScope(
    overrides: [
      app_providers.appCapabilitiesProvider.overrideWith(
        (ref) => AppPlatformCapabilities.current(sourceRuntimeEnabled: false),
      ),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

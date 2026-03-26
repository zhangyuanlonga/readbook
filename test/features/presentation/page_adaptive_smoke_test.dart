import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_appread/features/bookshelf/presentation/bookshelf_page.dart';
import 'package:flutter_appread/features/mine/presentation/mine_page.dart';
import 'package:flutter_appread/features/search/presentation/search_page.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('BookshelfPage renders on phone and large screens', (
    tester,
  ) async {
    await _runAdaptiveSmokeMatrix(
      tester,
      pageBuilder: () => const BookshelfPage(prefetchAnnouncementOnInit: false),
      useProviderScope: false,
      pageName: 'BookshelfPage',
    );
  });

  testWidgets('MinePage renders on phone and large screens', (tester) async {
    await _runAdaptiveSmokeMatrix(
      tester,
      pageBuilder: () => const MinePage(),
      useProviderScope: true,
      pageName: 'MinePage',
    );
  });

  testWidgets('SearchPage renders on phone and large screens', (tester) async {
    await _runAdaptiveSmokeMatrix(
      tester,
      pageBuilder: () => const SearchPage(),
      useProviderScope: false,
      pageName: 'SearchPage',
    );
  });
}

Future<void> _runAdaptiveSmokeMatrix(
  WidgetTester tester, {
  required Widget Function() pageBuilder,
  required bool useProviderScope,
  required String pageName,
}) async {
  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
    tester.view.resetDevicePixelRatio();
  });

  const cases = <_ViewportCase>[
    _ViewportCase(name: 'phone_360', size: Size(360, 800), dpr: 3.0),
    _ViewportCase(name: 'phone_390', size: Size(390, 844), dpr: 3.0),
    _ViewportCase(name: 'phone_412', size: Size(412, 915), dpr: 3.5),
    _ViewportCase(name: 'phone_414', size: Size(414, 921), dpr: 3.25),
    _ViewportCase(name: 'phone_427', size: Size(427, 924), dpr: 3.0),
    _ViewportCase(name: 'phone_480', size: Size(480, 1066), dpr: 3.0),
    _ViewportCase(name: 'phone_landscape', size: Size(640, 360), dpr: 3.0),
    _ViewportCase(name: 'tablet_840', size: Size(840, 1180), dpr: 2.0),
    _ViewportCase(name: 'tablet_1024', size: Size(1024, 1366), dpr: 2.0),
    _ViewportCase(name: 'large_1366', size: Size(1366, 1024), dpr: 2.0),
  ];

  for (final item in cases) {
    tester.view.devicePixelRatio = item.dpr;
    await tester.binding.setSurfaceSize(item.size);

    final router = GoRouter(
      routes: [GoRoute(path: '/', builder: (context, state) => pageBuilder())],
    );
    Widget app = MaterialApp.router(routerConfig: router);
    if (useProviderScope) {
      app = ProviderScope(child: app);
    }

    await tester.pumpWidget(app);
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      tester.takeException(),
      isNull,
      reason:
          '$pageName threw at ${item.name} (${item.size.width}x${item.size.height}@${item.dpr})',
    );

    // Dispose current page and advance fake clock to flush page-level timers.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 9));
  }
}

class _ViewportCase {
  const _ViewportCase({
    required this.name,
    required this.size,
    required this.dpr,
  });

  final String name;
  final Size size;
  final double dpr;
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shuxiang_reading_next/features/bookshelf/presentation/bookshelf_page.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('desktop empty state follows mobile empty actions', (
    tester,
  ) async {
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
      tester.view.resetDevicePixelRatio();
    });
    tester.view.devicePixelRatio = 1;
    await tester.binding.setSurfaceSize(const Size(947, 825));
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder:
              (context, state) =>
                  const BookshelfPage(prefetchAnnouncementOnInit: false),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(find.text('导入'), findsNothing);
    expect(find.text('默认排序'), findsNothing);
    expect(find.byIcon(Icons.checklist_rounded), findsNothing);
    expect(find.text('导入本地图书'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 9));
  });
}

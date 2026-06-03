import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shuxiang_reading_next/app/composition/app_providers.dart';
import 'package:shuxiang_reading_next/data/datasources/local/app_database.dart';
import 'package:shuxiang_reading_next/features/bookshelf/application/bookshelf_service.dart';
import 'package:shuxiang_reading_next/features/bookshelf/providers.dart';
import 'package:shuxiang_reading_next/features/bookshelf/presentation/bookshelf_page.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_preferences_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('desktop empty state follows mobile empty actions', (
    tester,
  ) async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    addTearDown(() async {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = false;
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
    final prefs = await SharedPreferences.getInstance();
    final database = AppDatabase(executor: NativeDatabase.memory());
    addTearDown(database.close);
    final bookshelfService = BookshelfService(
      preferences: prefs,
      database: database,
    );
    final readerPreferencesService = ReaderPreferencesService(
      preferences: prefs,
      database: database,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(database),
          bookshelfServiceProvider.overrideWithValue(bookshelfService),
          bookshelfReaderPreferencesServiceProvider.overrideWithValue(
            readerPreferencesService,
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await _pumpUntilFound(tester, find.text('书架暂无内容'));

    expect(tester.takeException(), isNull);
    expect(find.text('导入'), findsNothing);
    expect(find.text('默认排序'), findsNothing);
    expect(find.byIcon(Icons.checklist_rounded), findsNothing);
    expect(find.text('导入本地图书'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 9));
  });
}

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 3),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 50));
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }
  await tester.pump();
}

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shuxiang_reading_next/app/composition/app_providers.dart';
import 'package:shuxiang_reading_next/data/datasources/local/app_database.dart';
import 'package:shuxiang_reading_next/domain/entities/bookshelf_book.dart';
import 'package:shuxiang_reading_next/features/bookshelf/application/bookshelf_service.dart';
import 'package:shuxiang_reading_next/features/bookshelf/providers.dart';
import 'package:shuxiang_reading_next/features/bookshelf/presentation/bookshelf_page.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_preferences_service.dart';
import 'package:shuxiang_reading_next/features/source/application/source_health_persistence_service.dart';
import 'package:shuxiang_reading_next/features/source/application/source_health_service.dart';

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
        child: MaterialApp.router(
          theme: ThemeData(platform: TargetPlatform.macOS),
          routerConfig: router,
        ),
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

  testWidgets('desktop list mode lays out bookshelf cards in one column', (
    tester,
  ) async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    addTearDown(() async {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = false;
      await tester.binding.setSurfaceSize(null);
      tester.view.resetDevicePixelRatio();
    });
    tester.view.devicePixelRatio = 1;
    await tester.binding.setSurfaceSize(const Size(1180, 820));

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
    final sourceHealthService = SourceHealthService(
      persistenceService: SourceHealthPersistenceService(
        preferences: prefs,
        database: database,
      ),
    );

    await bookshelfService.upsert(
      BookshelfBook(
        bookId: 'desktop_list_1',
        sourceId: 'src_desktop',
        title: '桌面列表一',
        detailUrl: 'https://example.com/desktop/list/1',
        addedAt: DateTime.parse('2026-06-01T12:00:00.000Z'),
        author: '作者一',
      ),
    );
    await bookshelfService.upsert(
      BookshelfBook(
        bookId: 'desktop_list_2',
        sourceId: 'src_desktop',
        title: '桌面列表二',
        detailUrl: 'https://example.com/desktop/list/2',
        addedAt: DateTime.parse('2026-06-02T12:00:00.000Z'),
        author: '作者二',
      ),
    );

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
      ProviderScope(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(database),
          appSourceHealthServiceProvider.overrideWithValue(sourceHealthService),
          bookshelfServiceProvider.overrideWithValue(bookshelfService),
          bookshelfReaderPreferencesServiceProvider.overrideWithValue(
            readerPreferencesService,
          ),
        ],
        child: MaterialApp.router(
          theme: ThemeData(platform: TargetPlatform.macOS),
          routerConfig: router,
        ),
      ),
    );
    await _pumpUntilFound(tester, find.text('桌面列表一'));

    expect(find.byType(SliverList), findsWidgets);
    expect(find.byType(SliverGrid), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 9));
  });

  testWidgets('desktop two-column list mode uses two grid columns', (
    tester,
  ) async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    addTearDown(() async {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = false;
      await tester.binding.setSurfaceSize(null);
      tester.view.resetDevicePixelRatio();
    });
    tester.view.devicePixelRatio = 1;
    await tester.binding.setSurfaceSize(const Size(1180, 820));

    final prefs = await SharedPreferences.getInstance();
    final database = AppDatabase(executor: NativeDatabase.memory());
    addTearDown(database.close);
    final bookshelfService = BookshelfService(
      preferences: prefs,
      database: database,
    );
    await bookshelfService.saveListTwoColumnMode(true);
    final readerPreferencesService = ReaderPreferencesService(
      preferences: prefs,
      database: database,
    );
    final sourceHealthService = SourceHealthService(
      persistenceService: SourceHealthPersistenceService(
        preferences: prefs,
        database: database,
      ),
    );

    await bookshelfService.upsert(
      BookshelfBook(
        bookId: 'desktop_two_column_1',
        sourceId: 'src_desktop',
        title: '桌面双列一',
        detailUrl: 'https://example.com/desktop/two-column/1',
        addedAt: DateTime.parse('2026-06-01T12:00:00.000Z'),
        author: '作者一',
      ),
    );
    await bookshelfService.upsert(
      BookshelfBook(
        bookId: 'desktop_two_column_2',
        sourceId: 'src_desktop',
        title: '桌面双列二',
        detailUrl: 'https://example.com/desktop/two-column/2',
        addedAt: DateTime.parse('2026-06-02T12:00:00.000Z'),
        author: '作者二',
      ),
    );

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
      ProviderScope(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(database),
          appSourceHealthServiceProvider.overrideWithValue(sourceHealthService),
          bookshelfServiceProvider.overrideWithValue(bookshelfService),
          bookshelfReaderPreferencesServiceProvider.overrideWithValue(
            readerPreferencesService,
          ),
        ],
        child: MaterialApp.router(
          theme: ThemeData(platform: TargetPlatform.macOS),
          routerConfig: router,
        ),
      ),
    );
    await _pumpUntilFound(tester, find.text('桌面双列一'));

    final sliverGrid = tester.widget<SliverGrid>(find.byType(SliverGrid).first);
    final gridDelegate =
        sliverGrid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(gridDelegate.crossAxisCount, 2);
    expect(tester.takeException(), isNull);

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

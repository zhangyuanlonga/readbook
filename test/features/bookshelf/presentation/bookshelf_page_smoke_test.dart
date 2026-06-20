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
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'BookshelfPage can render from database-backed bookshelf snapshot',
    (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      final database = AppDatabase(executor: NativeDatabase.memory());
      addTearDown(database.close);
      final service = BookshelfService(preferences: prefs, database: database);
      final preferencesService = ReaderPreferencesService(
        preferences: prefs,
        database: database,
      );
      final sourceHealthService = SourceHealthService(
        persistenceService: SourceHealthPersistenceService(
          preferences: prefs,
          database: database,
        ),
      );
      await service.upsert(
        BookshelfBook(
          bookId: 'book_1',
          sourceId: 'src_1',
          title: '凡人修仙传',
          detailUrl: 'https://example.com/detail/1',
          addedAt: DateTime.parse('2026-02-12T12:00:00.000Z'),
          author: '忘语',
          category: '仙侠',
        ),
      );
      expect(await database.listBookshelfBooks(), hasLength(1));

      final router = GoRouter(
        routes: <RouteBase>[
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
            appSourceHealthServiceProvider.overrideWithValue(
              sourceHealthService,
            ),
            bookshelfServiceProvider.overrideWithValue(service),
            bookshelfReaderPreferencesServiceProvider.overrideWithValue(
              preferencesService,
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await _pumpUntilFound(tester, find.text('凡人修仙传'));

      expect(tester.takeException(), isNull);
      expect(await database.listBookshelfBooks(), hasLength(1));
      expect((await database.listBookshelfBooks()).single.title, '凡人修仙传');

      await tester.tap(find.byTooltip('更多功能'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('选择书籍'));
      await tester.pumpAndSettle();

      expect(find.text('已选择 0 项'), findsOneWidget);
      expect(find.text('封面'), findsOneWidget);
      expect(find.text('删除'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 9));
    },
  );
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

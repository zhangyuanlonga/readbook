import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuxiang_reading_next/data/datasources/local/app_database.dart';
import 'package:shuxiang_reading_next/features/bookshelf/application/bookshelf_service.dart';
import 'package:shuxiang_reading_next/features/bookshelf/providers.dart';
import 'package:shuxiang_reading_next/features/bookshelf/presentation/bookshelf_page.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_preferences_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'BookshelfPage can render after legacy prefs migrate into database',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'bookshelf.books':
            '[{"bookId":"book_1","sourceId":"src_1","title":"凡人修仙传","detailUrl":"https://example.com/detail/1","addedAt":"2026-02-12T12:00:00.000Z","author":"忘语","category":"仙侠"}]',
        'bookshelf.book_tags':
            '{"src_1::https://example.com/detail/1":["在读","收藏"]}',
        'bookshelf.tag_order': '["在读","收藏"]',
        'bookshelf.category_order': '["仙侠"]',
      });
      final prefs = await SharedPreferences.getInstance();
      final database = AppDatabase(executor: NativeDatabase.memory());
      addTearDown(database.close);
      final service = BookshelfService(preferences: prefs, database: database);
      final preferencesService = ReaderPreferencesService(
        preferences: prefs,
        database: database,
      );

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
            bookshelfServiceProvider.overrideWithValue(service),
            bookshelfReaderPreferencesServiceProvider.overrideWithValue(
              preferencesService,
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(await database.listBookshelfBooks(), hasLength(1));
      expect((await database.listBookshelfBooks()).single.title, '凡人修仙传');
      expect(prefs.getString('bookshelf.books'), isNull);
      expect(prefs.getString('bookshelf.book_tags'), isNull);
    },
  );
}

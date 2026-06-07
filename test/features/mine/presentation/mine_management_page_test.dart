import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuxiang_reading_next/data/datasources/local/app_database.dart';
import 'package:shuxiang_reading_next/features/bookshelf/application/bookshelf_service.dart';
import 'package:shuxiang_reading_next/features/mine/presentation/mine_management_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase database;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    database = AppDatabase(executor: NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  testWidgets('标签管理页在空数据下可以结束加载并显示空状态', (tester) async {
    await tester.pumpWidget(
      _buildApp(
        MineManagementPage(
          section: MineManagementSection.tagManagement,
          bookshelfService: BookshelfService(database: database),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('还没有标签'), findsOneWidget);
    expect(find.text('点击右上角新增即可。'), findsOneWidget);
  });

  testWidgets('标签管理页在加载超时时显示重试提示', (tester) async {
    await tester.pumpWidget(
      _buildApp(
        MineManagementPage(
          section: MineManagementSection.tagManagement,
          bookshelfService: _HangingBookshelfService(database: database),
          loadTimeout: const Duration(milliseconds: 10),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('标签加载超时，请点击重试。'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
  });

  testWidgets('标签管理页不再显示上下移动按钮', (tester) async {
    final service = BookshelfService(database: database);
    await service.saveTagOrder(const ['在读']);

    await tester.pumpWidget(
      _buildApp(
        MineManagementPage(
          section: MineManagementSection.tagManagement,
          bookshelfService: service,
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('在读'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_upward_rounded), findsNothing);
    expect(find.byIcon(Icons.arrow_downward_rounded), findsNothing);
  });

  testWidgets('标签管理页可读取数据库中的标签顺序', (tester) async {
    final service = BookshelfService(database: database);
    await service.saveTagItems(const [
      BookshelfTaxonomyItem(name: '收藏', colorValue: 0xFF6750A4),
      BookshelfTaxonomyItem(name: '在读', colorValue: 0xFF386A20),
    ]);
    await service.saveTagOrder(const ['在读', '收藏']);

    await tester.pumpWidget(
      _buildApp(
        MineManagementPage(
          section: MineManagementSection.tagManagement,
          bookshelfService: service,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('在读'), findsOneWidget);
    expect(find.text('收藏'), findsOneWidget);
  });

  testWidgets('标签管理页在桌面端使用 dialog 方式新增标签', (tester) async {
    await tester.binding.setSurfaceSize(const Size(840, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildApp(
        MineManagementPage(
          section: MineManagementSection.tagManagement,
          bookshelfService: BookshelfService(database: database),
        ),
        platform: TargetPlatform.macOS,
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('新增标签'), findsOneWidget);
    expect(find.text('标签名称'), findsOneWidget);
  });
}

class _HangingBookshelfService extends BookshelfService {
  _HangingBookshelfService({required AppDatabase database})
    : super(database: database);

  @override
  Future<Map<String, List<String>>> getTagMap() =>
      Completer<Map<String, List<String>>>().future;

  @override
  Future<List<String>> getTagOrder() => Completer<List<String>>().future;
}

Widget _buildApp(Widget child, {TargetPlatform? platform}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => child),
      GoRoute(
        path: '/mine',
        builder: (context, state) => const SizedBox.shrink(),
      ),
    ],
  );

  return ProviderScope(
    child: MaterialApp.router(
      theme: platform == null ? null : ThemeData(platform: platform),
      routerConfig: router,
    ),
  );
}

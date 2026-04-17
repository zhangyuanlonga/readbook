import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuxiang_reading_next/features/bookshelf/application/bookshelf_service.dart';
import 'package:shuxiang_reading_next/features/mine/presentation/mine_management_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('标签管理页在空数据下可以结束加载并显示空状态', (tester) async {
    await tester.pumpWidget(
      _buildApp(
        const MineManagementPage(section: MineManagementSection.tagManagement),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('还没有标签，点击右上角新增即可。'), findsOneWidget);
  });

  testWidgets('标签管理页在加载超时时显示重试提示', (tester) async {
    await tester.pumpWidget(
      _buildApp(
        MineManagementPage(
          section: MineManagementSection.tagManagement,
          bookshelfService: _HangingBookshelfService(),
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
    final service = BookshelfService();
    await service.saveTagOrder(const ['在读']);

    await tester.pumpWidget(
      _buildApp(
        MineManagementPage(
          section: MineManagementSection.tagManagement,
          bookshelfService: service,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('在读'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_upward_rounded), findsNothing);
    expect(find.byIcon(Icons.arrow_downward_rounded), findsNothing);
  });
}

class _HangingBookshelfService extends BookshelfService {
  @override
  Future<Map<String, List<String>>> getTagMap() =>
      Completer<Map<String, List<String>>>().future;

  @override
  Future<List<String>> getTagOrder() => Completer<List<String>>().future;
}

Widget _buildApp(Widget child) {
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

  return MaterialApp.router(routerConfig: router);
}

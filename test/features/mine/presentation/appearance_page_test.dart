import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuxiang_reading_next/app/theme/app_theme_palette.dart';
import 'package:shuxiang_reading_next/app/theme/app_theme_provider.dart';
import 'package:shuxiang_reading_next/app/theme/app_theme_seed_provider.dart';
import 'package:shuxiang_reading_next/features/mine/presentation/appearance_page.dart';

import '../../../test_utils/adaptive_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets(
    'desktop appearance page keeps only mode color and advanced theme',
    (tester) async {
      await registerAdaptiveViewportTearDown(tester);
      tester.view.devicePixelRatio = 1;
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      final router = _buildAppearanceRouter(
        theme: ThemeData(platform: TargetPlatform.macOS),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            theme: ThemeData(platform: TargetPlatform.macOS),
            routerConfig: router,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('模式'), findsOneWidget);
      expect(find.text('颜色'), findsOneWidget);
      expect(find.text('高级主题'), findsOneWidget);

      expect(find.text('导航样式'), findsNothing);
      expect(find.text('底部菜单'), findsNothing);
      expect(find.text('应用界面字体'), findsNothing);
      expect(find.text('其他'), findsNothing);
    },
  );

  testWidgets('mobile appearance page keeps legacy appearance controls', (
    tester,
  ) async {
    await registerAdaptiveViewportTearDown(tester);
    tester.view.devicePixelRatio = 3;
    await tester.binding.setSurfaceSize(const Size(390, 844));
    final router = _buildAppearanceRouter(
      theme: ThemeData(platform: TargetPlatform.android),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          theme: ThemeData(platform: TargetPlatform.android),
          routerConfig: router,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('模式'), findsOneWidget);
    expect(find.text('颜色'), findsOneWidget);
    expect(find.text('高级主题'), findsOneWidget);
    expect(find.text('导航样式'), findsOneWidget);
    expect(find.text('底部菜单'), findsOneWidget);
  });

  testWidgets('desktop appearance mode and color controls update providers', (
    tester,
  ) async {
    await registerAdaptiveViewportTearDown(tester);
    tester.view.devicePixelRatio = 1;
    await tester.binding.setSurfaceSize(const Size(1280, 800));

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final router = _buildAppearanceRouter(
      theme: ThemeData(platform: TargetPlatform.macOS),
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: ThemeData(platform: TargetPlatform.macOS),
          routerConfig: router,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(container.read(appThemeModeProvider), ThemeMode.system);
    await tester.tap(find.text('夜间'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(container.read(appThemeModeProvider), ThemeMode.dark);

    expect(
      container.read(appSeedColorProvider).toARGB32(),
      const Color(0xFFFFFFFF).toARGB32(),
    );
    await tester.tap(find.byTooltip(appThemeSeaBlueOption.label));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      container.read(appSeedColorProvider).toARGB32(),
      appThemeSeaBlueOption.color.toARGB32(),
    );
  });
}

GoRouter _buildAppearanceRouter({required ThemeData theme}) {
  return GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder:
            (context, state) =>
                Theme(data: theme, child: const AppearancePage()),
      ),
    ],
  );
}

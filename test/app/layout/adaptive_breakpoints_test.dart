import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shuxiang_reading_next/app/layout/app_adaptive.dart';
import 'package:shuxiang_reading_next/app/layout/app_layout.dart';
import 'package:shuxiang_reading_next/app/layout/app_spacing.dart';
import 'package:shuxiang_reading_next/app/navigation/app_navigation_style_provider.dart';
import 'package:shuxiang_reading_next/app/shell_navigation_provider.dart';
import 'package:shuxiang_reading_next/app/shell_scaffold.dart';
import 'package:shuxiang_reading_next/app/widgets/bottom_nav_icon_view.dart';
import 'package:shuxiang_reading_next/app/widgets/cupertino_dock_navigation_bar.dart';
import 'package:shuxiang_reading_next/features/bookshelf/providers.dart';
import '../../test_utils/adaptive_test_harness.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('AppAdaptiveMetrics 按 Material 风格窗口分级划分结构断点', (tester) async {
    final compact = await _readFromContext<AppAdaptiveMetrics>(
      tester,
      width: 390,
      read: AppAdaptiveMetrics.of,
    );
    final medium = await _readFromContext<AppAdaptiveMetrics>(
      tester,
      width: 600,
      read: AppAdaptiveMetrics.of,
    );
    final expanded = await _readFromContext<AppAdaptiveMetrics>(
      tester,
      width: 840,
      read: AppAdaptiveMetrics.of,
    );
    final desktop = await _readFromContext<AppAdaptiveMetrics>(
      tester,
      width: 1200,
      read: AppAdaptiveMetrics.of,
    );

    expect(compact.windowClass, AppWindowClass.compact);
    expect(medium.windowClass, AppWindowClass.medium);
    expect(expanded.windowClass, AppWindowClass.expanded);
    expect(desktop.windowClass, AppWindowClass.expanded);
  });

  testWidgets('AppAdaptiveMetrics 将旧宽度分档兼容映射到新窗口分级', (tester) async {
    expect(
      AppAdaptiveMetrics.windowClassForBucket(AppWidthBucket.compact),
      AppWindowClass.compact,
    );
    expect(
      AppAdaptiveMetrics.windowClassForBucket(AppWidthBucket.largePhone),
      AppWindowClass.compact,
    );
    expect(
      AppAdaptiveMetrics.windowClassForBucket(AppWidthBucket.phoneXl),
      AppWindowClass.compact,
    );
    expect(
      AppAdaptiveMetrics.windowClassForBucket(AppWidthBucket.medium),
      AppWindowClass.medium,
    );
    expect(
      AppAdaptiveMetrics.windowClassForBucket(AppWidthBucket.expanded),
      AppWindowClass.expanded,
    );
  });

  testWidgets('AppAdaptiveMetrics 同时参考宽高方向和文字缩放计算密度', (tester) async {
    final smallPhone = await _readFromContext<AppAdaptiveMetrics>(
      tester,
      width: 360,
      height: 800,
      read: AppAdaptiveMetrics.of,
    );
    final regularPhone = await _readFromContext<AppAdaptiveMetrics>(
      tester,
      width: 390,
      height: 844,
      read: AppAdaptiveMetrics.of,
    );
    final scaledPhone = await _readFromContext<AppAdaptiveMetrics>(
      tester,
      width: 412,
      height: 915,
      textScaleFactor: 1.3,
      read: AppAdaptiveMetrics.of,
    );
    final landscapePhone = await _readFromContext<AppAdaptiveMetrics>(
      tester,
      width: 780,
      height: 360,
      read: AppAdaptiveMetrics.of,
    );
    final tablet = await _readFromContext<AppAdaptiveMetrics>(
      tester,
      width: 840,
      height: 1180,
      read: AppAdaptiveMetrics.of,
    );

    expect(smallPhone.density, AppDensity.compact);
    expect(regularPhone.density, AppDensity.regular);
    expect(scaledPhone.density, AppDensity.compact);
    expect(landscapePhone.density, AppDensity.compact);
    expect(tablet.density, AppDensity.comfortable);
  });

  testWidgets('AppAdaptiveMetrics 暴露页面和组件尺寸 token', (tester) async {
    final metrics360 = await _readFromContext<AppAdaptiveMetrics>(
      tester,
      width: 360,
      height: 800,
      read: AppAdaptiveMetrics.of,
    );
    final metrics390 = await _readFromContext<AppAdaptiveMetrics>(
      tester,
      width: 390,
      height: 844,
      read: AppAdaptiveMetrics.of,
    );
    final metrics600 = await _readFromContext<AppAdaptiveMetrics>(
      tester,
      width: 600,
      height: 960,
      read: AppAdaptiveMetrics.of,
    );
    final metrics840 = await _readFromContext<AppAdaptiveMetrics>(
      tester,
      width: 840,
      height: 1180,
      read: AppAdaptiveMetrics.of,
    );
    final metrics1200 = await _readFromContext<AppAdaptiveMetrics>(
      tester,
      width: 1200,
      height: 900,
      read: AppAdaptiveMetrics.of,
    );

    expect(metrics360.pagePadding, 12);
    expect(metrics390.pagePadding, 16);
    expect(metrics600.pagePadding, 20);
    expect(metrics840.pagePadding, 24);
    expect(metrics1200.pagePadding, 24);
    expect(metrics360.controlHeight, 36);
    expect(metrics360.minTouchTargetSize, 44);
    expect(metrics390.controlHeight, 40);
    expect(metrics840.controlHeight, 44);
    expect(metrics840.dialogMaxWidth, 560);
    expect(metrics1200.bottomSheetMaxWidth, 720);
  });

  testWidgets('AppAdaptiveMetrics 支持按当前容器约束重新计算', (tester) async {
    final metrics = await _readFromContext<AppAdaptiveMetrics>(
      tester,
      width: 840,
      height: 1180,
      read:
          (context) => AppAdaptiveMetrics.resolveForConstraints(
            context,
            const BoxConstraints(maxWidth: 390, maxHeight: 640),
          ),
    );

    expect(metrics.width, 390);
    expect(metrics.windowClass, AppWindowClass.compact);
    expect(metrics.density, AppDensity.regular);
  });

  testWidgets('AppAdaptiveMetrics gridColumnsFor 按最小 item 宽度计算列数', (
    tester,
  ) async {
    final metrics = await _readFromContext<AppAdaptiveMetrics>(
      tester,
      width: 412,
      read: AppAdaptiveMetrics.of,
    );

    expect(metrics.gridColumnsFor(minColumns: 2, maxColumns: 6), 3);
    expect(
      metrics.gridColumnsFor(
        availableWidth: 600,
        minItemWidth: 124,
        minColumns: 2,
        maxColumns: 6,
        spacing: 8,
      ),
      4,
    );
  });

  testWidgets('AppSpacing 在 360、390、430 宽度下使用正确的间距', (tester) async {
    final spacing360 = await _readFromContext<double>(
      tester,
      width: 360,
      read: AppSpacing.pageHorizontal,
    );
    final spacing390 = await _readFromContext<double>(
      tester,
      width: 390,
      read: AppSpacing.pageHorizontal,
    );
    final spacing430 = await _readFromContext<double>(
      tester,
      width: 430,
      read: AppSpacing.pageHorizontal,
    );

    expect(spacing360, 12);
    expect(spacing390, 16);
    expect(spacing430, 16);
  });

  testWidgets('AppLayout 能正确识别常见手机宽度', (tester) async {
    final flags360 = await _readFromContext<_LayoutFlags>(
      tester,
      width: 360,
      read:
          (context) => _LayoutFlags(
            isPhoneSmall: AppLayout.isPhoneSmall(context),
            isPhoneLarge: AppLayout.isPhoneLarge(context),
            isPhone: AppLayout.isPhone(context),
          ),
    );
    final flags390 = await _readFromContext<_LayoutFlags>(
      tester,
      width: 390,
      read:
          (context) => _LayoutFlags(
            isPhoneSmall: AppLayout.isPhoneSmall(context),
            isPhoneLarge: AppLayout.isPhoneLarge(context),
            isPhone: AppLayout.isPhone(context),
          ),
    );
    final flags430 = await _readFromContext<_LayoutFlags>(
      tester,
      width: 430,
      read:
          (context) => _LayoutFlags(
            isPhoneSmall: AppLayout.isPhoneSmall(context),
            isPhoneLarge: AppLayout.isPhoneLarge(context),
            isPhone: AppLayout.isPhone(context),
          ),
    );

    expect(flags360.isPhoneSmall, isTrue);
    expect(flags360.isPhoneLarge, isFalse);
    expect(flags360.isPhone, isTrue);

    expect(flags390.isPhoneSmall, isFalse);
    expect(flags390.isPhoneLarge, isTrue);
    expect(flags390.isPhone, isTrue);

    expect(flags430.isPhoneSmall, isFalse);
    expect(flags430.isPhoneLarge, isTrue);
    expect(flags430.isPhone, isTrue);
  });

  testWidgets('AppLayout 按语义化断点划分宽度分档', (tester) async {
    final bucket320 = await _readFromContext<AppWidthBucket>(
      tester,
      width: 320,
      read: AppLayout.widthBucket,
    );
    final bucket360 = await _readFromContext<AppWidthBucket>(
      tester,
      width: 360,
      read: AppLayout.widthBucket,
    );
    final bucket390 = await _readFromContext<AppWidthBucket>(
      tester,
      width: 390,
      read: AppLayout.widthBucket,
    );
    final bucket480 = await _readFromContext<AppWidthBucket>(
      tester,
      width: 480,
      read: AppLayout.widthBucket,
    );
    final bucket600 = await _readFromContext<AppWidthBucket>(
      tester,
      width: 600,
      read: AppLayout.widthBucket,
    );
    final bucket840 = await _readFromContext<AppWidthBucket>(
      tester,
      width: 840,
      read: AppLayout.widthBucket,
    );

    expect(bucket320, AppWidthBucket.compact);
    expect(bucket360, AppWidthBucket.compact);
    expect(bucket390, AppWidthBucket.largePhone);
    expect(bucket480, AppWidthBucket.phoneXl);
    expect(bucket600, AppWidthBucket.medium);
    expect(bucket840, AppWidthBucket.expanded);
  });

  testWidgets('AppLayout 按桌面宽屏断点划分桌面宽度等级', (tester) async {
    expect(AppLayout.desktopWidthClassFor(1199), AppDesktopWidthClass.desktop);
    expect(
      AppLayout.desktopWidthClassFor(1600),
      AppDesktopWidthClass.wideDesktop,
    );
    expect(
      AppLayout.desktopWidthClassFor(1920),
      AppDesktopWidthClass.ultraWideDesktop,
    );

    final metrics = AppAdaptiveMetrics.resolveForSize(
      size: const Size(1920, 1080),
    );
    expect(metrics.desktopWidthClass, AppDesktopWidthClass.ultraWideDesktop);
    expect(metrics.isWideDesktopWindow, isTrue);
    expect(metrics.isUltraWideDesktopWindow, isTrue);
  });

  testWidgets('AppLayout pageContentMaxWidth 在手机上保持原宽，在中大屏按可用宽度限宽', (
    tester,
  ) async {
    final width390 = await _readFromContext<double>(
      tester,
      width: 390,
      read:
          (context) => AppLayout.pageContentMaxWidth(
            context,
            maxWidth: AppLayout.mineContentMaxWidth,
          ),
    );
    final width600 = await _readFromContext<double>(
      tester,
      width: 600,
      read:
          (context) => AppLayout.pageContentMaxWidth(
            context,
            maxWidth: AppLayout.mineContentMaxWidth,
          ),
    );
    final width720 = await _readFromContext<double>(
      tester,
      width: 720,
      read:
          (context) => AppLayout.pageContentMaxWidth(
            context,
            maxWidth: AppLayout.mineContentMaxWidth,
          ),
    );
    final width1200 = await _readFromContext<double>(
      tester,
      width: 1200,
      read:
          (context) => AppLayout.pageContentMaxWidth(
            context,
            maxWidth: AppLayout.mineContentMaxWidth,
          ),
    );

    expect(width390, 390);
    expect(width600, 600);
    expect(width720, 720);
    expect(width1200, AppLayout.mineContentMaxWidth);
  });

  testWidgets('AppLayout aboutPageContentMaxWidth 遵循两段式限宽', (tester) async {
    final width500 = await _readFromContext<double>(
      tester,
      width: 500,
      read: AppLayout.aboutPageContentMaxWidth,
    );
    final width700 = await _readFromContext<double>(
      tester,
      width: 700,
      read: AppLayout.aboutPageContentMaxWidth,
    );
    final width980 = await _readFromContext<double>(
      tester,
      width: 980,
      read: AppLayout.aboutPageContentMaxWidth,
    );
    final width1300 = await _readFromContext<double>(
      tester,
      width: 1300,
      read: AppLayout.aboutPageContentMaxWidth,
    );

    expect(width500, 500);
    expect(width700, 700);
    expect(width980, AppLayout.aboutContentMaxWidth);
    expect(width1300, AppLayout.aboutExpandedContentMaxWidth);
  });

  testWidgets('AppLayout optionGridColumnsForWidth 与宽度分档一致', (tester) async {
    final columns320 = await _readFromContext<int>(
      tester,
      width: 320,
      read: (context) => AppLayout.optionGridColumnsForWidth(320),
    );
    final columns390 = await _readFromContext<int>(
      tester,
      width: 390,
      read: (context) => AppLayout.optionGridColumnsForWidth(390),
    );
    final columns600 = await _readFromContext<int>(
      tester,
      width: 600,
      read: (context) => AppLayout.optionGridColumnsForWidth(600),
    );

    expect(columns320, 1);
    expect(columns390, 2);
    expect(columns600, 3);
  });

  testWidgets('AppLayout mineActionGridColumnsForWidth 遵循现行手机/中屏/桌面列数规则', (
    tester,
  ) async {
    final columns320 = await _readFromContext<int>(
      tester,
      width: 320,
      read: (context) => AppLayout.mineActionGridColumnsForWidth(320),
    );
    final columns360 = await _readFromContext<int>(
      tester,
      width: 360,
      read: (context) => AppLayout.mineActionGridColumnsForWidth(360),
    );
    final columns390 = await _readFromContext<int>(
      tester,
      width: 390,
      read: (context) => AppLayout.mineActionGridColumnsForWidth(390),
    );
    final columns430 = await _readFromContext<int>(
      tester,
      width: 430,
      read: (context) => AppLayout.mineActionGridColumnsForWidth(430),
    );
    final columns600 = await _readFromContext<int>(
      tester,
      width: 600,
      read: (context) => AppLayout.mineActionGridColumnsForWidth(600),
    );
    final columns900 = await _readFromContext<int>(
      tester,
      width: 900,
      read: (context) => AppLayout.mineActionGridColumnsForWidth(900),
    );

    expect(columns320, 4);
    expect(columns360, 4);
    expect(columns390, 4);
    expect(columns430, 4);
    expect(columns600, 3);
    expect(columns900, 4);
  });

  testWidgets('AppLayout 将 390dp 以下视为小屏手机', (tester) async {
    final small375 = await _readFromContext<bool>(
      tester,
      width: 375,
      read: (context) => AppLayout.isPhoneSmallWidthFor(375),
    );
    final small390 = await _readFromContext<bool>(
      tester,
      width: 390,
      read: (context) => AppLayout.isPhoneSmallWidthFor(390),
    );

    expect(small375, isTrue);
    expect(small390, isFalse);
  });

  testWidgets('AppLayout readingRecordsMetricColumnsForWidth 随宽度分档变化', (
    tester,
  ) async {
    final columns390 = await _readFromContext<int>(
      tester,
      width: 390,
      read: (context) => AppLayout.readingRecordsMetricColumnsForWidth(390),
    );
    final columns600 = await _readFromContext<int>(
      tester,
      width: 600,
      read: (context) => AppLayout.readingRecordsMetricColumnsForWidth(600),
    );

    expect(columns390, 2);
    expect(columns600, 3);
  });

  testWidgets('AppLayout useCondensedPhoneDensityForWidth 只在大号手机区间启用', (
    tester,
  ) async {
    final dense390 = await _readFromContext<bool>(
      tester,
      width: 390,
      read: (context) => AppLayout.useCondensedPhoneDensityForWidth(390),
    );
    final dense430 = await _readFromContext<bool>(
      tester,
      width: 430,
      read: (context) => AppLayout.useCondensedPhoneDensityForWidth(430),
    );
    final dense480 = await _readFromContext<bool>(
      tester,
      width: 480,
      read: (context) => AppLayout.useCondensedPhoneDensityForWidth(480),
    );
    final dense600 = await _readFromContext<bool>(
      tester,
      width: 600,
      read: (context) => AppLayout.useCondensedPhoneDensityForWidth(600),
    );

    expect(dense390, isTrue);
    expect(dense430, isTrue);
    expect(dense480, isTrue);
    expect(dense600, isFalse);
  });

  testWidgets('AppLayout bookshelfGridColumnsForWidth 按宽度阈值切换列数', (
    tester,
  ) async {
    final columns389 = await _readFromContext<int>(
      tester,
      width: 389,
      read: (context) => AppLayout.bookshelfGridColumnsForWidth(389),
    );
    final columns320 = await _readFromContext<int>(
      tester,
      width: 320,
      read: (context) => AppLayout.bookshelfGridColumnsForWidth(320),
    );
    final columns799 = await _readFromContext<int>(
      tester,
      width: 799,
      read: (context) => AppLayout.bookshelfGridColumnsForWidth(799),
    );
    final columns800 = await _readFromContext<int>(
      tester,
      width: 800,
      read: (context) => AppLayout.bookshelfGridColumnsForWidth(800),
    );
    final columns1100 = await _readFromContext<int>(
      tester,
      width: 1100,
      read: (context) => AppLayout.bookshelfGridColumnsForWidth(1100),
    );
    final columns1400 = await _readFromContext<int>(
      tester,
      width: 1400,
      read: (context) => AppLayout.bookshelfGridColumnsForWidth(1400),
    );

    expect(columns389, 3);
    expect(columns320, 3);
    expect(columns799, 3);
    expect(columns800, 4);
    expect(columns1100, 5);
    expect(columns1400, 6);
  });

  testWidgets('AppLayout sheetHeightFactor 按小屏、常规和大号手机切换', (tester) async {
    final compact = await _readFromContext<double>(
      tester,
      width: 320,
      read:
          (context) => AppLayout.sheetHeightFactor(
            context,
            compact: 0.92,
            regular: 0.9,
            large: 0.85,
          ),
    );
    final regular = await _readFromContext<double>(
      tester,
      width: 390,
      read:
          (context) => AppLayout.sheetHeightFactor(
            context,
            compact: 0.92,
            regular: 0.9,
            large: 0.85,
          ),
    );
    final large = await _readFromContext<double>(
      tester,
      width: 430,
      read:
          (context) => AppLayout.sheetHeightFactor(
            context,
            compact: 0.92,
            regular: 0.9,
            large: 0.85,
          ),
    );
    final compact360 = await _readFromContext<double>(
      tester,
      width: 360,
      read:
          (context) => AppLayout.sheetHeightFactor(
            context,
            compact: 0.92,
            regular: 0.9,
            large: 0.85,
          ),
    );

    expect(compact, 0.92);
    expect(compact360, 0.92);
    expect(regular, 0.85);
    expect(large, 0.85);
  });

  testWidgets('AppLayout clamps text scale 使用全局界面缩放上下限', (tester) async {
    final smallScale = await _readFromContext<double>(
      tester,
      width: 390,
      textScaleFactor: 0.4,
      read: AppLayout.clampedTextScaleFactor,
    );
    final phoneScale = await _readFromContext<double>(
      tester,
      width: 390,
      textScaleFactor: 1.5,
      read: AppLayout.clampedTextScaleFactor,
    );
    final tabletScale = await _readFromContext<double>(
      tester,
      width: 840,
      textScaleFactor: 1.5,
      read: AppLayout.clampedTextScaleFactor,
    );

    expect(smallScale, 0.6);
    expect(phoneScale, 1.5);
    expect(tabletScale, 1.5);
  });

  testWidgets('ShellScaffold 在手机宽度下保留底部导航栏', (tester) async {
    for (final width in <double>[360, 390, 430]) {
      await _pumpShellScaffold(tester, width: width);

      expect(
        find.byType(NavigationBar),
        findsOneWidget,
        reason: 'expected bottom bar at width=$width',
      );
      expect(
        find.byType(NavigationRail),
        findsNothing,
        reason: 'did not expect rail at width=$width',
      );
    }
  });

  testWidgets('ShellScaffold body 在任务队列为空时仍铺满页面', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    Size? bodySize;

    await tester.pumpWidget(
      AdaptiveTestHarness(
        width: 390,
        height: 844,
        wrapWithMaterialApp: true,
        child: ShellScaffold(
          location: '/bookshelf',
          child: LayoutBuilder(
            builder: (context, constraints) {
              bodySize = constraints.biggest;
              return const ColoredBox(color: Colors.white);
            },
          ),
        ),
      ),
    );
    await tester.pump();

    expect(bodySize, isNotNull);
    expect(bodySize!.width, 390);
    expect(bodySize!.height, 844);
  });

  testWidgets('ShellScaffold 到达平板断点后切换为侧边栏', (tester) async {
    await _pumpShellScaffold(tester, width: AppLayout.railBreakpointWidth);

    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byKey(const ValueKey('desktop_shell_sidebar')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('desktop_shell_sidebar'))).width,
      216,
    );
    expect(find.text('Selune'), findsOneWidget);
    expect(find.text('书架'), findsOneWidget);
  });

  testWidgets('ShellScaffold 桌面顶部栏显示轻量账号入口', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'auth.user_id': 'desktop_user',
      'auth.username': 'desktop_reader',
      'auth.display_name': 'Desktop Reader',
    });

    await _pumpShellScaffold(tester, width: 1280);
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('desktop_top_bar_notification_button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('desktop_top_bar_settings_button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('desktop_top_bar_account_entry')),
      findsOneWidget,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('desktop_shell_sidebar'))).width,
      244,
    );
    expect(
      find.byKey(const ValueKey<String>('desktop_shell_logout_entry')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('desktop_shell_user_card')),
      findsNothing,
    );
    expect(find.text('Desktop Reader'), findsWidgets);

    await tester.tap(
      find.byKey(const ValueKey<String>('desktop_top_bar_account_entry')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('desktop_account_menu_header')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('desktop_account_menu_profile')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('desktop_account_menu_settings')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('desktop_account_menu_logout')),
      findsOneWidget,
    );
    expect(find.text('个人信息'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
  });

  testWidgets('ShellScaffold 桌面顶部栏未登录时显示登录入口', (tester) async {
    await _pumpShellScaffold(tester, width: 1280);
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('desktop_top_bar_account_entry')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('desktop_shell_logout_entry')),
      findsNothing,
    );
    expect(find.text('登录'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('desktop_top_bar_account_entry')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('desktop_account_menu_login')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('desktop_account_menu_settings')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('desktop_account_menu_profile')),
      findsNothing,
    );
    expect(find.text('登录账号'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
  });

  testWidgets('ShellScaffold 桌面书架显示状态侧栏和视图下拉', (tester) async {
    var selectedStatus = '';
    final actions = DesktopBookshelfLibraryActions(
      activeLabel: '全部',
      statusActions: [
        DesktopBookshelfLibraryStatusAction(
          label: '全部',
          count: 5,
          selected: true,
          icon: Icons.library_books_outlined,
          onSelected: () => selectedStatus = 'all',
        ),
        DesktopBookshelfLibraryStatusAction(
          label: '待读清单',
          count: 0,
          selected: false,
          icon: Icons.playlist_add_check_rounded,
          onSelected: () => selectedStatus = 'todo',
        ),
        DesktopBookshelfLibraryStatusAction(
          label: '未读',
          count: 2,
          selected: false,
          icon: Icons.markunread_outlined,
          onSelected: () => selectedStatus = 'unread',
        ),
        DesktopBookshelfLibraryStatusAction(
          label: '阅读中',
          count: 3,
          selected: false,
          icon: Icons.menu_book_outlined,
          onSelected: () => selectedStatus = 'reading',
        ),
        DesktopBookshelfLibraryStatusAction(
          label: '已读完',
          count: 1,
          selected: false,
          icon: Icons.task_alt_rounded,
          onSelected: () => selectedStatus = 'finished',
        ),
      ],
    );

    await tester.pumpWidget(
      AdaptiveTestHarness(
        width: 1280,
        wrapWithMaterialApp: true,
        overrides: [
          desktopBookshelfLibraryActionsProvider.overrideWith((ref) => actions),
        ],
        child: const ShellScaffold(location: '/bookshelf', child: SizedBox()),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('desktop_bookshelf_view_selector')),
      findsOneWidget,
    );
    expect(find.text('我的书架'), findsOneWidget);
    expect(find.text('待读清单'), findsOneWidget);
    expect(find.text('未读'), findsOneWidget);
    expect(find.text('阅读中'), findsOneWidget);
    expect(find.text('已读完'), findsOneWidget);

    await tester.tap(find.text('阅读中'));
    expect(selectedStatus, 'reading');
  });

  testWidgets('ShellScaffold 底部导航保持统计页位于我的之前', (tester) async {
    await tester.pumpWidget(
      AdaptiveTestHarness(
        width: 390,
        wrapWithMaterialApp: true,
        overrides: [
          appShellNavigationProvider.overrideWith(
            _AllTabsNavigationNotifier.new,
          ),
        ],
        child: ShellScaffold(location: '/discover', child: SizedBox()),
      ),
    );
    await tester.pump();

    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    final labels = bar.destinations
        .map((item) => (item as NavigationDestination).label)
        .toList(growable: false);

    expect(labels, <String>['书架', '发现', '统计', '我的']);
    expect(bar.selectedIndex, 1);
  });

  testWidgets('ShellScaffold 标准底部导航为选中态提供独立图标', (tester) async {
    await tester.pumpWidget(
      AdaptiveTestHarness(
        width: 390,
        wrapWithMaterialApp: true,
        overrides: [
          appShellNavigationProvider.overrideWith(
            _AllTabsNavigationNotifier.new,
          ),
        ],
        child: const ShellScaffold(location: '/bookshelf', child: SizedBox()),
      ),
    );
    await tester.pump();

    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    final destinations = bar.destinations.cast<NavigationDestination>().toList(
      growable: false,
    );

    expect(
      (destinations[0].icon as BottomNavIconView).icon.fallbackIcon,
      Icons.library_books_outlined,
    );
    expect(
      (destinations[0].selectedIcon as BottomNavIconView).icon.fallbackIcon,
      Icons.library_books_rounded,
    );
    expect(
      (destinations[1].icon as BottomNavIconView).icon.fallbackIcon,
      Icons.explore_outlined,
    );
    expect(
      (destinations[1].selectedIcon as BottomNavIconView).icon.fallbackIcon,
      Icons.explore,
    );
    expect(
      (destinations[2].icon as BottomNavIconView).icon.fallbackIcon,
      Icons.insert_chart_outlined_rounded,
    );
    expect(
      (destinations[2].selectedIcon as BottomNavIconView).icon.fallbackIcon,
      Icons.insert_chart_rounded,
    );
    expect(
      (destinations[3].icon as BottomNavIconView).icon.fallbackIcon,
      Icons.person_outline,
    );
    expect(
      (destinations[3].selectedIcon as BottomNavIconView).icon.fallbackIcon,
      Icons.person,
    );
  });

  testWidgets('ShellScaffold 标准底部导航会响应文字显示开关', (tester) async {
    await tester.pumpWidget(
      AdaptiveTestHarness(
        width: 390,
        wrapWithMaterialApp: true,
        overrides: [
          appNavigationLabelVisibilityProvider.overrideWith(
            _HiddenNavigationLabelsNotifier.new,
          ),
        ],
        child: const ShellScaffold(location: '/bookshelf', child: SizedBox()),
      ),
    );
    await tester.pump();

    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.labelBehavior, NavigationDestinationLabelBehavior.alwaysHide);
  });

  testWidgets('ShellScaffold 会隐藏被禁用的导航项', (tester) async {
    await tester.pumpWidget(
      AdaptiveTestHarness(
        width: 390,
        wrapWithMaterialApp: true,
        overrides: [
          appShellNavigationProvider.overrideWith(
            _BookshelfMineNavigationNotifier.new,
          ),
        ],
        child: const ShellScaffold(location: '/bookshelf', child: SizedBox()),
      ),
    );
    await tester.pump();

    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    final labels = bar.destinations
        .map((item) => (item as NavigationDestination).label)
        .toList(growable: false);

    expect(labels, <String>['书架', '我的']);
    expect(bar.selectedIndex, 0);
  });

  testWidgets('ShellScaffold 在 iOS 跟随系统时默认使用标准底栏', (tester) async {
    await tester.pumpWidget(
      AdaptiveTestHarness(
        width: 390,
        wrapWithMaterialApp: true,
        child: Theme(
          data: ThemeData(platform: TargetPlatform.iOS),
          child: const ShellScaffold(location: '/bookshelf', child: SizedBox()),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(CupertinoDockNavigationBar), findsNothing);
  });

  testWidgets('ShellScaffold 在 iOS 手动选择苹果风格时使用 Cupertino dock', (tester) async {
    await tester.pumpWidget(
      AdaptiveTestHarness(
        width: 390,
        wrapWithMaterialApp: true,
        overrides: [
          appNavigationStylePreferenceProvider.overrideWith(
            _CupertinoDockNavigationStyleNotifier.new,
          ),
        ],
        child: Theme(
          data: ThemeData(platform: TargetPlatform.iOS),
          child: const ShellScaffold(location: '/bookshelf', child: SizedBox()),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(CupertinoDockNavigationBar), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('ShellScaffold 在平板宽度下忽略苹果风格设置并继续使用侧边栏', (tester) async {
    await tester.pumpWidget(
      AdaptiveTestHarness(
        width: AppLayout.railBreakpointWidth,
        wrapWithMaterialApp: true,
        overrides: [
          appNavigationStylePreferenceProvider.overrideWith(
            _CupertinoDockNavigationStyleNotifier.new,
          ),
        ],
        child: const ShellScaffold(location: '/bookshelf', child: SizedBox()),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('desktop_shell_sidebar')), findsOneWidget);
    expect(find.byType(CupertinoDockNavigationBar), findsNothing);
    expect(find.byType(NavigationBar), findsNothing);
  });
}

Future<void> _pumpShellScaffold(
  WidgetTester tester, {
  required double width,
}) async {
  await tester.pumpWidget(
    AdaptiveTestHarness(
      width: width,
      wrapWithMaterialApp: true,
      child: const ShellScaffold(location: '/bookshelf', child: SizedBox()),
    ),
  );
  await tester.pump();
}

Future<T> _readFromContext<T>(
  WidgetTester tester, {
  required double width,
  double height = 844,
  double textScaleFactor = 1,
  required T Function(BuildContext context) read,
}) async {
  T? result;

  await tester.pumpWidget(
    AdaptiveTestHarness(
      width: width,
      height: height,
      textScaleFactor: textScaleFactor,
      wrapWithMaterialApp: true,
      child: Builder(
        builder: (context) {
          result = read(context);
          return const SizedBox();
        },
      ),
    ),
  );
  await tester.pump();

  return result as T;
}

class _BookshelfMineNavigationNotifier extends AppShellNavigationNotifier {
  @override
  AppShellNavigationState build() {
    return const AppShellNavigationState(
      showBookshelf: true,
      showDiscover: false,
      showStats: false,
    );
  }
}

class _CupertinoDockNavigationStyleNotifier
    extends AppNavigationStylePreferenceNotifier {
  @override
  AppNavigationStylePreference build() {
    return AppNavigationStylePreference.cupertinoDock;
  }
}

class _HiddenNavigationLabelsNotifier
    extends AppNavigationLabelVisibilityNotifier {
  @override
  bool build() {
    return false;
  }
}

class _AllTabsNavigationNotifier extends AppShellNavigationNotifier {
  @override
  AppShellNavigationState build() {
    return const AppShellNavigationState(
      showBookshelf: true,
      showDiscover: true,
      showStats: true,
    );
  }
}

class _LayoutFlags {
  const _LayoutFlags({
    required this.isPhoneSmall,
    required this.isPhoneLarge,
    required this.isPhone,
  });

  final bool isPhoneSmall;
  final bool isPhoneLarge;
  final bool isPhone;
}

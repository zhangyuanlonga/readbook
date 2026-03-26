import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_appread/app/layout/app_layout.dart';
import 'package:flutter_appread/app/layout/app_spacing.dart';
import 'package:flutter_appread/app/shell_navigation_provider.dart';
import 'package:flutter_appread/app/shell_scaffold.dart';

void main() {
  testWidgets('AppSpacing uses expected width buckets at 360/390/430', (
    tester,
  ) async {
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

  testWidgets('AppLayout classifies common phone widths correctly', (
    tester,
  ) async {
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
    expect(flags390.isPhoneLarge, isFalse);
    expect(flags390.isPhone, isTrue);

    expect(flags430.isPhoneSmall, isFalse);
    expect(flags430.isPhoneLarge, isTrue);
    expect(flags430.isPhone, isTrue);
  });

  testWidgets('AppLayout width bucket uses semantic breakpoints', (
    tester,
  ) async {
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

  testWidgets(
    'AppLayout pageContentMaxWidth keeps phone width and caps medium+',
    (tester) async {
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

      expect(width390, 390);
      expect(width600, 600);
      expect(width720, AppLayout.mineContentMaxWidth);
    },
  );

  testWidgets('AppLayout aboutPageContentMaxWidth follows two-stage caps', (
    tester,
  ) async {
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

  testWidgets('AppLayout optionGridColumnsForWidth matches width buckets', (
    tester,
  ) async {
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

  testWidgets('AppLayout mineActionGridColumnsForWidth follows rule', (
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

    expect(columns320, 2);
    expect(columns360, 2);
    expect(columns390, 4);
    expect(columns430, 4);
    expect(columns600, 4);
  });

  testWidgets('AppLayout treats widths up to 360dp as small phones', (
    tester,
  ) async {
    final small360 = await _readFromContext<bool>(
      tester,
      width: 360,
      read: (context) => AppLayout.isPhoneSmallWidthFor(360),
    );
    final small361 = await _readFromContext<bool>(
      tester,
      width: 361,
      read: (context) => AppLayout.isPhoneSmallWidthFor(361),
    );

    expect(small360, isTrue);
    expect(small361, isFalse);
  });

  testWidgets('AppLayout readingRecordsMetricColumnsForWidth follows buckets', (
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

  testWidgets(
    'AppLayout useCondensedPhoneDensityForWidth only enables on large phones',
    (tester) async {
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

      expect(dense390, isFalse);
      expect(dense430, isTrue);
      expect(dense480, isTrue);
      expect(dense600, isFalse);
    },
  );

  testWidgets('AppLayout bookshelfGridColumnsForWidth uses width thresholds', (
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

  testWidgets('AppLayout sheetHeightFactor follows compact/regular/large', (
    tester,
  ) async {
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
    expect(regular, 0.9);
    expect(large, 0.85);
  });

  testWidgets(
    'AppLayout clamps text scale with relaxed phone and tablet caps',
    (tester) async {
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

      expect(phoneScale, 1.24);
      expect(tabletScale, 1.3);
    },
  );

  testWidgets('ShellScaffold keeps bottom bar on narrow phone widths', (
    tester,
  ) async {
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

  testWidgets('ShellScaffold switches to rail at and above breakpoint', (
    tester,
  ) async {
    await _pumpShellScaffold(tester, width: AppLayout.railBreakpointWidth);

    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(NavigationRail), findsOneWidget);
  });

  testWidgets('ShellScaffold bottom navigation keeps discover between tabs', (
    tester,
  ) async {
    await tester.pumpWidget(
      _TestHarness(
        width: 390,
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

    expect(labels, <String>['书架', '发现', '我的']);
    expect(bar.selectedIndex, 1);
  });

  testWidgets('ShellScaffold hides disabled destinations', (tester) async {
    await tester.pumpWidget(
      _TestHarness(
        width: 390,
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
}

Future<void> _pumpShellScaffold(
  WidgetTester tester, {
  required double width,
}) async {
  await tester.pumpWidget(
    _TestHarness(
      width: width,
      child: const ShellScaffold(location: '/bookshelf', child: SizedBox()),
    ),
  );
  await tester.pump();
}

Future<T> _readFromContext<T>(
  WidgetTester tester, {
  required double width,
  double textScaleFactor = 1,
  required T Function(BuildContext context) read,
}) async {
  T? result;

  await tester.pumpWidget(
    _TestHarness(
      width: width,
      textScaleFactor: textScaleFactor,
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

class _TestHarness extends StatelessWidget {
  const _TestHarness({
    required this.width,
    required this.child,
    this.textScaleFactor = 1,
    this.overrides = const [],
  });

  final double width;
  final Widget child;
  final double textScaleFactor;
  final List<Override> overrides;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: overrides,
      child: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 844),
          textScaler: TextScaler.linear(textScaleFactor),
        ),
        child: MaterialApp(home: child),
      ),
    );
  }
}

class _BookshelfMineNavigationNotifier extends AppShellNavigationNotifier {
  @override
  AppShellNavigationState build() {
    return const AppShellNavigationState(
      showBookshelf: true,
      showDiscover: false,
    );
  }
}

class _AllTabsNavigationNotifier extends AppShellNavigationNotifier {
  @override
  AppShellNavigationState build() {
    return const AppShellNavigationState(
      showBookshelf: true,
      showDiscover: true,
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

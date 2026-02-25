import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_appread/app/layout/app_layout.dart';
import 'package:flutter_appread/app/layout/app_spacing.dart';
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

    expect(spacing360, 16);
    expect(spacing390, 16);
    expect(spacing430, 20);
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

    expect(flags360.isPhoneSmall, isFalse);
    expect(flags360.isPhoneLarge, isFalse);
    expect(flags360.isPhone, isTrue);

    expect(flags390.isPhoneSmall, isFalse);
    expect(flags390.isPhoneLarge, isFalse);
    expect(flags390.isPhone, isTrue);

    expect(flags430.isPhoneSmall, isFalse);
    expect(flags430.isPhoneLarge, isTrue);
    expect(flags430.isPhone, isTrue);
  });

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
      const _TestHarness(
        width: 390,
        child: ShellScaffold(location: '/discover', child: SizedBox()),
      ),
    );
    await tester.pump();

    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    final labels = bar.destinations
        .map((item) => (item as NavigationDestination).label)
        .toList(growable: false);

    expect(labels, <String>['书架', '发现', '书源', '我的']);
    expect(bar.selectedIndex, 1);
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
  required T Function(BuildContext context) read,
}) async {
  T? result;

  await tester.pumpWidget(
    _TestHarness(
      width: width,
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
  const _TestHarness({required this.width, required this.child});

  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQueryData(size: Size(width, 844)),
      child: MaterialApp(home: child),
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

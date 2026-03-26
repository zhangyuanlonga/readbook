import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_appread/app/layout/app_layout.dart';
import 'package:flutter_appread/app/shell_scaffold.dart';
import 'package:flutter_appread/features/book/presentation/widgets/book_detail_primary_actions.dart';

void main() {
  const widths = <double>[320, 360, 390, 430, 480, 600, 840, 1024];

  testWidgets('matrix: sheetHeightFactor on target widths', (tester) async {
    for (final width in widths) {
      final factor = await _readFromContext<double>(
        tester,
        width: width,
        read:
            (context) => AppLayout.sheetHeightFactor(
              context,
              compact: 0.92,
              regular: 0.9,
              large: 0.85,
            ),
      );

      final expected =
          AppLayout.isPhoneSmallWidthFor(width)
              ? 0.92
              : width >= AppLayout.phoneLargeWidth
              ? 0.85
              : 0.9;
      expect(
        factor,
        expected,
        reason: 'unexpected sheet factor at width=$width',
      );
    }
  });

  testWidgets('matrix: detail actions use full copy and icons from 320+', (
    tester,
  ) async {
    for (final width in widths) {
      await _pumpPrimaryActions(tester, width: width);

      expect(
        find.text('开始阅读'),
        findsOneWidget,
        reason: 'expected full read label at width=$width',
      );
      expect(
        find.text('加入书架'),
        findsOneWidget,
        reason: 'expected full shelf label at width=$width',
      );
      expect(
        find.byIcon(Icons.chrome_reader_mode_outlined),
        findsOneWidget,
        reason: 'expected read icon at width=$width',
      );
      expect(
        find.byIcon(Icons.bookmark_add_outlined),
        findsOneWidget,
        reason: 'expected shelf icon at width=$width',
      );
    }
  });

  test('matrix: bookshelf columns on target widths', () {
    final expected = <double, int>{
      320: 3,
      360: 3,
      390: 3,
      430: 3,
      480: 3,
      600: 3,
      840: 4,
      1024: 4,
    };

    for (final entry in expected.entries) {
      final columns = AppLayout.bookshelfGridColumnsForWidth(entry.key);
      expect(
        columns,
        entry.value,
        reason: 'unexpected grid columns at width=${entry.key}',
      );
    }
  });

  testWidgets('matrix: shell scaffold smoke test on phone and tablet sizes', (
    tester,
  ) async {
    const cases = <_ViewportCase>[
      _ViewportCase(name: 'phone_360', size: Size(360, 800), dpr: 3.0),
      _ViewportCase(name: 'phone_390', size: Size(390, 844), dpr: 3.0),
      _ViewportCase(name: 'phone_412', size: Size(412, 915), dpr: 3.5),
      _ViewportCase(name: 'phone_414', size: Size(414, 921), dpr: 3.25),
      _ViewportCase(name: 'phone_427', size: Size(427, 924), dpr: 3.0),
      _ViewportCase(name: 'phone_480', size: Size(480, 1066), dpr: 3.0),
      _ViewportCase(name: 'phone_landscape', size: Size(640, 360), dpr: 3.0),
      _ViewportCase(name: 'tablet_840', size: Size(840, 1180), dpr: 2.0),
      _ViewportCase(name: 'tablet_1024', size: Size(1024, 1366), dpr: 2.0),
      _ViewportCase(name: 'large_1366', size: Size(1366, 1024), dpr: 2.0),
    ];

    for (final item in cases) {
      await tester.pumpWidget(
        _TestHarness(
          width: item.size.width,
          height: item.size.height,
          dpr: item.dpr,
          child: const ShellScaffold(
            location: '/bookshelf',
            child: ColoredBox(color: Colors.white),
          ),
        ),
      );
      await tester.pump();

      expect(
        tester.takeException(),
        isNull,
        reason:
            'unexpected exception at ${item.name} (${item.size.width}x${item.size.height}@${item.dpr})',
      );
      if (item.size.width >= AppLayout.railBreakpointWidth) {
        expect(find.byType(NavigationRail), findsOneWidget);
      } else {
        expect(find.byType(NavigationBar), findsOneWidget);
      }
    }
  });
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

Future<void> _pumpPrimaryActions(
  WidgetTester tester, {
  required double width,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return BookDetailPrimaryActions(
                  availableWidth: constraints.maxWidth,
                  isInBookshelf: false,
                  isShelfActionLoading: false,
                  onRead: () {},
                  onToggleBookshelf: () {},
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

class _TestHarness extends StatelessWidget {
  const _TestHarness({
    required this.width,
    required this.child,
    this.height = 844,
    this.dpr = 3,
  });

  final double width;
  final double height;
  final double dpr;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MediaQuery(
        data: MediaQueryData(size: Size(width, height), devicePixelRatio: dpr),
        child: MaterialApp(home: child),
      ),
    );
  }
}

class _ViewportCase {
  const _ViewportCase({
    required this.name,
    required this.size,
    required this.dpr,
  });

  final String name;
  final Size size;
  final double dpr;
}

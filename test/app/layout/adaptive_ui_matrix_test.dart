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
          width < AppLayout.phoneSmallWidth
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
      320: 2,
      360: 2,
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
    const sizes = <Size>[
      Size(320, 844),
      Size(360, 800),
      Size(390, 844),
      Size(430, 932),
      Size(640, 360),
      Size(840, 1180),
      Size(1024, 1366),
      Size(1366, 1024),
    ];

    for (final size in sizes) {
      await tester.pumpWidget(
        _TestHarness(
          width: size.width,
          height: size.height,
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
        reason: 'unexpected exception at ${size.width}x${size.height}',
      );
      if (size.width >= AppLayout.railBreakpointWidth) {
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
  });

  final double width;
  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MediaQuery(
        data: MediaQueryData(size: Size(width, height)),
        child: MaterialApp(home: child),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class AdaptiveViewportCase {
  const AdaptiveViewportCase({
    required this.name,
    required this.size,
    required this.dpr,
  });

  final String name;
  final Size size;
  final double dpr;
}

const List<AdaptiveViewportCase>
kAdaptiveSmokeViewportCases = <AdaptiveViewportCase>[
  AdaptiveViewportCase(name: 'phone_360', size: Size(360, 800), dpr: 3.0),
  AdaptiveViewportCase(name: 'phone_390', size: Size(390, 844), dpr: 3.0),
  AdaptiveViewportCase(name: 'phone_412', size: Size(412, 915), dpr: 3.5),
  AdaptiveViewportCase(name: 'phone_414', size: Size(414, 921), dpr: 3.25),
  AdaptiveViewportCase(name: 'phone_427', size: Size(427, 924), dpr: 3.0),
  AdaptiveViewportCase(name: 'phone_480', size: Size(480, 1066), dpr: 3.0),
  AdaptiveViewportCase(name: 'phone_landscape', size: Size(640, 360), dpr: 3.0),
  AdaptiveViewportCase(name: 'tablet_840', size: Size(840, 1180), dpr: 2.0),
  AdaptiveViewportCase(name: 'tablet_1024', size: Size(1024, 1366), dpr: 2.0),
  AdaptiveViewportCase(name: 'large_1366', size: Size(1366, 1024), dpr: 2.0),
];

class AdaptiveTestHarness extends StatelessWidget {
  const AdaptiveTestHarness({
    super.key,
    required this.width,
    required this.child,
    this.height = 844,
    this.dpr = 3,
    this.textScaleFactor = 1,
    this.overrides = const <Override>[],
    this.wrapWithMaterialApp = false,
  });

  final double width;
  final double height;
  final double dpr;
  final double textScaleFactor;
  final List<Override> overrides;
  final bool wrapWithMaterialApp;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final content = wrapWithMaterialApp ? MaterialApp(home: child) : child;
    return ProviderScope(
      overrides: overrides,
      child: MediaQuery(
        data: MediaQueryData(
          size: Size(width, height),
          devicePixelRatio: dpr,
          textScaler: TextScaler.linear(textScaleFactor),
        ),
        child: content,
      ),
    );
  }
}

Future<void> registerAdaptiveViewportTearDown(WidgetTester tester) async {
  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> runAdaptivePageSmokeMatrix(
  WidgetTester tester, {
  required Widget Function() pageBuilder,
  required String pageName,
  bool useProviderScope = false,
  List<Override> overrides = const <Override>[],
  List<AdaptiveViewportCase> cases = kAdaptiveSmokeViewportCases,
}) async {
  await registerAdaptiveViewportTearDown(tester);

  for (final item in cases) {
    tester.view.devicePixelRatio = item.dpr;
    await tester.binding.setSurfaceSize(item.size);

    final router = GoRouter(
      routes: [GoRoute(path: '/', builder: (context, state) => pageBuilder())],
    );
    Widget app = MaterialApp.router(routerConfig: router);
    if (useProviderScope || overrides.isNotEmpty) {
      app = ProviderScope(overrides: overrides, child: app);
    }

    await tester.pumpWidget(app);
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      tester.takeException(),
      isNull,
      reason:
          '$pageName threw at ${item.name} (${item.size.width}x${item.size.height}@${item.dpr})',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 9));
  }
}

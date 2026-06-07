import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/app/widgets/adaptive_overflow_toolbar.dart';
import 'package:shuxiang_reading_next/features/mine/presentation/widgets/mine_route_top_bar.dart';

import '../../../test_utils/adaptive_test_harness.dart';

void main() {
  testWidgets('mine route top bar keeps compact page title simple', (
    tester,
  ) async {
    await tester.pumpWidget(
      AdaptiveTestHarness(
        width: 390,
        height: 844,
        wrapWithMaterialApp: true,
        child: Builder(
          builder:
              (context) => Scaffold(
                appBar: buildMineRouteTopBar(
                  context: context,
                  title: '外观',
                  subtitle: '主题与资源',
                  onBack: () {},
                  mobileActions: const <Widget>[
                    IconButton(onPressed: null, icon: Icon(Icons.add_rounded)),
                  ],
                ),
              ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('外观'), findsOneWidget);
    expect(find.text('主题与资源'), findsNothing);
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
  });

  testWidgets('mine route top bar exposes desktop subtitle and actions', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      AdaptiveTestHarness(
        width: 840,
        height: 900,
        wrapWithMaterialApp: true,
        child: Builder(
          builder:
              (context) => Scaffold(
                appBar: buildMineRouteTopBar(
                  context: context,
                  title: '字体管理',
                  subtitle: '资源能力',
                  onBack: () {},
                  actions: <AdaptiveOverflowToolbarItem>[
                    AdaptiveOverflowToolbarItem(
                      icon: Icons.refresh_rounded,
                      label: '刷新',
                      onPressed: () {
                        tapped = true;
                      },
                    ),
                  ],
                ),
              ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('字体管理'), findsOneWidget);
    expect(find.text('资源能力'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.refresh_rounded));
    expect(tapped, isTrue);
  });
}

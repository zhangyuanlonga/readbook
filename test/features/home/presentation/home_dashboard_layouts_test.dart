import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shuxiang_reading_next/app/layout/app_adaptive.dart';
import 'package:shuxiang_reading_next/features/home/presentation/widgets/home_dashboard_layouts.dart';

import '../../../test_utils/adaptive_test_harness.dart';

void main() {
  testWidgets('HomeMobileDashboardLayout preserves stable mobile order', (
    tester,
  ) async {
    final metrics = AppAdaptiveMetrics.resolveForSize(
      size: const Size(390, 844),
    );

    await tester.pumpWidget(
      AdaptiveTestHarness(
        width: 390,
        height: 844,
        wrapWithMaterialApp: true,
        child: Scaffold(
          body: HomeMobileDashboardLayout(
            metrics: metrics,
            checkInSummary: const Text('打卡'),
            sectionHeader: const Text('继续阅读标题'),
            continueReading: const Text('继续阅读内容'),
            readingGoal: const Text('阅读目标'),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      tester.getTopLeft(find.text('继续阅读标题')).dy,
      greaterThan(tester.getTopLeft(find.text('打卡')).dy),
    );
    expect(
      tester.getTopLeft(find.text('继续阅读内容')).dy,
      greaterThan(tester.getTopLeft(find.text('继续阅读标题')).dy),
    );
    expect(
      tester.getTopLeft(find.text('阅读目标')).dy,
      greaterThan(tester.getTopLeft(find.text('继续阅读内容')).dy),
    );
  });

  testWidgets('HomeDesktopDashboardLayout keeps primary panel wider', (
    tester,
  ) async {
    final metrics = AppAdaptiveMetrics.resolveForSize(
      size: const Size(1440, 900),
    );

    await tester.pumpWidget(
      AdaptiveTestHarness(
        width: 1440,
        height: 900,
        wrapWithMaterialApp: true,
        child: Scaffold(
          body: SizedBox(
            width: 1000,
            child: HomeDesktopDashboardLayout(
              metrics: metrics,
              continueReadingPanel: const ColoredBox(
                key: ValueKey<String>('desktop_primary'),
                color: Colors.blue,
                child: SizedBox(height: 80),
              ),
              readingSummary: const ColoredBox(
                key: ValueKey<String>('desktop_secondary'),
                color: Colors.green,
                child: SizedBox(height: 80),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final primaryWidth =
        tester
            .getSize(find.byKey(const ValueKey<String>('desktop_primary')))
            .width;
    final secondaryWidth =
        tester
            .getSize(find.byKey(const ValueKey<String>('desktop_secondary')))
            .width;

    expect(primaryWidth, greaterThan(secondaryWidth));
  });
}

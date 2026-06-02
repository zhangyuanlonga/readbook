import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shuxiang_reading_next/features/home/presentation/widgets/home_metric_widgets.dart';

import '../../../test_utils/adaptive_test_harness.dart';

void main() {
  testWidgets('HomeMetricPill renders label and value', (tester) async {
    await tester.pumpWidget(
      const AdaptiveTestHarness(
        width: 390,
        height: 844,
        wrapWithMaterialApp: true,
        child: Scaffold(body: HomeMetricPill(label: '本周打卡', value: '3 / 7')),
      ),
    );
    await tester.pump();

    expect(find.text('本周打卡'), findsOneWidget);
    expect(find.text('3 / 7'), findsOneWidget);
  });

  testWidgets('HomeAnimatedMetricPill renders formatted value', (tester) async {
    await tester.pumpWidget(
      AdaptiveTestHarness(
        width: 390,
        height: 844,
        wrapWithMaterialApp: true,
        child: Scaffold(
          body: HomeAnimatedMetricPill(
            label: '今日阅读',
            value: 12,
            formatter: (value) => '$value m',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('今日阅读'), findsOneWidget);
    expect(find.text('12 m'), findsOneWidget);
  });

  test('HomeReadingGoalArcPainter repaints when progress changes', () {
    const oldPainter = HomeReadingGoalArcPainter(
      progress: 0.2,
      trackColor: Colors.grey,
      progressColor: Colors.blue,
    );
    const nextPainter = HomeReadingGoalArcPainter(
      progress: 0.8,
      trackColor: Colors.grey,
      progressColor: Colors.blue,
    );

    expect(nextPainter.shouldRepaint(oldPainter), isTrue);
  });
}

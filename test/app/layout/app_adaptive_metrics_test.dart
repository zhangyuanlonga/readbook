import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shuxiang_reading_next/app/layout/app_adaptive.dart';
import '../../test_utils/adaptive_test_harness.dart';

void main() {
  test('resolveForSize covers standard adaptive viewport widths', () {
    final cases = <double, AppWindowClass>{
      360: AppWindowClass.compact,
      390: AppWindowClass.compact,
      412: AppWindowClass.compact,
      600: AppWindowClass.medium,
      840: AppWindowClass.expanded,
      1200: AppWindowClass.expanded,
    };

    for (final entry in cases.entries) {
      final metrics = AppAdaptiveMetrics.resolveForSize(
        size: Size(entry.key, 844),
      );
      expect(
        metrics.windowClass,
        entry.value,
        reason: 'unexpected window class at width=${entry.key}',
      );
    }
  });

  test(
    'resolveForSize lowers density for small, landscape, and scaled text',
    () {
      expect(
        AppAdaptiveMetrics.resolveForSize(size: const Size(360, 800)).density,
        AppDensity.compact,
      );
      expect(
        AppAdaptiveMetrics.resolveForSize(size: const Size(390, 844)).density,
        AppDensity.regular,
      );
      expect(
        AppAdaptiveMetrics.resolveForSize(
          size: const Size(412, 915),
          textScaleFactor: 1.3,
        ).density,
        AppDensity.compact,
      );
      expect(
        AppAdaptiveMetrics.resolveForSize(size: const Size(780, 360)).density,
        AppDensity.compact,
      );
      expect(
        AppAdaptiveMetrics.resolveForSize(size: const Size(840, 1180)).density,
        AppDensity.comfortable,
      );
    },
  );

  test('resolveForSize exposes stable layout tokens', () {
    final phone = AppAdaptiveMetrics.resolveForSize(size: const Size(390, 844));
    final medium = AppAdaptiveMetrics.resolveForSize(
      size: const Size(600, 960),
    );
    final expanded = AppAdaptiveMetrics.resolveForSize(
      size: const Size(840, 1180),
    );

    expect(phone.pagePadding, 16);
    expect(phone.cardPadding, 14);
    expect(phone.controlHeight, 40);
    expect(medium.pagePadding, 20);
    expect(expanded.pagePadding, 24);
    expect(expanded.dialogMaxWidth, 560);
    expect(expanded.bottomSheetMaxWidth, 720);
  });

  testWidgets('of and resolveForConstraints read MediaQuery and local width', (
    tester,
  ) async {
    AppAdaptiveMetrics? fromContext;
    AppAdaptiveMetrics? fromConstraints;

    await tester.pumpWidget(
      AdaptiveTestHarness(
        width: 840,
        height: 1180,
        textScaleFactor: 1.3,
        child: Builder(
          builder: (context) {
            fromContext = AppAdaptiveMetrics.of(context);
            fromConstraints = AppAdaptiveMetrics.resolveForConstraints(
              context,
              const BoxConstraints(maxWidth: 390, maxHeight: 640),
            );
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pump();

    expect(fromContext!.windowClass, AppWindowClass.expanded);
    expect(fromContext!.density, AppDensity.compact);
    expect(fromConstraints!.width, 390);
    expect(fromConstraints!.windowClass, AppWindowClass.compact);
    expect(fromConstraints!.density, AppDensity.compact);
  });

  test(
    'gridColumnsFor computes columns from available width and item width',
    () {
      final metrics = AppAdaptiveMetrics.resolveForSize(
        size: const Size(412, 915),
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
    },
  );
}

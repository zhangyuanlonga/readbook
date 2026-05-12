import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shuxiang_reading_next/app/motion/app_motion.dart';

void main() {
  test('AppMotion exposes stable baseline tokens', () {
    expect(AppMotion.instant, Duration.zero);
    expect(AppMotion.fast, const Duration(milliseconds: 120));
    expect(AppMotion.medium, const Duration(milliseconds: 180));
    expect(AppMotion.slow, const Duration(milliseconds: 260));
    expect(AppMotion.page, const Duration(milliseconds: 300));
    expect(AppMotion.pageEnterOffset, const Offset(0, 0.035));
    expect(AppMotion.sectionEnterOffset, const Offset(0, 0.02));
    expect(AppMotion.microOffset, const Offset(0, 0.008));
  });

  testWidgets('enabledOf respects MediaQuery.disableAnimations', (
    tester,
  ) async {
    bool? enabled;
    Duration? duration;

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Builder(
          builder: (context) {
            enabled = AppMotion.enabledOf(context);
            duration = AppMotion.durationOf(context, AppMotion.medium);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(enabled, isFalse);
    expect(duration, Duration.zero);
  });

  testWidgets('AppMotionScope can disable motion for tests or features', (
    tester,
  ) async {
    bool? enabled;

    await tester.pumpWidget(
      AppMotionScope(
        enabled: false,
        child: Builder(
          builder: (context) {
            enabled = AppMotionScope.enabledOf(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(enabled, isFalse);
  });
}

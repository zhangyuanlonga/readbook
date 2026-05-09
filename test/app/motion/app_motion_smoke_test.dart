import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shuxiang_reading_next/app/motion/app_motion_widgets.dart';

void main() {
  testWidgets('motion widgets render and degrade under disableAnimations', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: const Scaffold(
            body: AppFadeSlideTransition(child: Text('motion smoke')),
          ),
        ),
      ),
    );

    expect(find.text('motion smoke'), findsOneWidget);
  });
}

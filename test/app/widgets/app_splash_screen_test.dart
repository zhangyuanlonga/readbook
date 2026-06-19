import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/app/widgets/app_splash_screen.dart';

void main() {
  testWidgets('splash brand text does not inherit underline decoration', (
    tester,
  ) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: AppSplashBrandMark(),
      ),
    );

    final title = tester.widget<Text>(find.text('书享阅读'));
    final subtitle = tester.widget<Text>(find.text('CLEAR READING'));

    expect(title.style?.decoration, TextDecoration.none);
    expect(subtitle.style?.decoration, TextDecoration.none);
  });
}

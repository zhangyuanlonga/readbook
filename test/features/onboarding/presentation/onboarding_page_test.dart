import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuxiang_reading_next/features/onboarding/presentation/onboarding_page.dart';

void main() {
  testWidgets('OnboardingPage renders custom steps without Material errors', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: OnboardingPage())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('欢迎来到书享阅读'), findsOneWidget);

    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();

    expect(find.text('选择第一眼的样子'), findsOneWidget);
    expect(find.byType(ChoiceChip), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();

    expect(find.text('选择常用列表'), findsOneWidget);
    expect(find.byType(SegmentedButton<bool>), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

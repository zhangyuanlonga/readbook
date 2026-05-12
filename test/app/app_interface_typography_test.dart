import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuxiang_reading_next/app/app.dart';

Future<void> _pumpAppAndDismissStartup(WidgetTester tester) async {
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  await tester.pumpWidget(const ProviderScope(child: App()));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));

  final closeButtonFinder = find.text('我知道了');
  if (closeButtonFinder.evaluate().isNotEmpty) {
    await tester.tap(closeButtonFinder);
    await tester.pumpAndSettle();
  }

  await tester.pump(const Duration(seconds: 3));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('interface text scale is applied on external pages', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'app.shell.navigation.discover': true,
      'app.interfaceTextScale': 1.2,
      'app.interfaceFontWeight': 400,
      'app.interfaceFont.source': 'system',
      'app.interfaceFont.systemPreset': 'defaultSans',
    });

    await _pumpAppAndDismissStartup(tester);

    final bookshelfElement = tester.element(find.text('书架').first);
    final effectiveScale = MediaQuery.textScalerOf(bookshelfElement).scale(1);

    expect(effectiveScale, closeTo(1.2, 0.001));
  });

  testWidgets('interface font weight is applied on external pages theme', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'app.shell.navigation.discover': true,
      'app.interfaceTextScale': 1.0,
      'app.interfaceFontWeight': 700,
      'app.interfaceFont.source': 'system',
      'app.interfaceFont.systemPreset': 'defaultSans',
    });

    await _pumpAppAndDismissStartup(tester);

    final bookshelfElement = tester.element(find.text('书架').first);
    final bodyMediumWeight =
        Theme.of(bookshelfElement).textTheme.bodyMedium?.fontWeight;

    expect(bodyMediumWeight, FontWeight.w700);
  });
}

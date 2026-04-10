import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/app/shell_navigation_provider.dart';
import 'package:shuxiang_reading_next/app/widgets/cupertino_dock_navigation_bar.dart';

void main() {
  testWidgets('CupertinoDockNavigationBar forwards tab and search taps', (
    tester,
  ) async {
    var selectedIndex = -1;
    var searchPressed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: CupertinoDockNavigationBar(
            destinations: appShellDestinations,
            selectedIndex: 0,
            showLabels: true,
            onDestinationSelected: (index) {
              selectedIndex = index;
            },
            onSearchPressed: () {
              searchPressed = true;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('发现'));
    await tester.pumpAndSettle();

    expect(selectedIndex, 1);

    await tester.tap(find.byTooltip('搜索'));
    await tester.pumpAndSettle();

    expect(searchPressed, isTrue);
  });

  testWidgets('CupertinoDockNavigationBar can hide tab labels', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: CupertinoDockNavigationBar(
            destinations: appShellDestinations,
            selectedIndex: 0,
            showLabels: false,
            onDestinationSelected: (_) {},
            onSearchPressed: () {},
          ),
        ),
      ),
    );

    expect(find.text('书架'), findsNothing);
    expect(find.text('发现'), findsNothing);
    expect(find.text('统计'), findsNothing);
    expect(find.text('我的'), findsNothing);
    expect(find.byTooltip('发现'), findsOneWidget);
  });
}

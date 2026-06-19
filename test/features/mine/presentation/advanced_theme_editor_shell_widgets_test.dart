import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/mine/presentation/widgets/advanced_theme_editor_shell_widgets.dart';

void main() {
  testWidgets('section label renders tooltip trigger', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AdvancedThemeSectionLabel(title: '颜色层', tooltipMessage: '颜色说明'),
        ),
      ),
    );

    expect(find.text('颜色层'), findsOneWidget);
    expect(find.byIcon(Icons.help_outline_rounded), findsOneWidget);
  });

  testWidgets('expandable section header reports toggle taps', (tester) async {
    var toggled = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdvancedThemeExpandableSectionHeader(
            title: '强度层',
            expanded: false,
            onToggle: () {
              toggled = true;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('强度层'));
    expect(toggled, isTrue);
    expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);
  });

  testWidgets('panel and list body keep child content', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              AdvancedThemePanel(child: Text('panel child')),
              AdvancedThemeListSectionBody(child: Text('list child')),
            ],
          ),
        ),
      ),
    );

    expect(find.text('panel child'), findsOneWidget);
    expect(find.text('list child'), findsOneWidget);
  });
}

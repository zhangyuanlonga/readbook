import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/app_advanced_theme.dart';
import 'package:shuxiang_reading_next/features/mine/application/advanced_theme_service.dart';
import 'package:shuxiang_reading_next/features/mine/presentation/widgets/advanced_theme_summary_card.dart';

void main() {
  testWidgets('custom theme card applies from card tap without action button', (
    tester,
  ) async {
    var tapCount = 0;

    await tester.pumpWidget(
      _CardHarness(isActive: false, onTap: () => tapCount += 1),
    );

    expect(find.text('应用主题'), findsNothing);
    expect(find.text('停用主题'), findsNothing);
    expect(find.byIcon(Icons.verified_outlined), findsNothing);

    await tester.tap(find.text('自定义主题'));
    expect(tapCount, 1);
  });

  testWidgets(
    'active custom theme card shows the same status icon affordance',
    (tester) async {
      await tester.pumpWidget(const _CardHarness(isActive: true));

      expect(find.text('应用主题'), findsNothing);
      expect(find.text('停用主题'), findsNothing);
      expect(find.text('当前生效'), findsOneWidget);
      expect(find.byIcon(Icons.verified_outlined), findsOneWidget);
    },
  );
}

class _CardHarness extends StatelessWidget {
  const _CardHarness({required this.isActive, this.onTap});

  final bool isActive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 360,
            child: AdvancedThemeSummaryCard(
              theme: _summary,
              isActive: isActive,
              isSelected: false,
              isSelectionMode: false,
              isSaving: false,
              previewStrip: const SizedBox(height: 24),
              onTap: onTap ?? () {},
              onSelectionChanged: (_) {},
              onActionSelected: (_) {},
            ),
          ),
        ),
      ),
    );
  }
}

final _summary = AdvancedThemeSummary(
  id: 'custom-theme',
  name: '自定义主题',
  category: '阅读',
  updatedAt: DateTime.utc(2026),
  lightMode: _modeSummary(),
  darkMode: _modeSummary(),
);

AdvancedThemeModeSummary _modeSummary() {
  return const AdvancedThemeModeSummary(
    primaryColorValue: 0xFF3366FF,
    backgroundColorValue: 0xFFFFFFFF,
    surfaceColorValue: 0xFFF5F7FB,
    cardColorValue: 0xFFFFFFFF,
    cardTextColorValue: 0xFF111827,
    textSecondaryColorValue: 0xFF667085,
    componentStyle: AppAdvancedThemeComponentStyle(),
    wallpaperPath: null,
    hasWallpaper: false,
    hasReaderWallpaper: false,
    configuredColorCount: 6,
  );
}

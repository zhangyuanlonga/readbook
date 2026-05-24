import 'package:flutter/material.dart';
import 'package:shuxiang_reading_next/features/search/presentation/widgets/search_grouped_empty_fallback_card.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'shows both fallback actions when precise and source filter apply',
    (tester) async {
      var disablePreciseTapped = false;
      var switchAllTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SearchGroupedEmptyFallbackCard(
              canDisablePrecise: true,
              canSwitchAllSources: true,
              onDisablePreciseMatch: () => disablePreciseTapped = true,
              onSwitchAllSources: () => switchAllTapped = true,
            ),
          ),
        ),
      );

      expect(find.text('当前分组无结果，可尝试关闭精准匹配或切换全部书源。'), findsOneWidget);
      expect(find.text('关闭精准匹配'), findsOneWidget);
      expect(find.text('切换全部书源'), findsOneWidget);

      await tester.tap(find.text('关闭精准匹配'));
      await tester.pump();
      await tester.tap(find.text('切换全部书源'));
      await tester.pump();

      expect(disablePreciseTapped, isTrue);
      expect(switchAllTapped, isTrue);
    },
  );

  testWidgets(
    'shows source-only tip and action when only source filter applies',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SearchGroupedEmptyFallbackCard(
              canDisablePrecise: false,
              canSwitchAllSources: true,
              onDisablePreciseMatch: () {},
              onSwitchAllSources: () {},
            ),
          ),
        ),
      );

      expect(find.text('当前筛选书源无结果，可切换全部书源后重试。'), findsOneWidget);
      expect(find.text('关闭精准匹配'), findsNothing);
      expect(find.text('切换全部书源'), findsOneWidget);
    },
  );

  testWidgets('shows default message without fallback actions', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SearchGroupedEmptyFallbackCard(
            canDisablePrecise: false,
            canSwitchAllSources: false,
            onDisablePreciseMatch: () {},
            onSwitchAllSources: () {},
          ),
        ),
      ),
    );

    expect(find.text('暂无可展示结果，请检查书源配置或更换关键词。'), findsOneWidget);
    expect(find.text('关闭精准匹配'), findsNothing);
    expect(find.text('切换全部书源'), findsNothing);
  });
}

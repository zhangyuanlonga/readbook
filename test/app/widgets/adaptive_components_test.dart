import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shuxiang_reading_next/app/widgets/adaptive_content_container.dart';
import 'package:shuxiang_reading_next/app/widgets/adaptive_filter_bar.dart';
import 'package:shuxiang_reading_next/app/widgets/adaptive_list_tile.dart';
import 'package:shuxiang_reading_next/app/widgets/adaptive_search_bar.dart';
import 'package:shuxiang_reading_next/app/widgets/adaptive_setting_tile.dart';
import '../../test_utils/adaptive_test_harness.dart';

void main() {
  testWidgets('AdaptiveSearchBar uses compact and regular control heights', (
    tester,
  ) async {
    final compactController = TextEditingController();
    addTearDown(compactController.dispose);

    await tester.pumpWidget(
      AdaptiveTestHarness(
        width: 360,
        height: 800,
        wrapWithMaterialApp: true,
        child: Scaffold(
          body: AdaptiveSearchBar(
            controller: compactController,
            onChanged: (_) {},
            onClear: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    final compactBox = tester.widget<SizedBox>(
      find
          .ancestor(of: find.byType(TextField), matching: find.byType(SizedBox))
          .first,
    );
    expect(compactBox.height, 36);

    final regularController = TextEditingController();
    addTearDown(regularController.dispose);
    await tester.pumpWidget(
      AdaptiveTestHarness(
        width: 390,
        height: 844,
        wrapWithMaterialApp: true,
        child: Scaffold(
          body: AdaptiveSearchBar(
            controller: regularController,
            onChanged: (_) {},
            onClear: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    final regularBox = tester.widget<SizedBox>(
      find
          .ancestor(of: find.byType(TextField), matching: find.byType(SizedBox))
          .first,
    );
    expect(regularBox.height, 40);
  });

  testWidgets(
    'AdaptiveFilterBar renders chips and action in compact viewport',
    (tester) async {
      var actionTapped = false;

      await tester.pumpWidget(
        AdaptiveTestHarness(
          width: 360,
          height: 800,
          wrapWithMaterialApp: true,
          child: Scaffold(
            body: AdaptiveFilterBar(
              chips: const [
                AdaptiveFilterChipData(
                  label: '全部',
                  selected: true,
                  onTap: null,
                ),
                AdaptiveFilterChipData(
                  label: '本地',
                  selected: false,
                  onTap: null,
                ),
              ],
              onActionPressed: () {
                actionTapped = true;
              },
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('全部'), findsOneWidget);
      expect(find.text('本地'), findsOneWidget);
      expect(find.text('筛选'), findsOneWidget);

      await tester.tap(find.text('筛选'));
      expect(actionTapped, isTrue);
    },
  );

  testWidgets('AdaptiveSettingTile clamps description on compact viewport', (
    tester,
  ) async {
    await tester.pumpWidget(
      const AdaptiveTestHarness(
        width: 360,
        height: 800,
        wrapWithMaterialApp: true,
        child: Scaffold(
          body: AdaptiveSettingSection(
            child: AdaptiveSettingTile(
              icon: Icons.tune_rounded,
              title: '系统偏好',
              description: '很长的说明文字会在小屏幕上限制行数，避免把开关控件和后续设置项挤出首屏。',
              trailing: Switch(value: true, onChanged: null),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final description = tester.widget<Text>(
      find.text('很长的说明文字会在小屏幕上限制行数，避免把开关控件和后续设置项挤出首屏。'),
    );
    expect(description.maxLines, 2);
    expect(find.byType(Switch), findsOneWidget);
  });

  testWidgets('AdaptiveContentContainer uses default width token on desktop', (
    tester,
  ) async {
    await tester.pumpWidget(
      const AdaptiveTestHarness(
        width: 1280,
        height: 800,
        wrapWithMaterialApp: true,
        child: Scaffold(
          body: AdaptiveContentContainer(child: SizedBox(height: 20)),
        ),
      ),
    );
    await tester.pump();

    final constrainedBox = tester.widget<ConstrainedBox>(
      find
          .ancestor(
            of: find.byType(SizedBox),
            matching: find.byType(ConstrainedBox),
          )
          .first,
    );
    expect(constrainedBox.constraints.maxWidth, 820);
  });

  testWidgets('AdaptiveListTile supports selected and disabled states', (
    tester,
  ) async {
    var tapped = false;

    await tester.pumpWidget(
      AdaptiveTestHarness(
        width: 390,
        height: 844,
        wrapWithMaterialApp: true,
        child: Scaffold(
          body: AdaptiveListTile(
            selected: true,
            enabled: false,
            title: const Text('章节'),
            subtitle: const Text('不可点击'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              tapped = true;
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('章节'));

    expect(tapped, isFalse);
    final semantics = tester.getSemantics(find.byType(AdaptiveListTile));
    expect(semantics.hasFlag(SemanticsFlag.isSelected), isTrue);
    expect(semantics.hasFlag(SemanticsFlag.isEnabled), isFalse);
  });

  testWidgets('AdaptiveSettingTile exposes tap path when enabled', (
    tester,
  ) async {
    var tapped = false;

    await tester.pumpWidget(
      AdaptiveTestHarness(
        width: 390,
        height: 844,
        wrapWithMaterialApp: true,
        child: Scaffold(
          body: AdaptiveSettingTile(
            icon: Icons.tune_rounded,
            title: '阅读设置',
            description: '打开阅读设置',
            onTap: () {
              tapped = true;
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('阅读设置'));

    expect(tapped, isTrue);
  });
}

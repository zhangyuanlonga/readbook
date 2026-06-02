import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shuxiang_reading_next/app/widgets/adaptive_bottom_sheet.dart';
import 'package:shuxiang_reading_next/app/widgets/adaptive_content_container.dart';
import 'package:shuxiang_reading_next/app/widgets/adaptive_filter_bar.dart';
import 'package:shuxiang_reading_next/app/widgets/adaptive_list_tile.dart';
import 'package:shuxiang_reading_next/app/widgets/adaptive_overflow_toolbar.dart';
import 'package:shuxiang_reading_next/app/widgets/adaptive_search_bar.dart';
import 'package:shuxiang_reading_next/app/widgets/adaptive_setting_tile.dart';
import 'package:shuxiang_reading_next/app/widgets/adaptive_split_body.dart';
import 'package:shuxiang_reading_next/app/widgets/app_empty_state_card.dart';
import 'package:shuxiang_reading_next/app/widgets/app_task_bottom_sheet.dart';
import 'package:shuxiang_reading_next/app/widgets/import_export_task_overlay.dart';
import 'package:shuxiang_reading_next/app/widgets/import_export_task_sheet.dart';
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
    expect(semantics.flagsCollection.isSelected, Tristate.isTrue);
    expect(semantics.flagsCollection.isEnabled, Tristate.isFalse);
  });

  testWidgets('AdaptiveSplitBody stacks below breakpoint and splits above it', (
    tester,
  ) async {
    await tester.pumpWidget(
      const AdaptiveTestHarness(
        width: 700,
        height: 800,
        wrapWithMaterialApp: true,
        child: Scaffold(
          body: SizedBox(
            width: 700,
            child: AdaptiveSplitBody(
              primary: SizedBox(
                key: ValueKey<String>('split_primary'),
                height: 40,
              ),
              secondary: SizedBox(
                key: ValueKey<String>('split_secondary'),
                height: 40,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    var primaryTop = tester.getTopLeft(
      find.byKey(const ValueKey<String>('split_primary')),
    );
    var secondaryTop = tester.getTopLeft(
      find.byKey(const ValueKey<String>('split_secondary')),
    );
    expect(secondaryTop.dy, greaterThan(primaryTop.dy));

    await tester.pumpWidget(
      const AdaptiveTestHarness(
        width: 1024,
        height: 800,
        wrapWithMaterialApp: true,
        child: Scaffold(
          body: SizedBox(
            width: 1024,
            child: AdaptiveSplitBody(
              breakpoint: 600,
              primary: SizedBox(
                key: ValueKey<String>('split_primary'),
                height: 40,
              ),
              secondary: SizedBox(
                key: ValueKey<String>('split_secondary'),
                height: 40,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    primaryTop = tester.getTopLeft(
      find.byKey(const ValueKey<String>('split_primary')),
    );
    secondaryTop = tester.getTopLeft(
      find.byKey(const ValueKey<String>('split_secondary')),
    );
    expect(secondaryTop.dx, greaterThan(primaryTop.dx));
    expect((secondaryTop.dy - primaryTop.dy).abs(), lessThan(1));
  });

  testWidgets('AdaptiveOverflowToolbar keeps priority items visible', (
    tester,
  ) async {
    var firstTapped = false;
    var thirdTapped = false;
    await tester.pumpWidget(
      AdaptiveTestHarness(
        width: 180,
        height: 200,
        wrapWithMaterialApp: true,
        child: Scaffold(
          body: SizedBox(
            width: 104,
            child: AdaptiveOverflowToolbar(
              spacing: 8,
              items: [
                AdaptiveOverflowToolbarItem(
                  icon: Icons.star,
                  label: '重要',
                  priority: 10,
                  onPressed: () {
                    firstTapped = true;
                  },
                ),
                AdaptiveOverflowToolbarItem(
                  icon: Icons.tune,
                  label: '普通',
                  priority: 1,
                  onPressed: () {},
                ),
                AdaptiveOverflowToolbarItem(
                  icon: Icons.archive,
                  label: '收起项',
                  onPressed: () {
                    thirdTapped = true;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.star), findsOneWidget);
    expect(find.byIcon(Icons.tune), findsNothing);
    expect(find.byIcon(Icons.more_horiz_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.star));
    expect(firstTapped, isTrue);

    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('收起项'));
    expect(thirdTapped, isTrue);
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

  testWidgets('AppEmptyStateCard renders animated icon and action', (
    tester,
  ) async {
    var tapped = false;

    await tester.pumpWidget(
      AdaptiveTestHarness(
        width: 390,
        height: 844,
        wrapWithMaterialApp: true,
        child: Scaffold(
          body: AppEmptyStateCard(
            icon: Icons.book_outlined,
            title: '暂无内容',
            description: '稍后再试。',
            actionLabel: '去添加',
            onAction: () {
              tapped = true;
            },
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('暂无内容'), findsOneWidget);
    expect(find.text('去添加'), findsOneWidget);

    await tester.tap(find.text('去添加'));
    expect(tapped, isTrue);
  });

  testWidgets('ImportExportTaskSheet reflects failure result', (tester) async {
    await tester.pumpWidget(
      const AdaptiveTestHarness(
        width: 390,
        height: 844,
        wrapWithMaterialApp: true,
        child: Scaffold(
          body: ImportExportTaskSheet(
            status: ImportExportTaskStatus(
              title: '导入失败',
              message: '文件格式不支持',
              result: ImportExportTaskResult.failure,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('处理失败'), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
  });

  testWidgets('AppTaskBottomSheet fills compact mobile width', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const AdaptiveTestHarness(
        width: 390,
        height: 844,
        wrapWithMaterialApp: true,
        child: Scaffold(
          body: AppTaskBottomSheet(
            title: '导入本地图书',
            fitContent: true,
            body: SizedBox(height: 120),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(AdaptiveSheetDragHandle), findsOneWidget);

    final sheetBox =
        find
            .ancestor(
              of: find.text('导入本地图书'),
              matching: find.byType(DecoratedBox),
            )
            .first;
    expect(tester.getSize(sheetBox).width, 390);
  });

  testWidgets('showAdaptiveRawSurface dismisses when tapping outside', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      AdaptiveTestHarness(
        width: 390,
        height: 844,
        wrapWithMaterialApp: true,
        child: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () {
                    showAdaptiveRawSurface<void>(
                      context: context,
                      showDragHandle: false,
                      mobileBackgroundColor: Colors.transparent,
                      builder:
                          (context) => const AppTaskBottomSheet(
                            title: '导入本地图书',
                            fitContent: true,
                            body: SizedBox(height: 120),
                          ),
                    );
                  },
                  child: const Text('打开'),
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    expect(find.text('导入本地图书'), findsOneWidget);
    expect(find.byType(AdaptiveSheetDragHandle), findsOneWidget);

    await tester.tapAt(const Offset(20, 120));
    await tester.pumpAndSettle();

    expect(find.text('导入本地图书'), findsNothing);
  });
}

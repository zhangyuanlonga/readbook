import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:shimmer/shimmer.dart';
import 'package:shuxiang_reading_next/app/widgets/foundation/foundation.dart';

import '../../test_utils/adaptive_test_harness.dart';

void main() {
  testWidgets('AppButton handles tap, icon, expanded and loading states', (
    tester,
  ) async {
    var tapped = false;

    await tester.pumpWidget(
      AdaptiveTestHarness(
        width: 390,
        height: 844,
        wrapWithMaterialApp: true,
        child: Scaffold(
          body: Column(
            children: [
              AppButton(
                label: '保存',
                icon: const Icon(Icons.save_rounded),
                expanded: true,
                onPressed: () {
                  tapped = true;
                },
              ),
              const AppButton(label: '保存中', isLoading: true, onPressed: null),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.text('保存'));
    expect(tapped, isTrue);
    expect(find.byIcon(Icons.save_rounded), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    final expandedBox = tester.widget<SizedBox>(
      find.ancestor(of: find.text('保存'), matching: find.byType(SizedBox)).first,
    );
    expect(expandedBox.width, double.infinity);
  });

  testWidgets('AppButton renders secondary, tonal, danger and text variants', (
    tester,
  ) async {
    await tester.pumpWidget(
      const AdaptiveTestHarness(
        width: 600,
        height: 960,
        wrapWithMaterialApp: true,
        child: Scaffold(
          body: Wrap(
            children: [
              AppButton(
                label: '次要',
                variant: AppButtonVariant.secondary,
                onPressed: null,
              ),
              AppButton(
                label: '柔和',
                variant: AppButtonVariant.tonal,
                onPressed: null,
              ),
              AppButton(
                label: '删除',
                variant: AppButtonVariant.danger,
                onPressed: null,
              ),
              AppButton(
                label: '文字',
                variant: AppButtonVariant.text,
                onPressed: null,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(OutlinedButton), findsOneWidget);
    expect(find.byType(FilledButton), findsNWidgets(2));
    expect(find.byType(TextButton), findsOneWidget);
    expect(find.text('删除'), findsOneWidget);
  });

  testWidgets('AppTextField supports value changes and error presentation', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    var changedValue = '';

    await tester.pumpWidget(
      AdaptiveTestHarness(
        width: 390,
        height: 844,
        wrapWithMaterialApp: true,
        child: Scaffold(
          body: AppTextField(
            controller: controller,
            labelText: '名称',
            hintText: '输入名称',
            errorText: '名称不能为空',
            prefixIcon: const Icon(Icons.edit_outlined),
            onChanged: (value) {
              changedValue = value;
            },
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '主题 A');

    expect(changedValue, '主题 A');
    expect(find.text('名称不能为空'), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
  });

  testWidgets('AppTextField keeps read-only fields stable on desktop', (
    tester,
  ) async {
    final controller = TextEditingController(text: '只读内容');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      AdaptiveTestHarness(
        width: 1280,
        height: 800,
        wrapWithMaterialApp: true,
        child: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: AppTextField(
                controller: controller,
                labelText: '只读',
                readOnly: true,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('只读内容'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AppSkeletonBlock animates and respects disabled animations', (
    tester,
  ) async {
    await tester.pumpWidget(
      const AdaptiveTestHarness(
        width: 390,
        height: 844,
        wrapWithMaterialApp: true,
        child: Scaffold(body: AppSkeletonBlock(height: 24)),
      ),
    );

    expect(find.byType(Shimmer), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(body: AppSkeletonBlock(height: 24)),
        ),
      ),
    );

    expect(find.byType(Shimmer), findsNothing);
    expect(find.byType(AppSkeletonBlock), findsOneWidget);
  });

  testWidgets('AppSkeletonList renders stable fixed-size rows', (tester) async {
    await tester.pumpWidget(
      const AdaptiveTestHarness(
        width: 600,
        height: 960,
        wrapWithMaterialApp: true,
        child: Scaffold(
          body: AppSkeletonList(itemCount: 2, showTrailing: true),
        ),
      ),
    );

    expect(find.byType(AppSkeletonBlock), findsNWidgets(8));
    expect(tester.takeException(), isNull);
  });

  testWidgets('AppFeedback shows snack bar and inline feedback', (
    tester,
  ) async {
    await tester.pumpWidget(
      AdaptiveTestHarness(
        width: 390,
        height: 844,
        wrapWithMaterialApp: true,
        child: Scaffold(
          body: Builder(
            builder: (context) {
              return Column(
                children: [
                  AppButton(
                    label: '提示',
                    onPressed: () {
                      AppFeedback.showSnackBar(
                        context,
                        message: '保存成功',
                        tone: AppFeedbackTone.success,
                        useHaptics: false,
                      );
                    },
                  ),
                  const AppInlineFeedback(
                    title: '需要处理',
                    message: '同步失败，请稍后重试',
                    tone: AppFeedbackTone.warning,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('提示'));
    await tester.pump();

    expect(find.text('保存成功'), findsOneWidget);
    expect(find.text('需要处理'), findsOneWidget);
    expect(find.text('同步失败，请稍后重试'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('AppBatchActionBar handles selection and neutral actions', (
    tester,
  ) async {
    var selectedAll = false;
    var cleared = false;
    var archived = false;

    await tester.pumpWidget(
      AdaptiveTestHarness(
        width: 600,
        height: 960,
        wrapWithMaterialApp: true,
        child: Scaffold(
          body: AppBatchActionBar(
            selectedCount: 2,
            totalCount: 5,
            onSelectAll: () {
              selectedAll = true;
            },
            onClearSelection: () {
              cleared = true;
            },
            actions: [
              AppBatchAction(
                label: '归档',
                icon: Icons.archive_outlined,
                onPressed: () {
                  archived = true;
                },
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('已选择 2 / 5 项'), findsOneWidget);

    await tester.tap(find.text('全选'));
    await tester.tap(find.text('取消选择'));
    await tester.tap(find.text('归档'));
    await tester.pump();

    expect(selectedAll, isTrue);
    expect(cleared, isTrue);
    expect(archived, isTrue);
  });

  testWidgets('AppBatchActionBar confirms destructive batch actions', (
    tester,
  ) async {
    var deleted = false;

    await tester.pumpWidget(
      AdaptiveTestHarness(
        width: 390,
        height: 844,
        wrapWithMaterialApp: true,
        child: Scaffold(
          body: AppBatchActionBar(
            selectedCount: 3,
            totalCount: 3,
            actions: [
              AppBatchAction(
                label: '删除',
                icon: Icons.delete_outline,
                tone: AppBatchActionTone.destructive,
                confirmation: const AppBatchActionConfirmation(
                  title: '删除所选项目',
                  message: '删除后无法恢复，请确认是否继续。',
                  confirmLabel: '确认删除',
                ),
                onPressed: () {
                  deleted = true;
                },
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();

    expect(deleted, isFalse);
    expect(find.text('删除所选项目'), findsOneWidget);
    expect(find.text('删除后无法恢复，请确认是否继续。'), findsOneWidget);

    await tester.tap(find.text('确认删除'));
    await tester.pumpAndSettle();

    expect(deleted, isTrue);
  });

  testWidgets('AppContextMenu opens native menu actions', (tester) async {
    var archived = false;

    await tester.pumpWidget(
      AdaptiveTestHarness(
        width: 1280,
        height: 800,
        wrapWithMaterialApp: true,
        child: Scaffold(
          body: Center(
            child: AppContextMenu(
              actions: [
                AppContextMenuAction(
                  label: '归档',
                  icon: Icons.archive_outlined,
                  onPressed: () {
                    archived = true;
                  },
                ),
              ],
              child: const Padding(
                padding: EdgeInsets.all(24),
                child: Text('条目'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.longPress(find.text('条目'));
    await tester.pumpAndSettle();

    expect(find.text('归档'), findsOneWidget);

    await tester.tap(find.text('归档'));
    await tester.pumpAndSettle();

    expect(archived, isTrue);
  });

  testWidgets('AppShortcuts delegates key events to native actions', (
    tester,
  ) async {
    var refreshed = false;

    await tester.pumpWidget(
      AdaptiveTestHarness(
        width: 1280,
        height: 800,
        wrapWithMaterialApp: true,
        child: Scaffold(
          body: AppShortcuts(
            actions: [
              AppShortcutAction(
                activator: const SingleActivator(LogicalKeyboardKey.f5),
                onInvoke: () {
                  refreshed = true;
                },
              ),
            ],
            child: const Text('桌面编辑区'),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.f5);
    await tester.pump();

    expect(refreshed, isTrue);
  });

  testWidgets('AppSlidableActionTile wraps mature slidable actions', (
    tester,
  ) async {
    var deleted = false;

    await tester.pumpWidget(
      AdaptiveTestHarness(
        width: 390,
        height: 844,
        wrapWithMaterialApp: true,
        child: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              height: 72,
              child: AppSlidableActionGroup(
                child: AppSlidableActionTile(
                  actions: [
                    AppSlidableAction(
                      label: '删除',
                      icon: Icons.delete_outline,
                      tone: AppSlidableActionTone.destructive,
                      onPressed: () {
                        deleted = true;
                      },
                    ),
                  ],
                  child: const ListTile(title: Text('可滑动条目')),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(Slidable), findsOneWidget);

    await tester.drag(find.text('可滑动条目'), const Offset(-260, 0));
    await tester.pumpAndSettle();

    expect(find.text('删除'), findsOneWidget);

    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();

    expect(deleted, isTrue);
  });

  testWidgets('AppHaptics uses Flutter platform haptic channel', (
    tester,
  ) async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          calls.add(call);
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await AppHaptics.success();
    await AppHaptics.danger(enabled: false);

    expect(calls, hasLength(1));
    expect(calls.single.method, 'HapticFeedback.vibrate');
    expect(calls.single.arguments, 'HapticFeedbackType.lightImpact');
  });

  testWidgets('AppRefreshIndicator delegates to native refresh behavior', (
    tester,
  ) async {
    var refreshed = false;

    await tester.pumpWidget(
      AdaptiveTestHarness(
        width: 390,
        height: 844,
        wrapWithMaterialApp: true,
        child: Scaffold(
          body: AppRefreshIndicator(
            onRefresh: () async {
              refreshed = true;
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [SizedBox(height: 1200, child: Text('列表'))],
            ),
          ),
        ),
      ),
    );

    await tester.drag(find.byType(ListView), const Offset(0, 360));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(refreshed, isTrue);
  });

  testWidgets('AppRefreshScrollView keeps empty states refreshable', (
    tester,
  ) async {
    await tester.pumpWidget(
      AdaptiveTestHarness(
        width: 390,
        height: 844,
        wrapWithMaterialApp: true,
        child: Scaffold(
          body: AppRefreshScrollView(
            onRefresh: () async {},
            child: const SizedBox(height: 80, child: Text('空状态')),
          ),
        ),
      ),
    );

    expect(find.byType(AppRefreshIndicator), findsOneWidget);
    final listView = tester.widget<ListView>(find.byType(ListView));
    expect(listView.physics, isA<AlwaysScrollableScrollPhysics>());
  });

  testWidgets('AppReorderableList renders keyed items and drag handles', (
    tester,
  ) async {
    final items = ['one', 'two', 'three'];
    var reorderCalled = false;

    await tester.pumpWidget(
      AdaptiveTestHarness(
        width: 600,
        height: 960,
        wrapWithMaterialApp: true,
        child: Scaffold(
          body: SizedBox(
            height: 320,
            child: AppReorderableList(
              itemCount: items.length,
              buildDefaultDragHandles: false,
              onReorder: (_, _) {
                reorderCalled = true;
              },
              itemBuilder: (context, index) {
                final item = items[index];
                return ListTile(
                  key: ValueKey<String>(item),
                  title: Text(item),
                  trailing: AppReorderableDragHandle(index: index),
                );
              },
            ),
          ),
        ),
      ),
    );

    expect(find.byType(ReorderableListView), findsOneWidget);
    expect(find.byType(AppReorderableDragHandle), findsNWidgets(3));
    expect(find.byKey(const ValueKey<String>('one')), findsOneWidget);
    expect(reorderCalled, isFalse);
  });

  testWidgets('AppReorderableList supports 100+ keyed items lazily', (
    tester,
  ) async {
    await tester.pumpWidget(
      AdaptiveTestHarness(
        width: 600,
        height: 960,
        wrapWithMaterialApp: true,
        child: Scaffold(
          body: SizedBox(
            height: 640,
            child: AppReorderableList(
              itemCount: 120,
              buildDefaultDragHandles: false,
              onReorder: (_, _) {},
              itemBuilder: (context, index) {
                return ListTile(
                  key: ValueKey<String>('perf_item_$index'),
                  title: Text('Item $index'),
                  trailing: AppReorderableDragHandle(index: index),
                );
              },
            ),
          ),
        ),
      ),
    );

    expect(find.byType(ReorderableListView), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('perf_item_0')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('perf_item_119')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AppHighlightedText marks matching query spans', (tester) async {
    await tester.pumpWidget(
      const AdaptiveTestHarness(
        width: 390,
        height: 844,
        wrapWithMaterialApp: true,
        child: Scaffold(
          body: AppHighlightedText(
            text: 'Flutter Reading Flutter',
            query: 'flu',
          ),
        ),
      ),
    );

    final text = tester.widget<Text>(find.byType(Text));
    final span = text.textSpan! as TextSpan;
    final children = span.children!.cast<TextSpan>();

    expect(children.where((child) => child.text == 'Flu'), hasLength(2));
    expect(
      children.where((child) => child.text == 'tter Reading '),
      hasLength(1),
    );
  });

  testWidgets('AppImageViewer wraps content with native zoom surface', (
    tester,
  ) async {
    await tester.pumpWidget(
      const AdaptiveTestHarness(
        width: 390,
        height: 844,
        wrapWithMaterialApp: true,
        child: Scaffold(
          body: AppImageViewer(
            child: SizedBox(
              key: ValueKey<String>('preview_image'),
              width: 120,
              height: 160,
            ),
          ),
        ),
      ),
    );

    final viewer = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer),
    );

    expect(viewer.minScale, 1);
    expect(viewer.maxScale, 4);
    expect(find.byKey(const ValueKey<String>('preview_image')), findsOneWidget);
  });
}

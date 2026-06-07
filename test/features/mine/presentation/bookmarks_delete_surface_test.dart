import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/mine/presentation/bookmarks_page.dart';

import '../../../test_utils/adaptive_test_harness.dart';

void main() {
  testWidgets('灵感删除确认在移动端使用底部 surface', (tester) async {
    await tester.pumpWidget(
      AdaptiveTestHarness(
        width: 390,
        height: 844,
        wrapWithMaterialApp: true,
        child: Scaffold(body: _SurfaceLauncher(platform: TargetPlatform.iOS)),
      ),
    );

    await tester.tap(find.text('打开确认'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
    expect(find.text('确认删除'), findsOneWidget);
    expect(find.text('确定要删除选中的 1 条灵感吗？'), findsOneWidget);
  });

  testWidgets('灵感删除确认在桌面端使用 dialog surface', (tester) async {
    await tester.pumpWidget(
      AdaptiveTestHarness(
        width: 840,
        height: 900,
        wrapWithMaterialApp: true,
        child: Scaffold(body: _SurfaceLauncher(platform: TargetPlatform.macOS)),
      ),
    );

    await tester.tap(find.text('打开确认'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('删除所有灵感'), findsOneWidget);
    expect(find.text('确定要删除本书的所有 1 条灵感吗？'), findsOneWidget);
  });
}

class _SurfaceLauncher extends StatelessWidget {
  const _SurfaceLauncher({required this.platform});

  final TargetPlatform platform;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(platform: platform),
      child: Builder(
        builder: (surfaceContext) {
          return Center(
            child: FilledButton(
              onPressed: () {
                showBookmarkDeleteConfirmSurface(
                  context: surfaceContext,
                  title: platform == TargetPlatform.macOS ? '删除所有灵感' : '确认删除',
                  message:
                      platform == TargetPlatform.macOS
                          ? '确定要删除本书的所有 1 条灵感吗？'
                          : '确定要删除选中的 1 条灵感吗？',
                );
              },
              child: const Text('打开确认'),
            ),
          );
        },
      ),
    );
  }
}

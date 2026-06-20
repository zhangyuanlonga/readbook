import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/app/theme/app_advanced_theme_tokens.dart';
import 'package:shuxiang_reading_next/features/bookshelf/presentation/widgets/bookshelf_status_widgets.dart';
import 'package:shuxiang_reading_next/features/mine/presentation/widgets/advanced_theme_basic_section.dart';
import 'package:shuxiang_reading_next/features/mine/presentation/widgets/advanced_theme_list_status_widgets.dart';

import '../../test_utils/adaptive_test_harness.dart';

void main() {
  const cases = <AdaptiveViewportCase>[
    AdaptiveViewportCase(name: 'phone_360', size: Size(360, 800), dpr: 3),
    AdaptiveViewportCase(name: 'phone_390', size: Size(390, 844), dpr: 3),
    AdaptiveViewportCase(name: 'medium_600', size: Size(600, 960), dpr: 2),
    AdaptiveViewportCase(name: 'tablet_840', size: Size(840, 1180), dpr: 2),
    AdaptiveViewportCase(name: 'desktop_1280', size: Size(1280, 800), dpr: 1),
  ];

  for (final item in cases) {
    for (final textScaleFactor in <double>[1.0, 1.3]) {
      testWidgets(
        'UI governance pilot widgets render at ${item.name} textScale=$textScaleFactor',
        (tester) async {
          final titleController = TextEditingController(text: '主题名称');
          addTearDown(titleController.dispose);
          var membershipTapped = false;
          var importTapped = false;
          var retryTapped = false;

          await tester.pumpWidget(
            AdaptiveTestHarness(
              width: item.size.width,
              height: item.size.height,
              dpr: item.dpr,
              textScaleFactor: textScaleFactor,
              wrapWithMaterialApp: true,
              child: Scaffold(
                body: SingleChildScrollView(
                  child: Column(
                    children: [
                      SizedBox(
                        height: 320,
                        child: AdvancedThemeVipLockedState(
                          topInset: 0,
                          onOpenMembership: () {
                            membershipTapped = true;
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: BookshelfEmptyCard(
                          palette: _testPalette,
                          onImportLocal: () {
                            importTapped = true;
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: BookshelfLoadErrorCard(
                          message: '网络暂时不可用',
                          palette: _testPalette,
                          onRetry: () {
                            retryTapped = true;
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: AdvancedThemeEditorTitle(
                          isEditing: true,
                          nameController: titleController,
                          title: '主题名称',
                          onStartEditing: () {},
                          onChanged: (_) {},
                          onSubmitted: (_) {},
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );

          expect(find.text('主题名称'), findsOneWidget);
          expect(find.text('导入本地图书'), findsOneWidget);
          expect(find.text('网络暂时不可用'), findsOneWidget);
          expect(tester.takeException(), isNull);

          await tester.ensureVisible(find.text('前往会员页'));
          await tester.tap(find.text('前往会员页'));
          await tester.ensureVisible(find.text('导入本地图书'));
          await tester.tap(find.text('导入本地图书'));
          await tester.ensureVisible(find.text('重试'));
          await tester.tap(find.text('重试'));

          expect(membershipTapped, isTrue);
          expect(importTapped, isTrue);
          expect(retryTapped, isTrue);
        },
      );
    }
  }
}

const _testPalette = ResolvedAdvancedThemePalette(
  backgroundColor: Color(0xFFFFFFFF),
  surfaceColor: Color(0xFFFFFFFF),
  searchFieldBackgroundColor: Color(0xFFF4F6F8),
  elevatedSurfaceColor: Color(0xFFFFFFFF),
  cardColor: Color(0xFFFFFFFF),
  cardTextColor: Color(0xFF151A20),
  cardBorderColor: Color(0xFFD8DEE6),
  dividerColor: Color(0xFFD8DEE6),
  outlineColor: Color(0xFFD8DEE6),
  iconBackgroundColor: Color(0xFFE8F0FE),
  textPrimaryColor: Color(0xFF151A20),
  textSecondaryColor: Color(0xFF5F6B7A),
  primaryColor: Color(0xFF3367D6),
  primaryContainerColor: Color(0xFFDCE7FF),
  secondaryColor: Color(0xFF4F6F8F),
  buttonTextColor: Color(0xFFFFFFFF),
  shadowColor: Color(0x33000000),
  noticeAccentColor: Color(0xFF7A5C00),
  noticeSurfaceColor: Color(0xFFFFF4D6),
);

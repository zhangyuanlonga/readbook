import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/reader_settings.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_layout_resolver.dart';
import 'package:shuxiang_reading_next/features/reader/presentation/widgets/chrome/reader_chrome_widgets.dart';

void main() {
  group('ReaderInfoBar', () {
    testWidgets('renders md3-style leading and trailing slots', (tester) async {
      const palette = ReaderChromePalette(
        background: Colors.white,
        text: Colors.black,
        meta: Colors.black54,
        divider: Colors.black12,
        overlay: Colors.white,
      );
      const model = ReaderInfoBarModel(
        leadingItems: <ReaderInfoBarItemData>[
          ReaderInfoBarItemData.text('12:30'),
        ],
        centerItems: <ReaderInfoBarItemData>[
          ReaderInfoBarItemData.text(
            '第一章 山雨欲来',
            role: ReaderInfoBarTextRole.primary,
            expand: true,
          ),
        ],
        trailingItems: <ReaderInfoBarItemData>[
          ReaderInfoBarItemData.battery(
            batteryLevel: 64,
            batteryReadFailed: false,
          ),
          ReaderInfoBarItemData.text(
            '12/20 · 43%',
            role: ReaderInfoBarTextRole.primary,
          ),
        ],
        placement: ReaderInfoBarPlacement.footer,
        role: ReaderChromeRole.pagedFooter,
        outerPadding: EdgeInsets.zero,
        innerHorizontalPadding: 12,
        showDivider: true,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ReaderInfoBar(model: model, palette: palette)),
        ),
      );

      expect(find.text('12:30'), findsOneWidget);
      expect(find.text('第一章 山雨欲来'), findsOneWidget);
      expect(find.text('64%'), findsOneWidget);
      expect(find.text('12/20 · 43%'), findsOneWidget);
      expect(find.byIcon(Icons.battery_5_bar_rounded), findsOneWidget);
    });

    test('applies extra outer padding from settings factory', () {
      final model = ReaderInfoBarModel.fromSettings(
        settings: const ReaderSettings(
          infoFooterPadding: 9,
          infoFooterMarginTop: 2,
          infoFooterMarginBottom: 4,
          infoFooterMarginLeft: 6,
          infoFooterMarginRight: 8,
        ),
        layoutResolver: const ReaderLayoutResolver(),
        placement: ReaderInfoBarPlacement.footer,
        role: ReaderChromeRole.scrollFooter,
        trailingItems: const <ReaderInfoBarItemData>[
          ReaderInfoBarItemData.text('进度 50%'),
        ],
        extraOuterPadding: const EdgeInsets.only(bottom: 18),
      );

      expect(model.outerPadding, const EdgeInsets.fromLTRB(6, 2, 8, 22));
      expect(model.hasContent, isTrue);
    });
  });
}

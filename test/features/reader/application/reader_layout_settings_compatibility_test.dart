import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_layout_settings_compatibility.dart';

void main() {
  group('ReaderLayoutSettingsCompatibilityMatrix', () {
    test('tracks typography and geometry settings in layout signature', () {
      for (final key in <String>[
        'fontSize',
        'lineHeight',
        'paragraphSpacing',
        'paragraphIndent',
        'letterSpacing',
        'pagePadding',
        'horizontalPadding',
        'fontIdentity',
        'fontSource',
        'systemFontPreset',
        'fontFamilyKey',
        'customFontPath',
        'fontWeightLevel',
        'fontWeightValue',
        'bodyTextItalicEnabled',
        'textFullJustifyEnabled',
        'textBottomJustifyEnabled',
        'zhLayoutPolicy',
        'bodyMarginMode',
        'bodyMarginPreset',
        'bodyMarginTop',
        'bodyMarginBottom',
        'bodyMarginLeft',
        'bodyMarginRight',
        'showChapterHeader',
        'chapterHeaderMode',
        'chapterHeaderTopSpacing',
        'chapterHeaderBottomSpacing',
      ]) {
        expect(
          ReaderLayoutSettingsCompatibilityMatrix.isTrackedInLayoutSignature(
            key,
          ),
          isTrue,
          reason: key,
        );
      }
    });

    test(
      'keeps shell and page-turn owned settings out of layout signature',
      () {
        final shellOwned = ReaderLayoutSettingsCompatibilityMatrix.byStatus(
          ReaderLayoutSettingCompatibilityStatus.shellOwned,
        );
        final interactionOwned =
            ReaderLayoutSettingsCompatibilityMatrix.byStatus(
              ReaderLayoutSettingCompatibilityStatus.interactionOwned,
            );
        final surfaceOwned = ReaderLayoutSettingsCompatibilityMatrix.byStatus(
          ReaderLayoutSettingCompatibilityStatus.surfaceOwned,
        );
        final visualOnly = ReaderLayoutSettingsCompatibilityMatrix.byStatus(
          ReaderLayoutSettingCompatibilityStatus.visualOnly,
        );
        final pageTurnOwned = ReaderLayoutSettingsCompatibilityMatrix.byStatus(
          ReaderLayoutSettingCompatibilityStatus.pageTurnDelegateFallback,
        );

        expect(
          shellOwned.map((item) => item.key),
          contains('backgroundBrightnessInfoBar'),
        );
        expect(
          pageTurnOwned.map((item) => item.key),
          contains('pageAnimationStyle'),
        );
        expect(
          interactionOwned.map((item) => item.key),
          containsAll(<String>[
            'pageTurnMode',
            'pageTurnStepRatio',
            'tapZoneActions',
            'autoReadMode',
          ]),
        );
        expect(
          surfaceOwned.map((item) => item.key),
          containsAll(<String>['mangaReadMode', 'audioDefaultSpeed']),
        );
        expect(
          visualOnly.map((item) => item.key),
          containsAll(<String>[
            'backgroundStyle',
            'backgroundTone',
            'bodyTextColorValue',
            'bodyTextDecorationStyle',
          ]),
        );
      },
    );

    test(
      'covers the reader setting groups that can affect reader surfaces',
      () {
        for (final key in <String>[
          'brightness',
          'followSystemBrightness',
          'themeMode',
          'infoHeaderEnabled',
          'infoFooterEnabled',
          'infoShowTime',
          'infoShowBattery',
          'infoShowChapter',
          'infoShowProgress',
          'infoHeaderPadding',
          'infoFooterPadding',
          'infoHeaderMarginTop',
          'infoHeaderMarginBottom',
          'infoHeaderMarginLeft',
          'infoHeaderMarginRight',
          'infoFooterMarginTop',
          'infoFooterMarginBottom',
          'infoFooterMarginLeft',
          'infoFooterMarginRight',
          'backgroundImageBase64',
          'bodyTextShadowEnabled',
          'bodyTextShadowBlurRadius',
          'volumeKeyPageEnabled',
          'autoReadEnabled',
          'autoReadSpeed',
          'autoReadSpeedLevel',
          'autoReadPauseMode',
          'autoReadEndBehavior',
          'mangaImageSpacing',
          'mangaImagePadding',
          'mangaLoadStrategy',
          'audioRememberSpeed',
          'audioSeekStepSeconds',
          'audioAutoPlay',
          'switchSourceScoreRankingEnabled',
        ]) {
          expect(
            ReaderLayoutSettingsCompatibilityMatrix.containsKey(key),
            isTrue,
            reason: key,
          );
        }
      },
    );
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/reader_settings.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_settings_groups.dart';

void main() {
  group('ReaderSettingsGroupingService', () {
    const service = ReaderSettingsGroupingService();

    test('splits settings into stable semantic groups', () {
      const settings = ReaderSettings(
        fontSize: 21,
        lineHeight: 1.9,
        paragraphSpacing: 17,
        paragraphIndent: 3,
        letterSpacing: 0.16,
        textFullJustifyEnabled: true,
        fontWeightLevel: ReaderFontWeightLevel.medium,
        fontWeightValue: 700,
        fontSource: ReaderFontSource.custom,
        systemFontPreset: ReaderSystemFontPreset.serif,
        fontFamilyKey: 'reader_font',
        customFontPath: '/tmp/reader_font.ttf',
        bodyMarginTop: 10,
        bodyMarginBottom: 12,
        bodyMarginLeft: 14,
        bodyMarginRight: 16,
        infoHeaderEnabled: true,
        infoFooterEnabled: true,
        infoShowTime: true,
        infoShowBattery: true,
        infoShowChapter: true,
        infoShowProgress: false,
        infoHeaderPadding: 11,
        infoFooterPadding: 9,
        infoHeaderDividerEnabled: true,
        infoFooterDividerEnabled: false,
        infoHeaderMarginTop: 1,
        infoHeaderMarginBottom: 2,
        infoHeaderMarginLeft: 3,
        infoHeaderMarginRight: 4,
        infoFooterMarginTop: 5,
        infoFooterMarginBottom: 6,
        infoFooterMarginLeft: 7,
        infoFooterMarginRight: 8,
        showChapterHeader: true,
        chapterHeaderHorizontalOffset: 0.3,
        chapterHeaderVerticalOffset: 22,
        backgroundStyle: ReaderBackgroundStyle.warm,
        backgroundTone: ReaderBackgroundTone.amberGoldTint,
        backgroundImageBase64: 'bg',
        bodyTextColorValue: 0xFF123456,
        bodyTextItalicEnabled: true,
        bodyTextShadowEnabled: true,
        bodyTextShadowColorValue: 0x88224466,
        bodyTextShadowBlurRadius: 6,
        bodyTextShadowOffsetDx: 1,
        bodyTextShadowOffsetDy: -2,
        bodyTextDecorationStyle: ReaderBodyTextDecorationStyle.dashed,
        bodyTextDecorationColorValue: 0xFF3366CC,
        bodyTextUnderlineThickness: 3,
        bodyTextUnderlineGap: 4,
        bodyTextUnderlineDashLength: 5,
        bodyTextUnderlineDashGapRatio: 6,
        pageTurnMode: ReaderPageTurnMode.scroll,
        pageAnimationStyle: ReaderPageAnimationStyle.cover,
        pageTurnStepRatio: 0.7,
        volumeKeyPageEnabled: false,
        autoReadEnabled: true,
        autoReadSpeed: 80,
        autoReadMode: ReaderAutoReadMode.page,
        autoReadSpeedLevel: 8,
        autoReadPauseMode: ReaderAutoReadPauseMode.chapterEnd,
        autoReadEndBehavior: ReaderAutoReadEndBehavior.nextBook,
        audioDefaultSpeed: 1.35,
        audioRememberSpeed: false,
        audioSeekStepSeconds: 30,
        audioAutoPlay: true,
        mangaReadMode: ReaderMangaReadMode.paged,
        mangaImageSpacing: 18,
        mangaImagePadding: 12,
        mangaLoadStrategy: ReaderMangaLoadStrategy.smooth,
      );

      final groups = service.split(settings);

      expect(groups.typography.fontSize, 21);
      expect(groups.typography.paragraphSpacing, 17);
      expect(groups.typography.letterSpacing, closeTo(0.16, 0.0001));
      expect(groups.typography.fontFamilyKey, 'reader_font');
      expect(groups.bodyLayout.bodyMarginLeft, 14);
      expect(groups.chapterHeader.showChapterHeader, isTrue);
      expect(groups.chapterHeader.horizontalOffset, 0.3);
      expect(groups.chapterHeader.verticalOffset, 22);
      expect(groups.infoBar.infoHeaderEnabled, isTrue);
      expect(groups.infoBar.infoFooterMarginRight, 8);
      expect(
        groups.visualDecoration.backgroundStyle,
        ReaderBackgroundStyle.warm,
      );
      expect(
        groups.visualDecoration.bodyTextDecorationStyle,
        ReaderBodyTextDecorationStyle.dashed,
      );
      expect(groups.pageTurn.pageTurnMode, ReaderPageTurnMode.scroll);
      expect(
        groups.pageTurn.pageAnimationStyle,
        ReaderPageAnimationStyle.cover,
      );
      expect(groups.pageTurn.pageTurnStepRatio, closeTo(0.7, 0.0001));
      expect(groups.pageTurn.volumeKeyPageEnabled, isFalse);
      expect(groups.autoRead.enabled, isTrue);
      expect(groups.autoRead.mode, ReaderAutoReadMode.page);
      expect(groups.autoRead.pauseMode, ReaderAutoReadPauseMode.chapterEnd);
      expect(groups.autoRead.endBehavior, ReaderAutoReadEndBehavior.nextBook);
      expect(groups.audio.defaultSpeed, closeTo(1.35, 0.0001));
      expect(groups.audio.rememberSpeed, isFalse);
      expect(groups.audio.seekStepSeconds, 30);
      expect(groups.audio.autoPlay, isTrue);
      expect(groups.manga.readMode, ReaderMangaReadMode.paged);
      expect(groups.manga.imageSpacing, 18);
      expect(groups.manga.imagePadding, 12);
      expect(groups.manga.loadStrategy, ReaderMangaLoadStrategy.smooth);
    });

    test('merges grouped settings back without losing unrelated fields', () {
      const base = ReaderSettings(
        brightness: 0.65,
        autoReadEnabled: true,
        pageTurnMode: ReaderPageTurnMode.tapAndSwipe,
      );

      final merged = service.merge(
        base: base,
        typography: const ReaderTypographySettings(
          fontSize: 20,
          lineHeight: 1.8,
          paragraphSpacing: 15,
          paragraphIndent: 2,
          letterSpacing: 0.12,
          textFullJustifyEnabled: true,
          textBottomJustifyEnabled: true,
          fontWeightLevel: ReaderFontWeightLevel.medium,
          fontWeightValue: 600,
          fontSource: ReaderFontSource.system,
          systemFontPreset: ReaderSystemFontPreset.serif,
          fontFamilyKey: null,
          customFontPath: null,
        ),
        bodyLayout: const ReaderBodyLayoutSettings(
          bodyMarginTop: 8,
          bodyMarginBottom: 9,
          bodyMarginLeft: 10,
          bodyMarginRight: 11,
        ),
        chapterHeader: const ReaderChapterHeaderSettings(
          showChapterHeader: true,
          horizontalOffset: 0.5,
          verticalOffset: 18,
        ),
        pageTurn: const ReaderPageTurnSettings(
          pageTurnMode: ReaderPageTurnMode.scroll,
          pageAnimationStyle: ReaderPageAnimationStyle.fade,
          pageTurnStepRatio: 0.75,
          volumeKeyPageEnabled: false,
        ),
        autoRead: const ReaderAutoReadSettings(
          enabled: false,
          speed: 90,
          mode: ReaderAutoReadMode.page,
          speedLevel: 9,
          pauseMode: ReaderAutoReadPauseMode.chapterEnd,
          endBehavior: ReaderAutoReadEndBehavior.nextBook,
        ),
        audio: const ReaderAudioSettings(
          defaultSpeed: 1.25,
          rememberSpeed: false,
          seekStepSeconds: 20,
          autoPlay: true,
        ),
        manga: const ReaderMangaSettings(
          readMode: ReaderMangaReadMode.paged,
          imageSpacing: 14,
          imagePadding: 10,
          loadStrategy: ReaderMangaLoadStrategy.smooth,
        ),
      );

      expect(merged.brightness, 0.65);
      expect(merged.fontSize, 20);
      expect(merged.bodyMarginRight, 11);
      expect(merged.showChapterHeader, isTrue);
      expect(merged.chapterHeaderHorizontalOffset, 0.5);
      expect(merged.chapterHeaderVerticalOffset, 18);
      expect(merged.pageTurnMode, ReaderPageTurnMode.scroll);
      expect(merged.pageAnimationStyle, ReaderPageAnimationStyle.fade);
      expect(merged.pageTurnStepRatio, closeTo(0.75, 0.0001));
      expect(merged.volumeKeyPageEnabled, isFalse);
      expect(merged.autoReadEnabled, isFalse);
      expect(merged.autoReadSpeed, closeTo(90, 0.0001));
      expect(merged.autoReadMode, ReaderAutoReadMode.page);
      expect(merged.autoReadSpeedLevel, 9);
      expect(merged.autoReadPauseMode, ReaderAutoReadPauseMode.chapterEnd);
      expect(merged.autoReadEndBehavior, ReaderAutoReadEndBehavior.nextBook);
      expect(merged.audioDefaultSpeed, closeTo(1.25, 0.0001));
      expect(merged.audioRememberSpeed, isFalse);
      expect(merged.audioSeekStepSeconds, 20);
      expect(merged.audioAutoPlay, isTrue);
      expect(merged.mangaReadMode, ReaderMangaReadMode.paged);
      expect(merged.mangaImageSpacing, 14);
      expect(merged.mangaImagePadding, 10);
      expect(merged.mangaLoadStrategy, ReaderMangaLoadStrategy.smooth);
    });

    test(
      'exposes grouped access without changing serialized settings shape',
      () {
        const settings = ReaderSettings(
          fontSize: 22,
          pageAnimationStyle: ReaderPageAnimationStyle.translate,
          audioAutoPlay: true,
        );

        final grouped = settings.grouped;
        final merged = settings.mergeGroups(
          pageTurn: ReaderPageTurnSettings(
            pageTurnMode: grouped.pageTurn.pageTurnMode,
            pageAnimationStyle: ReaderPageAnimationStyle.cover,
            pageTurnStepRatio: grouped.pageTurn.pageTurnStepRatio,
            volumeKeyPageEnabled: grouped.pageTurn.volumeKeyPageEnabled,
          ),
        );

        expect(grouped.typography.fontSize, 22);
        expect(
          grouped.pageTurn.pageAnimationStyle,
          ReaderPageAnimationStyle.translate,
        );
        expect(grouped.audio.autoPlay, isTrue);
        expect(merged.pageAnimationStyle, ReaderPageAnimationStyle.cover);
        expect(merged.fontSize, 22);

        final serialized = merged.toJson();
        expect(serialized.containsKey('pageAnimationStyle'), isTrue);
        expect(serialized.containsKey('grouped'), isFalse);
        expect(serialized.containsKey('pageTurn'), isFalse);
        expect(serialized['pageAnimationStyle'], 'cover');
      },
    );
  });
}

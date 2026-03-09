import 'package:flutter_appread/domain/entities/reader_settings.dart';
import 'package:flutter_appread/domain/entities/reading_progress.dart';
import 'package:flutter_appread/features/reader/application/reader_preferences_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ReaderPreferencesService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('saves and loads reader settings', () async {
      final service = ReaderPreferencesService();
      final settings = const ReaderSettings(
        fontSize: 22,
        lineHeight: 1.9,
        horizontalPadding: 24,
        paragraphSpacing: 18,
        paragraphIndent: 4,
        letterSpacing: 0.12,
        brightness: 0.75,
        themeMode: ReaderThemeMode.sepia,
        pageTurnMode: ReaderPageTurnMode.tapAndSwipe,
        autoReadEnabled: true,
        autoReadSpeed: 66,
        backgroundStyle: ReaderBackgroundStyle.paper,
        pageTurnStepRatio: 0.72,
        fontWeightLevel: ReaderFontWeightLevel.medium,
        fontSource: ReaderFontSource.custom,
        fontFamilyKey: 'reader_custom_foo',
        customFontPath: '/tmp/reader_custom_foo.ttf',
        pageAnimationStyle: ReaderPageAnimationStyle.cover,
        backgroundImageBase64: 'dGVzdF9iZw==',
        mangaReadMode: ReaderMangaReadMode.horizontal,
        mangaImageSpacing: 14,
        mangaImagePadding: 12,
        mangaLoadStrategy: ReaderMangaLoadStrategy.saveData,
        switchSourceScoreRankingEnabled: false,
        infoHeaderEnabled: true,
        infoFooterEnabled: true,
        infoShowTime: true,
        infoShowBattery: true,
        infoShowChapter: true,
        infoShowProgress: false,
        infoHeaderPadding: 13,
        infoFooterPadding: 9,
        infoHeaderDividerEnabled: false,
        infoFooterDividerEnabled: true,
        infoHeaderMarginTop: 2,
        infoHeaderMarginBottom: 1,
        infoHeaderMarginLeft: 14,
        infoHeaderMarginRight: 18,
        bodyMarginTop: 8,
        bodyMarginBottom: 11,
        bodyMarginLeft: 19,
        bodyMarginRight: 21,
        infoFooterMarginTop: 7,
        infoFooterMarginBottom: 3,
        infoFooterMarginLeft: 15,
        infoFooterMarginRight: 17,
      );

      await service.saveSettings(settings);
      final restored = await service.loadSettings();

      expect(restored.fontSize, 22);
      expect(restored.lineHeight, 1.9);
      expect(restored.horizontalPadding, 24);
      expect(restored.paragraphSpacing, 18);
      expect(restored.paragraphIndent, 4);
      expect(restored.letterSpacing, closeTo(0.12, 0.0001));
      expect(restored.brightness, 0.75);
      expect(restored.themeMode, ReaderThemeMode.sepia);
      expect(restored.pageTurnMode, ReaderPageTurnMode.tapAndSwipe);
      expect(restored.autoReadEnabled, isTrue);
      expect(restored.autoReadSpeed, 66);
      expect(restored.backgroundStyle, ReaderBackgroundStyle.paper);
      expect(restored.pageTurnStepRatio, 0.72);
      expect(restored.fontWeightLevel, ReaderFontWeightLevel.medium);
      expect(restored.fontSource, ReaderFontSource.custom);
      expect(restored.fontFamilyKey, 'reader_custom_foo');
      expect(restored.customFontPath, '/tmp/reader_custom_foo.ttf');
      expect(restored.pageAnimationStyle, ReaderPageAnimationStyle.cover);
      expect(restored.backgroundImageBase64, 'dGVzdF9iZw==');
      expect(restored.mangaReadMode, ReaderMangaReadMode.horizontal);
      expect(restored.mangaImageSpacing, 14);
      expect(restored.mangaImagePadding, 12);
      expect(restored.mangaLoadStrategy, ReaderMangaLoadStrategy.saveData);
      expect(restored.switchSourceScoreRankingEnabled, isFalse);
      expect(restored.infoHeaderEnabled, isTrue);
      expect(restored.infoFooterEnabled, isTrue);
      expect(restored.infoShowTime, isTrue);
      expect(restored.infoShowBattery, isTrue);
      expect(restored.infoShowChapter, isTrue);
      expect(restored.infoShowProgress, isFalse);
      expect(restored.infoHeaderPadding, 13);
      expect(restored.infoFooterPadding, 9);
      expect(restored.infoHeaderDividerEnabled, isFalse);
      expect(restored.infoFooterDividerEnabled, isTrue);
      expect(restored.infoHeaderMarginTop, 2);
      expect(restored.infoHeaderMarginBottom, 1);
      expect(restored.infoHeaderMarginLeft, 14);
      expect(restored.infoHeaderMarginRight, 18);
      expect(restored.bodyMarginTop, 8);
      expect(restored.bodyMarginBottom, 11);
      expect(restored.bodyMarginLeft, 19);
      expect(restored.bodyMarginRight, 21);
      expect(restored.infoFooterMarginTop, 7);
      expect(restored.infoFooterMarginBottom, 3);
      expect(restored.infoFooterMarginLeft, 15);
      expect(restored.infoFooterMarginRight, 17);
    });

    test('saves and loads reading progress', () async {
      final service = ReaderPreferencesService();
      final progress = ReadingProgress(
        bookId: 'book_1',
        sourceId: 'src_1',
        detailUrl: 'https://example.com/book/1',
        chapterId: 'chapter_1',
        chapterUrl: 'https://example.com/book/1/chapter/1',
        chapterTitle: '第一章',
        chapterIndex: 0,
        updatedAt: DateTime.parse('2026-02-12T12:00:00.000Z'),
        chapterPositionRatio: 0.63,
      );

      await service.saveProgress(progress);
      final restored = await service.loadProgress('book_1');

      expect(restored, isNotNull);
      expect(restored!.bookId, 'book_1');
      expect(restored.chapterTitle, '第一章');
      expect(restored.chapterIndex, 0);
      expect(restored.chapterPositionRatio, 0.63);
    });

    test('loads legacy progress payload without position ratio', () async {
      SharedPreferences.setMockInitialValues({
        'reader.progress.book_legacy':
            '{"bookId":"book_legacy","sourceId":"src_legacy","detailUrl":"https://example.com/book/legacy","chapterId":"chapter_1","chapterUrl":"https://example.com/book/legacy/1","chapterTitle":"第一章","chapterIndex":1,"updatedAt":"2026-02-12T12:00:00.000Z"}',
      });

      final service = ReaderPreferencesService();
      final restored = await service.loadProgress('book_legacy');

      expect(restored, isNotNull);
      expect(restored!.chapterPositionRatio, 0);
    });
  });
}

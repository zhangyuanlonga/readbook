import 'dart:io';

import 'package:drift/native.dart';
import 'package:shuxiang_reading_next/core/storage/managed_asset_store.dart';
import 'package:shuxiang_reading_next/data/datasources/local/app_database.dart';
import 'package:shuxiang_reading_next/domain/entities/reader_settings.dart';
import 'package:shuxiang_reading_next/domain/entities/reader_logical_position.dart';
import 'package:shuxiang_reading_next/domain/entities/reading_progress.dart';
import 'package:shuxiang_reading_next/domain/entities/reader_toc_snapshot.dart';
import 'package:shuxiang_reading_next/domain/entities/chapter.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_preferences_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReaderPreferencesService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('saves and loads reader settings', () async {
      final service = await _createService();
      final settings = const ReaderSettings(
        fontSize: 22,
        lineHeight: 1.9,
        horizontalPadding: 24,
        paragraphSpacing: 18,
        paragraphIndent: 4,
        letterSpacing: 0.12,
        brightness: 0.75,
        followSystemBrightness: true,
        themeMode: ReaderThemeMode.sepia,
        pageTurnMode: ReaderPageTurnMode.tapAndSwipe,
        autoReadEnabled: true,
        autoReadSpeed: 66,
        autoReadMode: ReaderAutoReadMode.page,
        autoReadSpeedLevel: 6,
        autoReadPauseMode: ReaderAutoReadPauseMode.chapterEnd,
        autoReadEndBehavior: ReaderAutoReadEndBehavior.loopBook,
        audioDefaultSpeed: 1.5,
        audioRememberSpeed: false,
        audioSeekStepSeconds: 30,
        audioAutoPlay: true,
        backgroundStyle: ReaderBackgroundStyle.paper,
        pageTurnStepRatio: 0.72,
        fontWeightLevel: ReaderFontWeightLevel.medium,
        fontWeightValue: 700,
        fontSource: ReaderFontSource.custom,
        systemFontPreset: ReaderSystemFontPreset.monospace,
        fontFamilyKey: 'reader_custom_foo',
        customFontPath: '/tmp/reader_custom_foo.ttf',
        bodyTextItalicEnabled: true,
        bodyTextShadowEnabled: true,
        bodyTextShadowColorValue: 0x88224466,
        bodyTextShadowBlurRadius: 12,
        bodyTextShadowOffsetDx: 2,
        bodyTextShadowOffsetDy: -1,
        pageAnimationStyle: ReaderPageAnimationStyle.cover,
        backgroundImageBase64: 'dGVzdF9iZw==',
        bodyTextDecorationStyle: ReaderBodyTextDecorationStyle.dashed,
        bodyTextDecorationColorValue: 0xFF3366CC,
        bodyTextUnderlineThickness: 3.5,
        bodyTextUnderlineGap: 4,
        bodyTextUnderlineDashLength: 9,
        bodyTextUnderlineDashGapRatio: 5,
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
        showChapterHeader: true,
        chapterHeaderHorizontalOffset: 0.42,
        chapterHeaderVerticalOffset: 24,
      );

      await service.saveSettings(settings);
      final restored = await service.loadSettings();

      expect(restored.fontSize, 22);
      expect(restored.lineHeight, 1.9);
      expect(restored.horizontalPadding, 20);
      expect(restored.paragraphSpacing, 18);
      expect(restored.paragraphIndent, 4);
      expect(restored.letterSpacing, closeTo(0.12, 0.0001));
      expect(restored.brightness, 0.75);
      expect(restored.followSystemBrightness, isTrue);
      expect(restored.themeMode, ReaderThemeMode.sepia);
      expect(restored.pageTurnMode, ReaderPageTurnMode.tapAndSwipe);
      expect(restored.autoReadEnabled, isTrue);
      expect(restored.autoReadSpeed, 66);
      expect(restored.autoReadMode, ReaderAutoReadMode.page);
      expect(restored.autoReadSpeedLevel, 6);
      expect(restored.autoReadPauseMode, ReaderAutoReadPauseMode.chapterEnd);
      expect(restored.autoReadEndBehavior, ReaderAutoReadEndBehavior.loopBook);
      expect(restored.audioDefaultSpeed, 1.5);
      expect(restored.audioRememberSpeed, isFalse);
      expect(restored.audioSeekStepSeconds, 30);
      expect(restored.audioAutoPlay, isTrue);
      expect(restored.backgroundStyle, ReaderBackgroundStyle.paper);
      expect(restored.pageTurnStepRatio, 0.72);
      expect(restored.fontWeightLevel, ReaderFontWeightLevel.medium);
      expect(restored.fontWeightValue, 700);
      expect(restored.fontSource, ReaderFontSource.custom);
      expect(restored.systemFontPreset, ReaderSystemFontPreset.monospace);
      expect(restored.fontFamilyKey, 'reader_custom_foo');
      expect(restored.customFontPath, '/tmp/reader_custom_foo.ttf');
      expect(restored.bodyTextItalicEnabled, isTrue);
      expect(restored.bodyTextShadowEnabled, isTrue);
      expect(restored.bodyTextShadowColorValue, 0x88224466);
      expect(restored.bodyTextShadowBlurRadius, 12);
      expect(restored.bodyTextShadowOffsetDx, 2);
      expect(restored.bodyTextShadowOffsetDy, -1);
      expect(restored.pageAnimationStyle, ReaderPageAnimationStyle.cover);
      expect(restored.backgroundImageBase64, 'dGVzdF9iZw==');
      expect(
        restored.bodyTextDecorationStyle,
        ReaderBodyTextDecorationStyle.dashed,
      );
      expect(restored.bodyTextDecorationColorValue, 0xFF3366CC);
      expect(restored.bodyTextUnderlineThickness, 3.5);
      expect(restored.bodyTextUnderlineGap, 4);
      expect(restored.bodyTextUnderlineDashLength, 9);
      expect(restored.bodyTextUnderlineDashGapRatio, 5);
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
      expect(restored.showChapterHeader, isTrue);
      expect(restored.chapterHeaderHorizontalOffset, closeTo(0.42, 0.0001));
      expect(restored.chapterHeaderVerticalOffset, 24);
    });

    test('tracks whether auto read has been configured', () async {
      final service = await _createService();

      expect(await service.loadAutoReadConfigured(), isFalse);

      await service.saveAutoReadConfigured(true);

      expect(await service.loadAutoReadConfigured(), isTrue);
    });

    test('tracks whether toolbar hint has been shown', () async {
      final service = await _createService();

      expect(await service.loadToolbarHintShown(), isFalse);

      await service.saveToolbarHintShown(true);

      expect(await service.loadToolbarHintShown(), isTrue);
    });

    test('tracks whether tap zone guide has been shown', () async {
      final service = await _createService();

      expect(await service.loadTapZoneGuideShown(), isFalse);

      await service.saveTapZoneGuideShown(true);

      expect(await service.loadTapZoneGuideShown(), isTrue);
    });

    test('ignores legacy layout fields when loading settings', () async {
      SharedPreferences.setMockInitialValues({
        'reader.settings.bodyMarginMode': 'preset',
        'reader.settings.bodyMarginPreset': 'relaxed',
        'reader.settings.horizontalPadding': 30.0,
        'reader.settings.chapterHeaderMode': 'center',
        'reader.settings.chapterHeaderTopSpacing': 12.0,
        'reader.settings.chapterHeaderBottomSpacing': 6.0,
        'reader.settings.pinnedChapterHeaderOffsetX': 80.0,
        'reader.settings.pinnedChapterHeaderOffsetY': 18.0,
      });

      final service = await _createService();
      final restored = await service.loadSettings();

      expect(restored.bodyMarginTop, 6);
      expect(restored.bodyMarginBottom, 6);
      expect(restored.bodyMarginLeft, 16);
      expect(restored.bodyMarginRight, 16);
      expect(restored.showChapterHeader, isTrue);
      expect(restored.chapterHeaderHorizontalOffset, 0);
      expect(restored.chapterHeaderVerticalOffset, 0);
    });

    test(
      'preserves negative chapter header vertical offset after reload',
      () async {
        final service = await _createService();

        await service.saveSettings(
          const ReaderSettings(chapterHeaderVerticalOffset: -18),
        );

        final restored = await service.loadSettings();

        expect(restored.chapterHeaderVerticalOffset, -18);
      },
    );

    test('preserves wide footer horizontal margins after reload', () async {
      final service = await _createService();

      await service.saveSettings(
        const ReaderSettings(
          infoFooterMarginLeft: 72,
          infoFooterMarginRight: 80,
        ),
      );

      final restored = await service.loadSettings();

      expect(restored.infoFooterMarginLeft, 72);
      expect(restored.infoFooterMarginRight, 80);
    });

    test('saving settings clears legacy storage keys', () async {
      SharedPreferences.setMockInitialValues({
        'reader.settings.bodyMarginMode': 'preset',
        'reader.settings.bodyMarginPreset': 'relaxed',
        'reader.settings.chapterHeaderMode': 'center',
        'reader.settings.chapterHeaderTopSpacing': 12.0,
        'reader.settings.chapterHeaderBottomSpacing': 6.0,
        'reader.settings.pinnedChapterHeaderOffsetX': 80.0,
        'reader.settings.pinnedChapterHeaderOffsetY': 18.0,
      });

      final service = await _createService();
      await service.saveSettings(
        const ReaderSettings(
          bodyMarginTop: 7,
          bodyMarginBottom: 9,
          bodyMarginLeft: 15,
          bodyMarginRight: 17,
          showChapterHeader: true,
          chapterHeaderHorizontalOffset: 0.4,
          chapterHeaderVerticalOffset: 10,
        ),
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('reader.settings.bodyMarginMode'), isFalse);
      expect(prefs.containsKey('reader.settings.bodyMarginPreset'), isFalse);
      expect(prefs.containsKey('reader.settings.horizontalPadding'), isFalse);
      expect(prefs.containsKey('reader.settings.chapterHeaderMode'), isFalse);
      expect(
        prefs.containsKey('reader.settings.chapterHeaderTopSpacing'),
        isFalse,
      );
      expect(
        prefs.containsKey('reader.settings.chapterHeaderBottomSpacing'),
        isFalse,
      );
      expect(
        prefs.containsKey('reader.settings.pinnedChapterHeaderOffsetX'),
        isFalse,
      );
      expect(
        prefs.containsKey('reader.settings.pinnedChapterHeaderOffsetY'),
        isFalse,
      );
    });

    test('saves and loads reading progress', () async {
      final service = await _createService();
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
        logicalPosition: const ReaderLogicalPosition(
          chapterIndex: 0,
          blockIndex: 4,
          offsetInBlock: 9,
          chapterPositionRatio: 0.63,
        ),
      );

      await service.saveProgress(progress);
      final restored = await service.loadProgress('book_1');

      expect(restored, isNotNull);
      expect(restored!.bookId, 'book_1');
      expect(restored.chapterTitle, '第一章');
      expect(restored.chapterIndex, 0);
      expect(restored.chapterPositionRatio, 0.63);
      expect(restored.logicalPosition, isNotNull);
      expect(restored.logicalPosition!.blockIndex, 4);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('reader.progress.book_1'), isFalse);
    });

    test('migrates reading progress to a new book identity', () async {
      final service = await _createService();
      final progress = ReadingProgress(
        bookId: 'book_old',
        sourceId: 'src_old',
        detailUrl: 'https://example.com/book/old',
        chapterId: 'chapter_1',
        chapterUrl: 'https://example.com/book/old/chapter/1',
        chapterTitle: '第一章',
        chapterIndex: 0,
        updatedAt: DateTime.parse('2026-02-12T12:00:00.000Z'),
        chapterPositionRatio: 0.63,
      );

      await service.saveProgress(progress);
      await service.migrateProgress(
        previousBookId: 'book_old',
        nextProgress: ReadingProgress(
          bookId: 'book_new',
          sourceId: 'src_new',
          detailUrl: 'https://example.com/book/new',
          chapterId: 'chapter_2',
          chapterUrl: 'https://example.com/book/new/chapter/2',
          chapterTitle: '第二章',
          chapterIndex: 1,
          updatedAt: DateTime.parse('2026-02-12T13:00:00.000Z'),
          chapterPositionRatio: 0.22,
        ),
      );

      final oldProgress = await service.loadProgress('book_old');
      final newProgress = await service.loadProgress('book_new');

      expect(oldProgress, isNull);
      expect(newProgress, isNotNull);
      expect(newProgress!.sourceId, 'src_new');
      expect(newProgress.chapterTitle, '第二章');
      expect(newProgress.chapterIndex, 1);
    });

    test('rejects legacy progress payload without position ratio', () async {
      SharedPreferences.setMockInitialValues({
        'reader.progress.book_legacy':
            '{"bookId":"book_legacy","sourceId":"src_legacy","detailUrl":"https://example.com/book/legacy","chapterId":"chapter_1","chapterUrl":"https://example.com/book/legacy/1","chapterTitle":"第一章","chapterIndex":1,"updatedAt":"2026-02-12T12:00:00.000Z"}',
      });

      final service = await _createService();
      final restored = await service.loadProgress('book_legacy');

      expect(restored, isNull);
    });

    test(
      'migrates legacy progress payload from SharedPreferences to database',
      () async {
        SharedPreferences.setMockInitialValues({
          'reader.progress.book_legacy':
              '{"bookId":"book_legacy","sourceId":"src_legacy","detailUrl":"https://example.com/book/legacy","chapterId":"chapter_1","chapterUrl":"https://example.com/book/legacy/1","chapterTitle":"第一章","chapterIndex":1,"updatedAt":"2026-02-12T12:00:00.000Z","chapterPositionRatio":0.4}',
        });

        final service = await _createService();
        final restored = await service.loadProgress('book_legacy');

        expect(restored, isNotNull);
        expect(restored!.chapterPositionRatio, 0.4);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.containsKey('reader.progress.book_legacy'), isFalse);

        final restoredAgain = await service.loadProgress('book_legacy');
        expect(restoredAgain, isNotNull);
        expect(restoredAgain!.chapterTitle, '第一章');
      },
    );

    test('ignores legacy single background image key', () async {
      SharedPreferences.setMockInitialValues({
        'reader.settings.customBackgroundImageBase64': 'legacy_background',
      });

      final service = await _createService();
      final restored = await service.loadCustomBackgroundImages();

      expect(restored, isEmpty);
    });

    test('saves and loads toc snapshot', () async {
      final service = await _createService();
      final snapshot = ReaderTocSnapshot(
        bookId: 'book_1',
        sourceId: 'src_1',
        detailUrl: 'https://example.com/book/1',
        title: '测试书籍',
        author: '作者甲',
        coverUrl: 'https://example.com/cover.jpg',
        chapters: const [
          Chapter(
            id: 'volume_1',
            bookId: 'book_1',
            title: '第一卷',
            chapterUrl: '',
            index: 0,
            isVolume: true,
          ),
          Chapter(
            id: 'chapter_2',
            bookId: 'book_1',
            title: '第一章',
            chapterUrl: 'https://example.com/book/1/chapter/1',
            index: 1,
          ),
        ],
        updatedAt: DateTime.parse('2026-03-20T12:00:00.000Z'),
      );

      await service.saveTocSnapshot(snapshot);
      final restored = await service.loadTocSnapshot(
        sourceId: 'src_1',
        detailUrl: 'https://example.com/book/1',
      );

      expect(restored, isNotNull);
      expect(restored!.title, '测试书籍');
      expect(restored.author, '作者甲');
      expect(restored.coverUrl, 'https://example.com/cover.jpg');
      expect(restored.chapters, hasLength(2));
      expect(restored.chapters.first.title, '第一卷');
      expect(restored.chapters.first.isVolume, isTrue);
      expect(restored.chapters.first.chapterUrl, isEmpty);
      expect(restored.chapters.last.index, 1);
    });
  });
}

Future<ReaderPreferencesService> _createService() async {
  final documentsDir = await Directory.systemTemp.createTemp('reader_docs_');
  final supportDir = await Directory.systemTemp.createTemp('reader_support_');
  final database = AppDatabase(executor: NativeDatabase.memory());
  addTearDown(() async {
    await database.close();
    if (documentsDir.existsSync()) {
      await documentsDir.delete(recursive: true);
    }
    if (supportDir.existsSync()) {
      await supportDir.delete(recursive: true);
    }
  });
  return ReaderPreferencesService(
    assetStore: ManagedAssetStore(
      documentsDirectoryProvider: () async => documentsDir,
      supportDirectoryProvider: () async => supportDir,
    ),
    database: database,
  );
}

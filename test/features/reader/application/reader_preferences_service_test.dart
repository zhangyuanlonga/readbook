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
        brightness: 0.75,
        themeMode: ReaderThemeMode.sepia,
        pageTurnMode: ReaderPageTurnMode.scroll,
        backgroundStyle: ReaderBackgroundStyle.paper,
        pageTurnStepRatio: 0.72,
        fontWeightLevel: ReaderFontWeightLevel.medium,
        pageAnimationStyle: ReaderPageAnimationStyle.cover,
        backgroundImageBase64: 'dGVzdF9iZw==',
      );

      await service.saveSettings(settings);
      final restored = await service.loadSettings();

      expect(restored.fontSize, 22);
      expect(restored.lineHeight, 1.9);
      expect(restored.horizontalPadding, 24);
      expect(restored.paragraphSpacing, 18);
      expect(restored.paragraphIndent, 4);
      expect(restored.brightness, 0.75);
      expect(restored.themeMode, ReaderThemeMode.sepia);
      expect(restored.pageTurnMode, ReaderPageTurnMode.scroll);
      expect(restored.backgroundStyle, ReaderBackgroundStyle.paper);
      expect(restored.pageTurnStepRatio, 0.72);
      expect(restored.fontWeightLevel, ReaderFontWeightLevel.medium);
      expect(restored.pageAnimationStyle, ReaderPageAnimationStyle.cover);
      expect(restored.backgroundImageBase64, 'dGVzdF9iZw==');
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

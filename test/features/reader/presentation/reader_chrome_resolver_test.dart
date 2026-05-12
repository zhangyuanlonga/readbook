import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/reader_settings.dart';
import 'package:shuxiang_reading_next/features/reader/presentation/reader_chrome_resolver.dart';
import 'package:shuxiang_reading_next/features/reader/presentation/reader_shell.dart';

void main() {
  group('ReaderChromeResolver', () {
    const resolver = ReaderChromeResolver();

    test('resolves paged visibility like md3-style reader chrome', () {
      final visibility = resolver.resolveVisibility(
        const ReaderSettings(
          infoHeaderEnabled: true,
          infoFooterEnabled: false,
          infoShowTime: true,
          infoShowBattery: true,
          infoShowChapter: true,
          infoShowProgress: true,
        ),
        ReaderPresentationViewportKind.textPaged,
      );

      expect(visibility.hasReaderInfoItems, isTrue);
      expect(visibility.showsOuterPinnedChapterHeader, isFalse);
      expect(visibility.showsOuterInfoBars, isFalse);
      expect(visibility.showsPagedHeaderInfoBar, isTrue);
      expect(visibility.showsOuterFooterInfoBar, isFalse);
      expect(visibility.showsAnyHeaderInfoBar, isTrue);
      expect(visibility.showsAnyFooterInfoBar, isTrue);
      expect(visibility.reservesPinnedHeaderSpace, isTrue);
    });

    test(
      'falls back to footer info bar for scroll mode when header/footer off',
      () {
        final visibility = resolver.resolveVisibility(
          const ReaderSettings(
            infoHeaderEnabled: false,
            infoFooterEnabled: false,
            infoShowTime: true,
            infoShowProgress: true,
          ),
          ReaderPresentationViewportKind.textScroll,
        );

        expect(visibility.showsOuterInfoBars, isTrue);
        expect(visibility.showsOuterFooterInfoBar, isTrue);
        expect(visibility.showsAnyHeaderInfoBar, isFalse);
        expect(visibility.showsAnyFooterInfoBar, isTrue);
      },
    );

    test('builds paged footer slots with chapter and page progress', () {
      final snapshot = ReaderChromeSnapshot(
        settings: const ReaderSettings(
          infoHeaderEnabled: true,
          infoShowTime: true,
          infoShowBattery: true,
          infoShowChapter: true,
          infoShowProgress: true,
        ),
        viewportKind: ReaderPresentationViewportKind.textPaged,
        now: DateTime(2026, 4, 26, 12, 30),
        progressPercent: 43,
        chapterTitle: '第一章 山雨欲来',
        bookTitle: '示例书籍',
        batteryLevel: 64,
        pageIndex: 11,
        pageCount: 20,
      );
      final visibility = resolver.resolveVisibility(
        snapshot.settings,
        snapshot.viewportKind,
      );
      final slots = resolver.resolveInfoBarSlots(
        snapshot: snapshot,
        visibility: visibility,
        isHeader: false,
      );

      expect(slots.leading.single.text, '第一章 山雨欲来');
      expect(slots.center, isEmpty);
      expect(slots.trailing[0].kind.name, 'text');
      expect(slots.trailing[0].text, '12/20 · 43%');
    });

    test('moves chapter into header center when footer is absent', () {
      final snapshot = ReaderChromeSnapshot(
        settings: const ReaderSettings(
          infoHeaderEnabled: true,
          infoFooterEnabled: false,
          infoShowChapter: true,
          infoShowTime: true,
          infoShowProgress: true,
        ),
        viewportKind: ReaderPresentationViewportKind.textScroll,
        now: DateTime(2026, 4, 26, 8, 5),
        progressPercent: 10,
        chapterTitle: '第二章',
      );
      final visibility = resolver.resolveVisibility(
        snapshot.settings,
        snapshot.viewportKind,
      );

      final headerSlots = resolver.resolveInfoBarSlots(
        snapshot: snapshot,
        visibility: visibility,
        isHeader: true,
      );

      expect(headerSlots.leading.single.text, '08:05');
      expect(headerSlots.center.single.text, '第二章');
      expect(headerSlots.trailing.single.text, '进度 10%');
    });
  });
}

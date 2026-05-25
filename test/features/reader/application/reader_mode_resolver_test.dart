import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/reader_settings.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_content_session.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_mode_model.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_mode_resolver.dart';

void main() {
  group('ReaderModeResolver', () {
    const resolver = ReaderModeResolver();

    test('resolves paged text mode when paged text is available', () {
      const settings = ReaderSettings(
        pageTurnMode: ReaderPageTurnMode.tapAndSwipe,
        pageAnimationStyle: ReaderPageAnimationStyle.cover,
      );

      final mode = resolver.resolve(
        contentMode: ReaderContentMode.text,
        settings: settings,
        canUsePagedText: true,
      );

      expect(mode.contentKind, ReaderContentKind.text);
      expect(mode.layoutMode, ReaderLayoutMode.paged);
      expect(mode.viewportKind, ReaderModeViewportKind.textPaged);
      expect(mode.tapTurnEnabled, isTrue);
      expect(mode.swipeTurnEnabled, isTrue);
      expect(mode.pageAnimationStyle, ReaderPageAnimationStyle.cover);
    });

    test('resolves scroll text mode when page turn input selects scroll', () {
      const settings = ReaderSettings(
        pageTurnMode: ReaderPageTurnMode.tapAndScroll,
      );

      final mode = resolver.resolve(
        contentMode: ReaderContentMode.text,
        settings: settings,
        canUsePagedText: true,
      );

      expect(mode.contentKind, ReaderContentKind.text);
      expect(mode.layoutMode, ReaderLayoutMode.scroll);
      expect(mode.viewportKind, ReaderModeViewportKind.textScroll);
      expect(mode.tapTurnEnabled, isTrue);
      expect(mode.swipeTurnEnabled, isFalse);
      expect(mode.pageAnimationStyle, isNull);
    });

    test('resolves scroll text mode when paged text is unavailable', () {
      const settings = ReaderSettings(
        pageTurnMode: ReaderPageTurnMode.tapAndSwipe,
      );

      final mode = resolver.resolve(
        contentMode: ReaderContentMode.text,
        settings: settings,
        canUsePagedText: false,
      );

      expect(mode.contentKind, ReaderContentKind.text);
      expect(mode.layoutMode, ReaderLayoutMode.scroll);
      expect(mode.viewportKind, ReaderModeViewportKind.textScroll);
      expect(mode.tapTurnEnabled, isTrue);
      expect(mode.swipeTurnEnabled, isFalse);
      expect(mode.pageAnimationStyle, isNull);
    });

    test('resolves image paged and scroll layouts from manga mode', () {
      const pagedSettings = ReaderSettings(
        mangaReadMode: ReaderMangaReadMode.paged,
      );
      const scrollSettings = ReaderSettings(
        mangaReadMode: ReaderMangaReadMode.continuous,
      );

      final pagedMode = resolver.resolve(
        contentMode: ReaderContentMode.comic,
        settings: pagedSettings,
        canUsePagedText: false,
      );
      final scrollMode = resolver.resolve(
        contentMode: ReaderContentMode.comic,
        settings: scrollSettings,
        canUsePagedText: false,
      );

      expect(pagedMode.contentKind, ReaderContentKind.image);
      expect(pagedMode.layoutMode, ReaderLayoutMode.paged);
      expect(pagedMode.viewportKind, ReaderModeViewportKind.imagePaged);
      expect(pagedMode.pageAnimationStyle, isNull);

      expect(scrollMode.contentKind, ReaderContentKind.image);
      expect(scrollMode.layoutMode, ReaderLayoutMode.scroll);
      expect(scrollMode.viewportKind, ReaderModeViewportKind.imageScroll);
      expect(scrollMode.pageAnimationStyle, isNull);
    });

    test('resolves hybrid content as paged document viewport', () {
      const settings = ReaderSettings();

      final mode = resolver.resolve(
        contentMode: ReaderContentMode.hybrid,
        settings: settings,
        canUsePagedText: false,
      );

      expect(mode.contentKind, ReaderContentKind.document);
      expect(mode.layoutMode, ReaderLayoutMode.paged);
      expect(mode.viewportKind, ReaderModeViewportKind.hybridPaged);
      expect(mode.supportsTextSelection, isFalse);
      expect(mode.supportsZoomGesture, isTrue);
      expect(mode.supportsAutoRead, isFalse);
    });
  });
}

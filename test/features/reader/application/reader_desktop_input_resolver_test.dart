import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_desktop_input_resolver.dart';

void main() {
  group('ReaderDesktopInputResolver', () {
    const resolver = ReaderDesktopInputResolver();

    test('maps keyboard shortcuts to reader actions', () {
      expect(
        resolver.resolveKeyAction(LogicalKeyboardKey.escape),
        ReaderDesktopInputAction.toggleOverlay,
      );
      expect(
        resolver.resolveKeyAction(LogicalKeyboardKey.arrowLeft),
        ReaderDesktopInputAction.previousPage,
      );
      expect(
        resolver.resolveKeyAction(LogicalKeyboardKey.pageUp),
        ReaderDesktopInputAction.previousPage,
      );
      expect(
        resolver.resolveKeyAction(LogicalKeyboardKey.arrowRight),
        ReaderDesktopInputAction.nextPage,
      );
      expect(
        resolver.resolveKeyAction(LogicalKeyboardKey.space),
        ReaderDesktopInputAction.nextPage,
      );
      expect(
        resolver.resolveKeyAction(LogicalKeyboardKey.home),
        ReaderDesktopInputAction.chapterStart,
      );
      expect(
        resolver.resolveKeyAction(LogicalKeyboardKey.end),
        ReaderDesktopInputAction.chapterEnd,
      );
      expect(
        resolver.resolveKeyAction(LogicalKeyboardKey.keyA),
        ReaderDesktopInputAction.none,
      );
    });

    test('keeps overlay, busy, and auto-read keyboard gates centralized', () {
      expect(
        resolver.resolveKeyAction(
          LogicalKeyboardKey.arrowRight,
          overlayVisible: true,
        ),
        ReaderDesktopInputAction.none,
      );
      expect(
        resolver.resolveKeyAction(
          LogicalKeyboardKey.escape,
          overlayVisible: true,
        ),
        ReaderDesktopInputAction.toggleOverlay,
      );
      expect(
        resolver.resolveKeyAction(
          LogicalKeyboardKey.keyA,
          autoReadSessionEnabled: true,
        ),
        ReaderDesktopInputAction.pauseAutoRead,
      );
      expect(
        resolver.resolveKeyAction(
          LogicalKeyboardKey.arrowRight,
          readerBusy: true,
          autoReadSessionEnabled: true,
        ),
        ReaderDesktopInputAction.none,
      );
      expect(
        resolver.resolveKeyAction(
          LogicalKeyboardKey.escape,
          textSelectionActive: true,
        ),
        ReaderDesktopInputAction.none,
      );
    });

    test(
      'resolves pointer wheel page turns only for eligible paged viewport',
      () {
        final now = DateTime.utc(2026, 5, 12, 10);

        expect(
          resolver.resolvePointerScrollAction(
            deltaY: 24,
            isPagedViewport: true,
            overlayVisible: false,
            textSelectionActive: false,
            now: now,
          ),
          ReaderDesktopInputAction.nextPage,
        );
        expect(
          resolver.resolvePointerScrollAction(
            deltaY: -24,
            isPagedViewport: true,
            overlayVisible: false,
            textSelectionActive: false,
            now: now,
          ),
          ReaderDesktopInputAction.previousPage,
        );
        expect(
          resolver.resolvePointerScrollAction(
            deltaY: 4,
            isPagedViewport: true,
            overlayVisible: false,
            textSelectionActive: false,
            now: now,
          ),
          ReaderDesktopInputAction.none,
        );
        expect(
          resolver.resolvePointerScrollAction(
            deltaY: 24,
            isPagedViewport: false,
            overlayVisible: false,
            textSelectionActive: false,
            now: now,
          ),
          ReaderDesktopInputAction.none,
        );
        expect(
          resolver.resolvePointerScrollAction(
            deltaY: 24,
            isPagedViewport: true,
            overlayVisible: true,
            textSelectionActive: false,
            now: now,
          ),
          ReaderDesktopInputAction.none,
        );
        expect(
          resolver.resolvePointerScrollAction(
            deltaY: 24,
            isPagedViewport: true,
            overlayVisible: false,
            textSelectionActive: true,
            now: now,
          ),
          ReaderDesktopInputAction.none,
        );
      },
    );

    test('throttles repeated pointer wheel page turns', () {
      final now = DateTime.utc(2026, 5, 12, 10);

      expect(
        resolver.resolvePointerScrollAction(
          deltaY: 24,
          isPagedViewport: true,
          overlayVisible: false,
          textSelectionActive: false,
          lastPageTurnAt: now.subtract(const Duration(milliseconds: 80)),
          now: now,
        ),
        ReaderDesktopInputAction.none,
      );
      expect(
        resolver.resolvePointerScrollAction(
          deltaY: 24,
          isPagedViewport: true,
          overlayVisible: false,
          textSelectionActive: false,
          lastPageTurnAt: now.subtract(const Duration(milliseconds: 260)),
          now: now,
        ),
        ReaderDesktopInputAction.nextPage,
      );
    });
  });
}

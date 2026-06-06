import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_accessibility_adaptive_policy.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_content_session.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_mode_model.dart';

void main() {
  group('ReaderAccessibilityAdaptivePolicy', () {
    const policy = ReaderAccessibilityAdaptivePolicy();

    test(
      'covers required M6 width audit points without overflowing content cap',
      () {
        for (final width
            in ReaderAccessibilityAdaptivePolicy.widthAuditPoints) {
          final decision = policy.resolveLayout(
            width: width,
            isDesktopLike: width >= 600,
          );

          expect(decision.contentMaxWidth, lessThanOrEqualTo(720));
          expect(decision.overlayHorizontalInset, greaterThan(0));
          expect(decision.minTouchTarget, greaterThanOrEqualTo(40));
        }
      },
    );

    test('uses side panels only on desktop-like medium and wider surfaces', () {
      expect(
        policy.resolveLayout(width: 390, isDesktopLike: true).usesSidePanel,
        isFalse,
      );
      expect(
        policy.resolveLayout(width: 840, isDesktopLike: true).usesSidePanel,
        isTrue,
      );
      expect(
        policy.resolveLayout(width: 840, isDesktopLike: false).usesSidePanel,
        isFalse,
      );
    });

    test(
      'caps chrome and sheet text scale while reader body follows settings',
      () {
        final decision = policy.resolveTextScale(textScaleFactor: 1.8);

        expect(decision.readerBodyScaleFollowsSettings, isTrue);
        expect(decision.chromeTextScale, 1.2);
        expect(decision.sheetTextScale, 1.15);
      },
    );

    test('enables focus and hover affordances only for pointer surfaces', () {
      final mobile = policy.resolveKeyboardInteraction(
        surface: ReaderInteractionSurface.mobileTouch,
      );
      final desktop = policy.resolveKeyboardInteraction(
        surface: ReaderInteractionSurface.desktopPointer,
      );

      expect(mobile.supportsTabTraversal, isFalse);
      expect(mobile.wheelPageTurnEnabled, isFalse);
      expect(desktop.showsFocusRing, isTrue);
      expect(desktop.escClosesOverlay, isTrue);
      expect(desktop.enterActivatesFocusedAction, isTrue);
    });

    test(
      'separates text selection image preview and pdf zoom capabilities',
      () {
        final text = policy.resolveGestureCapability(
          contentMode: ReaderContentMode.text,
          viewportKind: ReaderModeViewportKind.textScroll,
          surface: ReaderInteractionSurface.mobileTouch,
        );
        final manga = policy.resolveGestureCapability(
          contentMode: ReaderContentMode.comic,
          viewportKind: ReaderModeViewportKind.imageScroll,
          surface: ReaderInteractionSurface.desktopPointer,
        );
        final pdf = policy.resolveGestureCapability(
          contentMode: ReaderContentMode.hybrid,
          viewportKind: ReaderModeViewportKind.hybridPaged,
          surface: ReaderInteractionSurface.webPointer,
        );

        expect(text.supportsTextSelection, isTrue);
        expect(text.prefersLongPressSelection, isTrue);
        expect(manga.supportsImagePreview, isTrue);
        expect(pdf.supportsPdfZoomGesture, isTrue);
      },
    );

    test('raises readability requirements for high contrast text', () {
      final decision = policy.resolveReadability(
        hasBackgroundImage: true,
        darkMode: true,
        highContrastText: true,
      );

      expect(decision.shouldDimBackgroundImage, isTrue);
      expect(decision.brightnessOverlayAllowed, isFalse);
      expect(decision.minimumContrastRatio, 7.0);
      expect(decision.preferSolidTextScrim, isTrue);
    });
  });
}

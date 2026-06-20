import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/reader_settings.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_page_turn_delegate.dart';

void main() {
  group('ReaderPageTurnDelegate', () {
    const delegate = ReaderPageTurnDelegate();

    test('allows legacy renderer to keep the requested animation style', () {
      final decision = delegate.resolve(
        const ReaderPageTurnDelegateRequest(
          surface: ReaderPageTurnRendererSurface.legacy,
          requestedStyle: ReaderPageAnimationStyle.paperCurl,
        ),
      );

      expect(decision.usesLegacyFallback, isFalse);
      expect(decision.effectiveStyle, ReaderPageAnimationStyle.paperCurl);
    });

    test('allows layout release only for explicitly supported animation', () {
      final decision = delegate.resolve(
        const ReaderPageTurnDelegateRequest(
          surface: ReaderPageTurnRendererSurface.layoutRelease,
          requestedStyle: ReaderPageAnimationStyle.none,
        ),
      );

      expect(decision.usesLegacyFallback, isFalse);
      expect(decision.reason, 'layout_release_supported');
    });

    test('falls back to legacy for unbridged layout release animations', () {
      for (final style in <ReaderPageAnimationStyle>[
        ReaderPageAnimationStyle.paperCurl,
        ReaderPageAnimationStyle.curl,
        ReaderPageAnimationStyle.cover,
        ReaderPageAnimationStyle.translate,
        ReaderPageAnimationStyle.vertical,
        ReaderPageAnimationStyle.fade,
      ]) {
        final decision = delegate.resolve(
          ReaderPageTurnDelegateRequest(
            surface: ReaderPageTurnRendererSurface.layoutRelease,
            requestedStyle: style,
          ),
        );

        expect(decision.usesLegacyFallback, isTrue, reason: style.name);
        expect(decision.effectiveStyle, style);
      }
    });
  });
}

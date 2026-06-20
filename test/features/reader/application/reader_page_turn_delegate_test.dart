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

    test('allows layout release to keep every existing page animation', () {
      for (final style in ReaderPageAnimationStyle.values) {
        final decision = delegate.resolve(
          ReaderPageTurnDelegateRequest(
            surface: ReaderPageTurnRendererSurface.layoutRelease,
            requestedStyle: style,
          ),
        );

        expect(decision.usesLegacyFallback, isFalse, reason: style.name);
        expect(decision.effectiveStyle, style);
        expect(decision.reason, 'layout_release_supported');
      }
    });
  });
}

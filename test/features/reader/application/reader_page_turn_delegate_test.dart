import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/reader_settings.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_page_turn_delegate.dart';

void main() {
  group('ReaderPageTurnDelegate', () {
    const delegate = ReaderPageTurnDelegate();

    test('allows layout release to keep every existing page animation', () {
      for (final style in ReaderPageAnimationStyle.values) {
        final decision = delegate.resolve(
          ReaderPageTurnDelegateRequest(requestedStyle: style),
        );

        expect(decision.effectiveStyle, style);
        expect(decision.reason, 'layout_release_supported');
      }
    });
  });
}

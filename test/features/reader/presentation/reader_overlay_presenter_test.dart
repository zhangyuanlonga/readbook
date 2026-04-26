import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/reader/presentation/reader_overlay_presenter.dart';

void main() {
  group('ReaderOverlayPresenter', () {
    const presenter = ReaderOverlayPresenter();

    test('dedupes snackbar within time window', () {
      final now = DateTime(2026, 4, 26, 12);
      final decision = presenter.resolveSnackbarDecision(
        text: 'hello',
        lastKey: 'hello',
        lastAt: now,
        dedupeWindow: const Duration(seconds: 2),
        now: now.add(const Duration(seconds: 1)),
      );

      expect(decision.shouldShow, isFalse);
    });

    test('resolves progress from draft ratio when present', () {
      expect(
        presenter.resolveProgressValue(currentRatio: 0.2, draftRatio: 0.7),
        0.7,
      );
    });

    testWidgets('builds shell overlay transition widget', (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: presenter.buildShellOverlayTransition(
            edge: ReaderOverlayEdge.top,
            slideProgress: 1,
            fadeProgress: 1,
            collapsedScale: 0.95,
            translateDistance: 20,
            child: const Text('overlay'),
          ),
        ),
      );

      expect(find.text('overlay'), findsOneWidget);
    });
  });
}

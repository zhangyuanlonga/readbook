import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/reader/presentation/reader_page_lifecycle_delegate.dart';

void main() {
  group('ReaderPageLifecycleDelegate', () {
    const delegate = ReaderPageLifecycleDelegate();

    test('marks back interaction and reports cooldown window', () {
      final now = DateTime(2026, 4, 26, 12);
      final marked = delegate.markBackNavigationTriggered(now: now);

      expect(marked, now);
      expect(
        delegate.isBackNavigationCoolingDown(
          lastInteractionAt: marked,
          cooldown: const Duration(milliseconds: 300),
          now: now.add(const Duration(milliseconds: 100)),
        ),
        isTrue,
      );
    });

    test('classifies lifecycle resume and pause states', () {
      expect(
        delegate.shouldResumeReaderRuntime(AppLifecycleState.resumed),
        isTrue,
      );
      expect(
        delegate.shouldPauseReaderRuntime(AppLifecycleState.paused),
        isTrue,
      );
      expect(
        delegate.shouldPauseReaderRuntime(AppLifecycleState.inactive),
        isTrue,
      );
    });
  });
}

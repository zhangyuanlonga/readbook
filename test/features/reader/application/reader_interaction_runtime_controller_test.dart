import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_interaction_runtime_controller.dart';

void main() {
  group('ReaderInteractionRuntimeController', () {
    test('tracks busy state and low priority pause', () {
      final controller = ReaderInteractionRuntimeController();
      addTearDown(controller.dispose);

      final transition = controller.markBusy(
        ReaderInteractionRuntimeState.animating,
      );

      expect(transition?.from, ReaderInteractionRuntimeState.idle);
      expect(transition?.to, ReaderInteractionRuntimeState.animating);
      expect(controller.state, ReaderInteractionRuntimeState.animating);
      expect(controller.isLowPriorityWorkPaused, isTrue);
    });

    test('settles back to idle and consumes deferred preload', () async {
      final controller = ReaderInteractionRuntimeController(
        settleDuration: const Duration(milliseconds: 1),
      );
      addTearDown(controller.dispose);
      final settledTransitions = <ReaderInteractionStateTransition?>[];

      controller.markBusy(ReaderInteractionRuntimeState.dragging);
      controller.markDeferredNeighborPreload();
      final settling = controller.beginSettling(
        onSettled: settledTransitions.add,
      );

      expect(settling?.to, ReaderInteractionRuntimeState.settling);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(controller.state, ReaderInteractionRuntimeState.idle);
      expect(settledTransitions.single?.to, ReaderInteractionRuntimeState.idle);
      expect(controller.consumeDeferredNeighborPreloadIfIdle(), isTrue);
      expect(controller.consumeDeferredNeighborPreloadIfIdle(), isFalse);
    });

    test('tracks initial interaction cooldown', () {
      final controller = ReaderInteractionRuntimeController();
      addTearDown(controller.dispose);
      final now = DateTime(2026, 6, 13, 10);

      controller.lockInitialInteractionUntil(
        now.add(const Duration(milliseconds: 300)),
      );

      expect(controller.isInitialInteractionCoolingDown(now), isTrue);
      expect(
        controller.isInitialInteractionCoolingDown(
          now.add(const Duration(milliseconds: 301)),
        ),
        isFalse,
      );
    });

    test('tracks back navigation cooldown and double back exit', () {
      final controller = ReaderInteractionRuntimeController();
      addTearDown(controller.dispose);
      final now = DateTime(2026, 6, 13, 10);

      controller.markBackNavigationTriggered(now);

      expect(
        controller.isBackNavigationCoolingDown(
          now.add(const Duration(milliseconds: 100)),
          const Duration(milliseconds: 250),
        ),
        isTrue,
      );
      expect(
        controller.isBackNavigationCoolingDown(
          now.add(const Duration(milliseconds: 300)),
          const Duration(milliseconds: 250),
        ),
        isFalse,
      );
      expect(
        controller.recordReaderBackAndShouldExit(
          now: now,
          doubleBackWindow: const Duration(milliseconds: 700),
        ),
        isFalse,
      );
      expect(
        controller.recordReaderBackAndShouldExit(
          now: now.add(const Duration(milliseconds: 600)),
          doubleBackWindow: const Duration(milliseconds: 700),
        ),
        isTrue,
      );
    });
  });
}

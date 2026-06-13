import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/reader/presentation/reader_pointer_input_controller.dart';

void main() {
  group('ReaderPointerInputController', () {
    test('tracks swipe movement and pointer-up metrics', () {
      var now = DateTime(2026, 6, 13, 12);
      final controller = ReaderPointerInputController(now: () => now);
      final traces = <String>[];

      final started = controller.beginPointer(
        const PointerDownEvent(
          pointer: 1,
          position: Offset(10, 20),
          kind: PointerDeviceKind.touch,
        ),
        shouldHandleLongPress: false,
        selectionActive: false,
        resolveLongPressGuard:
            () => const ReaderPointerLongPressGuard(
              mounted: true,
              selectionActive: false,
            ),
        logTrace: (step, {context = const <String, Object?>{}}) {
          traces.add(step);
        },
        onLongPress: () {},
      );

      expect(started, isTrue);
      controller.startSwipe(const Offset(10, 20));
      now = now.add(const Duration(milliseconds: 100));
      expect(
        controller.updatePointerMove(
          const PointerMoveEvent(pointer: 1, position: Offset(80, 24)),
          logTrace: (step, {context = const <String, Object?>{}}) {
            traces.add(step);
          },
        ),
        isTrue,
      );

      final snapshot = controller.buildPointerUpSnapshot(
        const PointerUpEvent(pointer: 1, position: Offset(80, 24)),
      );

      expect(snapshot, isNotNull);
      expect(snapshot!.moved, isTrue);
      expect(snapshot.dx, 70);
      expect(snapshot.dy, 4);
      expect(snapshot.velocity, 700);
      expect(traces, contains('pointer_move_cancel_long_press'));
    });

    test('marks child handled before pointer up', () {
      final controller = ReaderPointerInputController();

      controller.beginPointer(
        const PointerDownEvent(
          pointer: 1,
          position: Offset.zero,
          kind: PointerDeviceKind.touch,
        ),
        shouldHandleLongPress: false,
        selectionActive: false,
        resolveLongPressGuard:
            () => const ReaderPointerLongPressGuard(
              mounted: true,
              selectionActive: false,
            ),
        logTrace: (_, {context = const <String, Object?>{}}) {},
        onLongPress: () {},
      );
      controller.markChildHandled();

      final snapshot = controller.buildPointerUpSnapshot(
        const PointerUpEvent(pointer: 1, position: Offset.zero),
      );

      expect(snapshot?.childHandled, isTrue);
    });

    test('ignores non-primary mouse buttons', () {
      final controller = ReaderPointerInputController();

      final started = controller.beginPointer(
        const PointerDownEvent(
          pointer: 1,
          position: Offset.zero,
          kind: PointerDeviceKind.mouse,
          buttons: kSecondaryMouseButton,
        ),
        shouldHandleLongPress: false,
        selectionActive: false,
        resolveLongPressGuard:
            () => const ReaderPointerLongPressGuard(
              mounted: true,
              selectionActive: false,
            ),
        logTrace: (_, {context = const <String, Object?>{}}) {},
        onLongPress: () {},
      );

      expect(started, isFalse);
      expect(controller.hasActivePointer, isFalse);
    });
  });
}

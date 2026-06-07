import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/app/lifecycle/async_ownership_controller.dart';

void main() {
  group('AsyncOwnershipController', () {
    test('only keeps the latest task active', () {
      final controller = AsyncOwnershipController();

      final first = controller.begin();
      final second = controller.begin();

      expect(controller.isActive(first, mounted: true), isFalse);
      expect(controller.isActive(second, mounted: true), isTrue);
    });

    test('cancel invalidates the current task generation', () {
      final controller = AsyncOwnershipController();

      final token = controller.begin();
      controller.cancel();

      expect(controller.isActive(token, mounted: true), isFalse);
    });

    test('mounted guard prevents disposed widgets from writing state', () {
      final controller = AsyncOwnershipController();

      final token = controller.begin();

      expect(controller.isActive(token, mounted: false), isFalse);
    });

    test('dispose invalidates active tasks and blocks new tasks', () {
      final controller = AsyncOwnershipController();

      final token = controller.begin();
      controller.dispose();

      expect(controller.isActive(token, mounted: true), isFalse);
      expect(controller.isDisposed, isTrue);
      expect(controller.begin, throwsStateError);
    });
  });
}

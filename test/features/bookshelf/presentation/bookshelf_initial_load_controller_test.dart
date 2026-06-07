import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/bookshelf/presentation/bookshelf_initial_load_controller.dart';

void main() {
  group('BookshelfInitialLoadController', () {
    test('does not reset cover refresh state after unmount', () async {
      final controller = BookshelfInitialLoadController();
      final loadCompleter = Completer<void>();
      var mounted = true;
      final coverRefreshStates = <bool>[];

      final task = controller.load(
        force: true,
        isMounted: () => mounted,
        hasVisibleBooks: true,
        duplicateLoadCooldown: const Duration(milliseconds: 700),
        runCore: () => loadCompleter.future,
        setCoverRefreshActive: coverRefreshStates.add,
      );

      expect(coverRefreshStates, <bool>[true]);

      mounted = false;
      loadCompleter.complete();
      await task;

      expect(coverRefreshStates, <bool>[true]);
    });

    test('coalesces non-forced duplicate loads while one is active', () async {
      final controller = BookshelfInitialLoadController();
      final loadCompleter = Completer<void>();
      var runCount = 0;

      final first = controller.load(
        force: false,
        isMounted: () => true,
        hasVisibleBooks: false,
        duplicateLoadCooldown: const Duration(milliseconds: 700),
        runCore: () {
          runCount += 1;
          return loadCompleter.future;
        },
        setCoverRefreshActive: (_) {},
      );
      unawaited(
        controller.load(
          force: false,
          isMounted: () => true,
          hasVisibleBooks: false,
          duplicateLoadCooldown: const Duration(milliseconds: 700),
          runCore: () {
            runCount += 1;
            return Future<void>.value();
          },
          setCoverRefreshActive: (_) {},
        ),
      );

      expect(runCount, 1);

      loadCompleter.complete();
      await first;
    });
  });
}

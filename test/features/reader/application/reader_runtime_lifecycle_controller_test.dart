import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_runtime_lifecycle_controller.dart';

void main() {
  group('ReaderRuntimeLifecycleController', () {
    const controller = ReaderRuntimeLifecycleController();

    test('pauses runtime for non-visible lifecycle states', () {
      for (final state in <AppLifecycleState>[
        AppLifecycleState.inactive,
        AppLifecycleState.paused,
        AppLifecycleState.detached,
      ]) {
        final decision = controller.resolve(state);

        expect(decision.pauseRuntime, isTrue);
        expect(decision.resumeRuntime, isFalse);
      }
    });

    test('resumes runtime when app is resumed', () {
      final decision = controller.resolve(AppLifecycleState.resumed);

      expect(decision.pauseRuntime, isFalse);
      expect(decision.resumeRuntime, isTrue);
    });
  });
}

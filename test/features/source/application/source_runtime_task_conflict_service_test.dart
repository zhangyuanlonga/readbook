import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/source/application/source_runtime_task_conflict_service.dart';

void main() {
  group('SourceRuntimeTaskConflictService', () {
    late SourceRuntimeTaskConflictService service;

    setUp(() {
      service = SourceRuntimeTaskConflictService();
    });

    test('background epoch advances when foreground scene cancels conflict', () {
      const key = 'source_a::detail:https%3A%2F%2Fexample.com%2Fbook%2F1';
      final capturedEpoch = service.captureBackgroundEpoch(key);

      expect(
        service.hasBackgroundConflictAdvanced(
          conflictKey: key,
          capturedEpoch: capturedEpoch,
        ),
        isFalse,
      );

      service.cancelBackgroundWorkFor(
        conflictKey: key,
        byScene: SourceRuntimeConflictScene.reader,
      );

      expect(
        service.hasBackgroundConflictAdvanced(
          conflictKey: key,
          capturedEpoch: capturedEpoch,
        ),
        isTrue,
      );
    });

    test('source-wide conflict key can cancel lower-priority work', () {
      const sourceId = 'source_discover';
      final sourceKey = service.conflictKeyForSource(sourceId);
      final capturedEpoch = service.captureBackgroundEpoch(sourceKey);

      service.cancelBackgroundWorkFor(
        conflictKey: sourceKey,
        byScene: SourceRuntimeConflictScene.discover,
      );

      expect(
        service.hasBackgroundConflictAdvanced(
          conflictKey: sourceKey,
          capturedEpoch: capturedEpoch,
        ),
        isTrue,
      );
    });
  });
}

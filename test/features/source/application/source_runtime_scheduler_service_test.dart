import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/source/application/source_runtime_scheduler_service.dart';

void main() {
  group('SourceRuntimeSchedulerService', () {
    late SourceRuntimeSchedulerService service;

    setUp(() {
      service = SourceRuntimeSchedulerService();
    });

    test('foreground reader cancels lower-priority background work', () {
      final disposition = service.resolveForegroundDisposition(
        requestingScene: SourceRuntimeSchedulerScene.reader,
        conflictingScene: SourceRuntimeSchedulerScene.bookshelfBackground,
      );

      expect(disposition, SourceRuntimeTaskDisposition.cancel);
    });

    test('same-priority foreground scenes queue instead of cancelling', () {
      final disposition = service.resolveForegroundDisposition(
        requestingScene: SourceRuntimeSchedulerScene.detail,
        conflictingScene: SourceRuntimeSchedulerScene.discover,
      );

      expect(disposition, SourceRuntimeTaskDisposition.queue);
    });

    test('builds detail-based conflict key when detail url exists', () {
      final key = service.conflictKeyForBook(
        sourceId: 'source_1',
        detailUrl: 'https://example.com/book/1',
        bookId: 'book_1',
      );

      expect(
        key,
        'source_1::detail:${Uri.encodeComponent('https://example.com/book/1')}',
      );
    });

    test('queues same-priority task until existing lease releases', () async {
      final first = await service.acquire(
        scene: SourceRuntimeSchedulerScene.detail,
        conflictKeys: const <String>['source_1'],
      );
      expect(first, isNotNull);

      var acquiredSecond = false;
      final secondFuture = service
          .acquire(
            scene: SourceRuntimeSchedulerScene.discover,
            conflictKeys: const <String>['source_1'],
          )
          .then((lease) {
            acquiredSecond = lease != null;
            lease?.release();
          });

      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(acquiredSecond, isFalse);

      first!.release();
      await secondFuture.timeout(const Duration(seconds: 1));
      expect(acquiredSecond, isTrue);
    });

    test('returns null when blocked by higher priority and cancellation requested', () async {
      final foreground = await service.acquire(
        scene: SourceRuntimeSchedulerScene.reader,
        conflictKeys: const <String>['source_1'],
      );
      expect(foreground, isNotNull);

      final background = await service.acquire(
        scene: SourceRuntimeSchedulerScene.bookshelfBackground,
        conflictKeys: const <String>['source_1'],
        cancelIfBlockedByHigherPriority: true,
      );

      expect(background, isNull);
      foreground!.release();
    });

    test('reuses lease for detail and reader on same book keys', () async {
      final detailLease = await service.acquire(
        scene: SourceRuntimeSchedulerScene.detail,
        conflictKeys: const <String>[
          'source_1',
          'source_1::detail:https%3A%2F%2Fexample.com%2Fbook%2F1',
        ],
      );
      expect(detailLease, isNotNull);

      var readerAcquired = false;
      final readerFuture = service
          .acquire(
            scene: SourceRuntimeSchedulerScene.reader,
            conflictKeys: const <String>[
              'source_1',
              'source_1::detail:https%3A%2F%2Fexample.com%2Fbook%2F1',
            ],
          )
          .then((lease) {
            readerAcquired = lease != null;
            lease?.release();
          });

      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(readerAcquired, isTrue);

      detailLease!.release();
      await readerFuture.timeout(const Duration(seconds: 1));
    });
  });
}

import 'package:shuxiang_reading_next/features/search/application/search_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SearchCancellationToken', () {
    test('waitIfPaused returns immediately when token is active', () async {
      final token = SearchCancellationToken();
      await token.waitIfPaused();
      expect(token.isCancelled, isFalse);
      expect(token.isPaused, isFalse);
    });

    test('pause blocks waiters until resume', () async {
      final token = SearchCancellationToken();
      token.pause();

      var resumed = false;
      final waiter = token.waitIfPaused().then((_) {
        resumed = true;
      });

      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(resumed, isFalse);
      expect(token.isPaused, isTrue);

      token.resume();
      await waiter.timeout(const Duration(seconds: 1));

      expect(resumed, isTrue);
      expect(token.isPaused, isFalse);
      expect(token.isCancelled, isFalse);
    });

    test('cancel unblocks paused waiters', () async {
      final token = SearchCancellationToken();
      token.pause();

      var completed = false;
      final waiter = token.waitIfPaused().then((_) {
        completed = true;
      });

      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(completed, isFalse);

      token.cancel();
      await waiter.timeout(const Duration(seconds: 1));

      expect(token.isCancelled, isTrue);
      expect(token.isPaused, isFalse);
      expect(completed, isTrue);
    });
  });
}

import 'package:shuxiang_reading_next/core/network/source_rate_limiter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SourceRateLimiter', () {
    test('ignores missing source id or invalid rate', () async {
      final limiter = SourceRateLimiter();

      await limiter.acquire(sourceId: '', concurrentRate: '1/1000');
      await limiter.acquire(sourceId: 's1', concurrentRate: '');
      await limiter.acquire(sourceId: 's1', concurrentRate: 'invalid');
    });

    test('enforces simple 1/windowMs rate', () async {
      final limiter = SourceRateLimiter();
      final stopwatch = Stopwatch()..start();

      await limiter.acquire(sourceId: 's1', concurrentRate: '1/80');
      await limiter.acquire(sourceId: 's1', concurrentRate: '1/80');

      stopwatch.stop();
      expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(60));
    });
  });
}

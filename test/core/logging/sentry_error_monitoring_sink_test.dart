import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shuxiang_reading_next/core/logging/sentry_error_monitoring_sink.dart';

void main() {
  group('filterUnsanitizedSentryEvent', () {
    test('allows only events tagged as sanitized by app monitoring', () {
      final sanitized = SentryEvent(
        tags: const <String, String>{
          SentryAppErrorMonitoringSink.sanitizedTagKey:
              SentryAppErrorMonitoringSink.sanitizedTagValue,
        },
      );
      final raw = SentryEvent();

      expect(filterUnsanitizedSentryEvent(sanitized, Hint()), same(sanitized));
      expect(filterUnsanitizedSentryEvent(raw, Hint()), isNull);
    });
  });
}

import 'package:sentry_flutter/sentry_flutter.dart';

import 'error_monitoring_service.dart';

class SentryAppErrorMonitoringSink implements AppErrorMonitoringSink {
  const SentryAppErrorMonitoringSink();

  static const String sanitizedTagKey = 'selune_sanitized';
  static const String sanitizedTagValue = 'true';

  @override
  Future<void> capture(AppErrorMonitoringEvent event) async {
    await Sentry.captureException(
      event.throwable ?? MonitoredException(event.message),
      stackTrace: event.stackTrace,
      withScope: (scope) {
        scope.level =
            event.severity == AppErrorMonitoringSeverity.fatal
                ? SentryLevel.fatal
                : SentryLevel.error;
        scope.setTag(sanitizedTagKey, sanitizedTagValue);
        scope.setTag('origin', event.origin);
        scope.setContexts('selune_error', <String, Object?>{
          'message': event.message,
          'origin': event.origin,
          'severity': event.severity.name,
          'timestamp': event.timestamp.toIso8601String(),
          'context': event.context,
        });
      },
    );
  }
}

SentryEvent? filterUnsanitizedSentryEvent(SentryEvent event, Hint hint) {
  if (event.tags?[SentryAppErrorMonitoringSink.sanitizedTagKey] ==
      SentryAppErrorMonitoringSink.sanitizedTagValue) {
    return event;
  }
  return null;
}

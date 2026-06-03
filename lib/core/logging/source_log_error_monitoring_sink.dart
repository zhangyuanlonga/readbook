import 'error_monitoring_service.dart';
import 'source_log_store.dart';

class SourceLogAppErrorMonitoringSink implements AppErrorMonitoringSink {
  SourceLogAppErrorMonitoringSink({SourceLogStore? store})
    : _store = store ?? SourceLogStore.instance;

  final SourceLogStore _store;

  @override
  void capture(AppErrorMonitoringEvent event) {
    _store.add(
      AppLogEntry(
        timestamp: event.timestamp,
        level: AppLogLevel.error,
        message: event.message,
        context: <String, Object?>{
          'origin': event.origin,
          'severity': event.severity.name,
          ...event.context,
        },
      ),
    );
  }
}

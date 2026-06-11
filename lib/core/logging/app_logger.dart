import 'dart:async';

import 'package:logger/logger.dart';

import '../errors/app_exception.dart';
import 'error_monitoring_service.dart';
import 'source_log_store.dart';

class AppLogger {
  AppLogger._();

  static final AppLogger instance = AppLogger._();

  final Logger _logger = Logger(
    printer: PrettyPrinter(methodCount: 0, errorMethodCount: 8),
  );
  final SourceLogStore _store = SourceLogStore.instance;
  final AppErrorMonitoringService _monitoring =
      AppErrorMonitoringService.instance;

  /// Records verbose diagnostic information without reporting it as an error.
  void debug(String message, {Map<String, Object?> context = const {}}) {
    final sanitizedMessage = AppErrorMonitoringService.sanitizeMessage(message);
    final sanitizedContext = AppErrorMonitoringService.sanitizeContext(context);
    _store.add(
      AppLogEntry(
        timestamp: DateTime.now(),
        level: AppLogLevel.info,
        message: sanitizedMessage,
        context: sanitizedContext,
      ),
    );
    _logger.d(_joinMessage(sanitizedMessage, sanitizedContext));
  }

  void info(String message, {Map<String, Object?> context = const {}}) {
    final sanitizedMessage = AppErrorMonitoringService.sanitizeMessage(message);
    final sanitizedContext = AppErrorMonitoringService.sanitizeContext(context);
    _store.add(
      AppLogEntry(
        timestamp: DateTime.now(),
        level: AppLogLevel.info,
        message: sanitizedMessage,
        context: sanitizedContext,
      ),
    );
    _logger.i(_joinMessage(sanitizedMessage, sanitizedContext));
  }

  void warn(String message, {Map<String, Object?> context = const {}}) {
    final sanitizedMessage = AppErrorMonitoringService.sanitizeMessage(message);
    final sanitizedContext = AppErrorMonitoringService.sanitizeContext(context);
    _store.add(
      AppLogEntry(
        timestamp: DateTime.now(),
        level: AppLogLevel.warn,
        message: sanitizedMessage,
        context: sanitizedContext,
      ),
    );
    _logger.w(_joinMessage(sanitizedMessage, sanitizedContext));
  }

  void error(
    String message, {
    AppException? exception,
    Map<String, Object?> context = const {},
  }) {
    final merged = <String, Object?>{
      ...context,
      if (exception != null) ...{
        'code': exception.code.name,
        'stage': exception.stage.name,
        'sourceId': exception.sourceId,
        'requestUrl': exception.requestUrl,
      },
    };
    final sanitizedMessage = AppErrorMonitoringService.sanitizeMessage(message);
    final sanitizedMerged = AppErrorMonitoringService.sanitizeContext(merged);

    _store.add(
      AppLogEntry(
        timestamp: DateTime.now(),
        level: AppLogLevel.error,
        message: sanitizedMessage,
        context: sanitizedMerged,
      ),
    );

    _logger.e(
      _joinMessage(sanitizedMessage, sanitizedMerged),
      error: AppErrorMonitoringService.sanitizeThrowableForLog(
        exception?.cause ?? exception,
      ),
      stackTrace: exception?.stackTrace,
    );
    unawaited(
      _monitoring.captureLoggerError(
        message,
        exception: exception,
        context: context,
      ),
    );
  }

  String _joinMessage(String message, Map<String, Object?> context) {
    if (context.isEmpty) {
      return message;
    }

    final pairs = context.entries
        .where((entry) => entry.value != null)
        .map((entry) => '${entry.key}=${entry.value}')
        .join(', ');

    return '$message | $pairs';
  }
}

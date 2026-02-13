import 'package:logger/logger.dart';

import '../errors/app_exception.dart';
import 'source_log_store.dart';

class AppLogger {
  AppLogger._();

  static final AppLogger instance = AppLogger._();

  final Logger _logger = Logger(
    printer: PrettyPrinter(methodCount: 0, errorMethodCount: 8),
  );
  final SourceLogStore _store = SourceLogStore.instance;

  void info(String message, {Map<String, Object?> context = const {}}) {
    _store.add(
      AppLogEntry(
        timestamp: DateTime.now(),
        level: AppLogLevel.info,
        message: message,
        context: context,
      ),
    );
    _logger.i(_joinMessage(message, context));
  }

  void warn(String message, {Map<String, Object?> context = const {}}) {
    _store.add(
      AppLogEntry(
        timestamp: DateTime.now(),
        level: AppLogLevel.warn,
        message: message,
        context: context,
      ),
    );
    _logger.w(_joinMessage(message, context));
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

    _store.add(
      AppLogEntry(
        timestamp: DateTime.now(),
        level: AppLogLevel.error,
        message: message,
        context: merged,
        exception: exception,
      ),
    );

    _logger.e(
      _joinMessage(message, merged),
      error: exception?.cause ?? exception,
      stackTrace: exception?.stackTrace,
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

import 'dart:async';

import '../errors/app_exception.dart';

enum AppErrorMonitoringSeverity { error, fatal }

class AppErrorMonitoringConfig {
  const AppErrorMonitoringConfig({
    required this.remoteReportingEnabled,
    required this.sentryDsn,
    required this.environment,
  });

  static const bool _remoteEnabled = bool.fromEnvironment(
    'APP_ERROR_MONITORING_ENABLED',
    defaultValue: false,
  );
  static const String _sentryDsn = String.fromEnvironment(
    'APP_ERROR_MONITORING_DSN',
  );
  static const String _environment = String.fromEnvironment(
    'APP_ERROR_MONITORING_ENVIRONMENT',
    defaultValue: 'production',
  );

  factory AppErrorMonitoringConfig.fromEnvironment() {
    return const AppErrorMonitoringConfig(
      remoteReportingEnabled: _remoteEnabled,
      sentryDsn: _sentryDsn,
      environment: _environment,
    );
  }

  final bool remoteReportingEnabled;
  final String sentryDsn;
  final String environment;

  bool get shouldInitializeRemote =>
      remoteReportingEnabled && sentryDsn.trim().isNotEmpty;
}

class AppErrorMonitoringEvent {
  const AppErrorMonitoringEvent({
    required this.timestamp,
    required this.message,
    required this.origin,
    required this.severity,
    required this.context,
    this.throwable,
    this.stackTrace,
  });

  final DateTime timestamp;
  final String message;
  final String origin;
  final AppErrorMonitoringSeverity severity;
  final Map<String, Object?> context;
  final Object? throwable;
  final StackTrace? stackTrace;
}

abstract class AppErrorMonitoringSink {
  FutureOr<void> capture(AppErrorMonitoringEvent event);
}

class NoopAppErrorMonitoringSink implements AppErrorMonitoringSink {
  const NoopAppErrorMonitoringSink();

  @override
  void capture(AppErrorMonitoringEvent event) {}
}

class AppErrorMonitoringService {
  AppErrorMonitoringService._();

  static final AppErrorMonitoringService instance =
      AppErrorMonitoringService._();

  AppErrorMonitoringSink _sink = const NoopAppErrorMonitoringSink();
  bool _captureEnabled = false;

  bool get captureEnabled => _captureEnabled;

  void configure({
    required AppErrorMonitoringSink sink,
    required bool captureEnabled,
  }) {
    _sink = sink;
    _captureEnabled = captureEnabled;
  }

  void resetForTesting() {
    _sink = const NoopAppErrorMonitoringSink();
    _captureEnabled = false;
  }

  Future<void> captureLoggerError(
    String message, {
    AppException? exception,
    Map<String, Object?> context = const {},
  }) {
    return _capture(
      message,
      origin: 'app_logger',
      severity: AppErrorMonitoringSeverity.error,
      throwable: exception?.cause ?? exception,
      stackTrace: exception?.stackTrace,
      context: <String, Object?>{
        ...context,
        if (exception != null) ...{
          'code': exception.code.name,
          'stage': exception.stage.name,
          'sourceId': exception.sourceId,
          'requestUrl': exception.requestUrl,
        },
      },
    );
  }

  Future<void> captureUnhandledError(
    Object error,
    StackTrace stackTrace, {
    required String origin,
    AppErrorMonitoringSeverity severity = AppErrorMonitoringSeverity.fatal,
  }) {
    return _capture(
      'Unhandled ${error.runtimeType}',
      origin: origin,
      severity: severity,
      throwable: error,
      stackTrace: stackTrace,
    );
  }

  Future<void> _capture(
    String message, {
    required String origin,
    required AppErrorMonitoringSeverity severity,
    Object? throwable,
    StackTrace? stackTrace,
    Map<String, Object?> context = const {},
  }) async {
    if (!_captureEnabled) {
      return;
    }
    final event = AppErrorMonitoringEvent(
      timestamp: DateTime.now(),
      message: sanitizeMessage(message),
      origin: origin,
      severity: severity,
      context: sanitizeContext(context),
      throwable: _sanitizeThrowable(throwable),
      stackTrace: stackTrace,
    );
    await _sink.capture(event);
  }

  static Map<String, Object?> sanitizeContext(Map<String, Object?> context) {
    final result = <String, Object?>{};
    for (final entry in context.entries) {
      final value = entry.value;
      if (value == null) {
        continue;
      }
      result[entry.key] = _sanitizeValue(entry.key, value);
    }
    return result;
  }

  static String sanitizeMessage(String value) {
    return _sanitizeText(value);
  }

  static Object _sanitizeThrowable(Object? throwable) {
    if (throwable == null) {
      return const MonitoredException('UnknownError');
    }
    return MonitoredException(throwable.runtimeType.toString());
  }

  static Object sanitizeThrowableForLog(Object? throwable) {
    return _sanitizeThrowable(throwable);
  }

  static Object? _sanitizeValue(String key, Object? value) {
    final normalizedKey = key.toLowerCase();
    if (_isSensitiveKey(normalizedKey)) {
      return '[redacted]';
    }
    if (_isPathKey(normalizedKey)) {
      return '[redacted-path]';
    }
    if (value is Uri) {
      return _sanitizeUrl(value);
    }
    if (value is String) {
      if (_isUrlKey(normalizedKey) || _looksLikeUrl(value)) {
        return _sanitizeUrl(Uri.tryParse(value));
      }
      return _sanitizeText(value);
    }
    if (value is num || value is bool) {
      return value;
    }
    if (value is DateTime) {
      return value.toIso8601String();
    }
    if (value is Enum) {
      return value.name;
    }
    if (value is Iterable) {
      return value
          .map((item) => _sanitizeValue(key, item))
          .toList(growable: false);
    }
    if (value is Map) {
      return value.map(
        (nestedKey, nestedValue) => MapEntry(
          nestedKey.toString(),
          _sanitizeValue(nestedKey.toString(), nestedValue),
        ),
      );
    }
    return _sanitizeText(value.toString());
  }

  static bool _isSensitiveKey(String key) {
    return key.contains('token') ||
        key.contains('authorization') ||
        key.contains('cookie') ||
        key.contains('password') ||
        key.contains('secret') ||
        key.contains('credential') ||
        key.contains('session') ||
        key.contains('deviceuid') ||
        key.contains('fingerprint') ||
        key.contains('stacktrace');
  }

  static bool _isPathKey(String key) {
    return key == 'path' ||
        key.endsWith('path') ||
        key.contains('directory') ||
        key.contains('filepath') ||
        key.contains('root');
  }

  static bool _isUrlKey(String key) {
    return key.contains('url') || key.contains('uri') || key == 'endpoint';
  }

  static bool _looksLikeUrl(String value) {
    final trimmed = value.trimLeft();
    return trimmed.startsWith('http://') || trimmed.startsWith('https://');
  }

  static String _sanitizeUrl(Uri? uri) {
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return '[redacted-url]';
    }
    return Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      path: uri.path,
    ).toString();
  }

  static String _sanitizeText(String value) {
    final withoutBearer = value.replaceAll(
      RegExp(r'Bearer\s+[A-Za-z0-9._~+/=-]+', caseSensitive: false),
      'Bearer [redacted]',
    );
    final withoutTokenQuery = withoutBearer.replaceAll(
      RegExp(r'([?&](?:token|access_token|refresh_token|sid|session)=)[^&\s]+'),
      r'$1[redacted]',
    );
    if (withoutTokenQuery.length <= 240) {
      return withoutTokenQuery;
    }
    return '${withoutTokenQuery.substring(0, 237)}...';
  }
}

class MonitoredException implements Exception {
  const MonitoredException(this.typeName);

  final String typeName;

  @override
  String toString() {
    return typeName;
  }
}

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../core/logging/error_monitoring_service.dart';
import '../core/logging/sentry_error_monitoring_sink.dart';
import '../core/logging/source_log_error_monitoring_sink.dart';

typedef AppBootstrapRunner = Future<void> Function();

bool _hooksInstalled = false;

Future<void> runAppWithErrorMonitoring(
  AppBootstrapRunner appRunner, {
  AppErrorMonitoringConfig? config,
}) async {
  final resolvedConfig = config ?? AppErrorMonitoringConfig.fromEnvironment();
  final monitoring = AppErrorMonitoringService.instance;

  if (!resolvedConfig.shouldInitializeRemote) {
    monitoring.configure(
      sink: SourceLogAppErrorMonitoringSink(),
      captureEnabled: true,
    );
    _installGlobalErrorHooks(monitoring);
    return _runInMonitoringZone(monitoring, appRunner);
  }

  try {
    await SentryFlutter.init(
      (options) {
        options
          ..dsn = resolvedConfig.sentryDsn
          ..environment = resolvedConfig.environment
          ..sendDefaultPii = false
          ..attachScreenshot = false
          ..enableAutoPerformanceTracing = false
          ..enableUserInteractionBreadcrumbs = false
          ..enableUserInteractionTracing = false
          ..tracesSampleRate = 0
          ..beforeSend = filterUnsanitizedSentryEvent;
      },
      appRunner: () {
        monitoring.configure(
          sink: const SentryAppErrorMonitoringSink(),
          captureEnabled: true,
        );
        _installGlobalErrorHooks(monitoring);
        return _runInMonitoringZone(monitoring, appRunner);
      },
    );
  } catch (error, stackTrace) {
    monitoring.configure(
      sink: SourceLogAppErrorMonitoringSink(),
      captureEnabled: true,
    );
    _installGlobalErrorHooks(monitoring);
    unawaited(
      monitoring.captureUnhandledError(
        error,
        stackTrace,
        origin: 'sentry_init',
        severity: AppErrorMonitoringSeverity.error,
      ),
    );
    await _runInMonitoringZone(monitoring, appRunner);
  }
}

Future<void> _runInMonitoringZone(
  AppErrorMonitoringService monitoring,
  AppBootstrapRunner appRunner,
) {
  return runZonedGuarded<Future<void>>(appRunner, (error, stackTrace) {
        unawaited(
          monitoring.captureUnhandledError(error, stackTrace, origin: 'zone'),
        );
      }) ??
      Future<void>.value();
}

void _installGlobalErrorHooks(AppErrorMonitoringService monitoring) {
  if (_hooksInstalled) {
    return;
  }
  _hooksInstalled = true;

  final previousFlutterOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    if (previousFlutterOnError != null) {
      previousFlutterOnError(details);
    } else {
      FlutterError.presentError(details);
    }
    unawaited(
      monitoring.captureUnhandledError(
        details.exception,
        details.stack ?? StackTrace.current,
        origin: 'flutter',
        severity: AppErrorMonitoringSeverity.error,
      ),
    );
  };

  final previousPlatformOnError = PlatformDispatcher.instance.onError;
  PlatformDispatcher.instance.onError = (error, stackTrace) {
    unawaited(
      monitoring.captureUnhandledError(
        error,
        stackTrace,
        origin: 'platform_dispatcher',
      ),
    );
    return previousPlatformOnError?.call(error, stackTrace) ?? true;
  };
}

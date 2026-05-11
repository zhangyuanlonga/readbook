import 'dart:async';
import 'dart:ui' show FrameTiming;

import 'package:flutter/widgets.dart';

import '../../core/app_update/app_update_release.dart';
import '../../core/app_update/app_update_service.dart';
import '../../core/logging/app_logger.dart';
import '../../features/source/application/source_runtime_facade.dart';

typedef StartupUpdateDialogPresenter =
    Future<void> Function(BuildContext context, AppUpdateRelease release);

class AppStartupCoordinator {
  AppStartupCoordinator({
    required Future<void> Function() sendHeartbeat,
    required Future<void> Function() sendVisitEvent,
    required VoidCallback showStartupAnnouncementIfNeeded,
    required Future<BuildContext?> Function() resolveDialogContext,
    required StartupUpdateDialogPresenter showUpdateDialog,
    AppLogger? logger,
    AppUpdateService? appUpdateService,
    SourceRuntimeFacade? sourceRuntimeFacade,
  }) : _sendHeartbeat = sendHeartbeat,
       _sendVisitEvent = sendVisitEvent,
       _showStartupAnnouncementIfNeeded = showStartupAnnouncementIfNeeded,
       _resolveDialogContext = resolveDialogContext,
       _showUpdateDialog = showUpdateDialog,
       _logger = logger ?? AppLogger.instance,
       _appUpdateService = appUpdateService ?? AppUpdateService(),
       _sourceRuntimeFacade = sourceRuntimeFacade;

  static const Duration _startupMinDuration = Duration(milliseconds: 250);
  static const Duration _startupDeferredTasksDelay = Duration(
    milliseconds: 1800,
  );
  static const Duration _startupTaskGap = Duration(milliseconds: 320);
  static const Duration _startupAnnouncementDelay = Duration(milliseconds: 480);

  final Future<void> Function() _sendHeartbeat;
  final Future<void> Function() _sendVisitEvent;
  final VoidCallback _showStartupAnnouncementIfNeeded;
  final Future<BuildContext?> Function() _resolveDialogContext;
  final StartupUpdateDialogPresenter _showUpdateDialog;
  final AppLogger _logger;
  final AppUpdateService _appUpdateService;
  final SourceRuntimeFacade? _sourceRuntimeFacade;

  final Stopwatch _startupStopwatch = Stopwatch()..start();
  final Completer<void> _startupFirstFrameCompleter = Completer<void>();

  Timer? _startupDelayTimer;
  Timer? _startupDeferredTasksTimer;
  bool _startupDeferredTasksScheduled = false;
  bool _isStartupUpdateInFlight = false;
  bool _hasCheckedStartupUpdate = false;
  bool _firstFrameMetricsLogged = false;

  int get elapsedMilliseconds => _startupStopwatch.elapsedMilliseconds;

  void notifyFirstFrameCallback() {
    if (!_startupFirstFrameCompleter.isCompleted) {
      _startupFirstFrameCompleter.complete();
    }
    _logger.info(
      'Startup first frame callback',
      context: <String, Object?>{'elapsedMs': elapsedMilliseconds},
    );
  }

  void onFrameTimings(List<FrameTiming> timings) {
    if (_firstFrameMetricsLogged || timings.isEmpty) {
      return;
    }
    _firstFrameMetricsLogged = true;
    final frame = timings.first;
    _logger.info(
      'Startup first frame timing',
      context: <String, Object?>{
        'buildMs': frame.buildDuration.inMilliseconds,
        'rasterMs': frame.rasterDuration.inMilliseconds,
        'totalMs': frame.totalSpan.inMilliseconds,
        'vsyncOverheadMs': frame.vsyncOverhead.inMilliseconds,
        'elapsedMs': elapsedMilliseconds,
      },
    );
  }

  Future<void> prepareStartup({
    required bool Function() isMounted,
    Future<void> Function()? waitUntilReady,
    required VoidCallback markStartupReady,
  }) async {
    await _startupFirstFrameCompleter.future;
    await waitUntilReady?.call();
    final remainingDelay = _startupMinDuration - _startupStopwatch.elapsed;
    await _waitStartupDelay(remainingDelay);

    if (!isMounted()) {
      return;
    }

    markStartupReady();
    _logger.info(
      'Startup ready',
      context: <String, Object?>{'elapsedMs': elapsedMilliseconds},
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_warmupLocalDatabase());
      scheduleDeferredTasks(isMounted: isMounted);
    });
  }

  void scheduleDeferredTasks({required bool Function() isMounted}) {
    if (_startupDeferredTasksScheduled) {
      return;
    }
    _startupDeferredTasksScheduled = true;
    _startupDeferredTasksTimer?.cancel();
    _startupDeferredTasksTimer = Timer(_startupDeferredTasksDelay, () {
      unawaited(_runStartupDeferredTasks(isMounted: isMounted));
    });
  }

  void dispose() {
    _startupDelayTimer?.cancel();
    _startupDeferredTasksTimer?.cancel();
  }

  Future<void> _warmupLocalDatabase() async {
    final sourceRuntimeFacade = _sourceRuntimeFacade;
    if (sourceRuntimeFacade == null) {
      _logger.info(
        'Startup warmup local database skipped',
        context: <String, Object?>{
          'reason': 'source_runtime_disabled',
          'elapsedMs': elapsedMilliseconds,
        },
      );
      return;
    }

    final stopwatch = Stopwatch()..start();
    try {
      await sourceRuntimeFacade.listScriptSources();
    } catch (_) {
      // Ignore warmup failures to avoid affecting app startup or first frame.
    } finally {
      _logger.info(
        'Startup warmup local database',
        context: <String, Object?>{
          'costMs': stopwatch.elapsedMilliseconds,
          'elapsedMs': elapsedMilliseconds,
        },
      );
    }
  }

  Future<void> _checkStartupUpdateIfNeeded({
    required bool Function() isMounted,
  }) async {
    if (_hasCheckedStartupUpdate || _isStartupUpdateInFlight) {
      return;
    }
    _isStartupUpdateInFlight = true;
    try {
      final result = await _appUpdateService.checkUpdate();
      _hasCheckedStartupUpdate = true;
      final release = result.release;
      if (!isMounted() || !result.hasUpdate || release == null) {
        return;
      }
      final dialogContext = await _resolveDialogContext();
      if (!isMounted() || dialogContext == null || !dialogContext.mounted) {
        return;
      }
      await _showUpdateDialog(dialogContext, release);
    } catch (_) {
      _hasCheckedStartupUpdate = true;
    } finally {
      _isStartupUpdateInFlight = false;
    }
  }

  Future<void> _runStartupDeferredTasks({
    required bool Function() isMounted,
  }) async {
    if (!isMounted()) {
      return;
    }
    _logger.info(
      'Startup deferred tasks begin',
      context: <String, Object?>{'elapsedMs': elapsedMilliseconds},
    );
    _showStartupAnnouncementIfNeeded();
    await _waitDeferredGap(_startupAnnouncementDelay, isMounted: isMounted);
    if (!isMounted()) {
      return;
    }
    await _runStartupDeferredTask(name: 'heartbeat', task: _sendHeartbeat);
    await _waitDeferredGap(_startupTaskGap, isMounted: isMounted);
    await _runStartupDeferredTask(name: 'visit', task: _sendVisitEvent);
    await _waitDeferredGap(_startupTaskGap, isMounted: isMounted);
    await _runStartupDeferredTask(
      name: 'updateCheck',
      task: () => _checkStartupUpdateIfNeeded(isMounted: isMounted),
    );
    _logger.info(
      'Startup deferred tasks complete',
      context: <String, Object?>{'elapsedMs': elapsedMilliseconds},
    );
  }

  Future<void> _runStartupDeferredTask({
    required String name,
    required Future<void> Function() task,
  }) async {
    final stopwatch = Stopwatch()..start();
    await task();
    _logger.info(
      'Startup deferred task complete',
      context: <String, Object?>{
        'task': name,
        'costMs': stopwatch.elapsedMilliseconds,
        'elapsedMs': elapsedMilliseconds,
      },
    );
  }

  Future<void> _waitDeferredGap(
    Duration duration, {
    required bool Function() isMounted,
  }) async {
    if (!isMounted() || duration <= Duration.zero) {
      return;
    }
    await Future<void>.delayed(duration);
  }

  Future<void> _waitStartupDelay(Duration delay) {
    if (delay <= Duration.zero) {
      return Future<void>.value();
    }

    final completer = Completer<void>();
    _startupDelayTimer?.cancel();
    _startupDelayTimer = Timer(delay, () {
      if (!completer.isCompleted) {
        completer.complete();
      }
    });

    return completer.future;
  }
}

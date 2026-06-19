import 'dart:async';
import 'dart:ui' show FrameTiming;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../cache/app_cache_store_registry.dart';
import '../../core/cache/app_cache_governance_service.dart';
import '../../core/app_update/app_update_release.dart';
import '../../core/app_update/app_update_service.dart';
import '../../core/logging/app_logger.dart';
import '../../core/preferences/deprecated_keys_cleaner.dart';
import '../../data/datasources/local/app_database.dart';
import 'startup_task_gate_service.dart';

typedef StartupUpdateDialogPresenter =
    Future<void> Function(BuildContext context, AppUpdateRelease release);

class AppStartupCoordinator {
  AppStartupCoordinator({
    required Future<void> Function() sendHeartbeat,
    required Future<void> Function() sendVisitEvent,
    required Future<void> Function() validateStartupAuthSession,
    required VoidCallback showStartupAnnouncementIfNeeded,
    required Future<BuildContext?> Function() resolveDialogContext,
    required StartupUpdateDialogPresenter showUpdateDialog,
    AppLogger? logger,
    AppUpdateService? appUpdateService,
    StartupTaskGateService? taskGateService,
    DeprecatedKeysCleaner? deprecatedKeysCleaner,
    AppCacheGovernanceService? cacheGovernanceService,
    AppDatabase? database,
    Duration? startupMinDuration,
    Duration? startupDeferredTasksDelay,
  }) : _sendHeartbeat = sendHeartbeat,
       _sendVisitEvent = sendVisitEvent,
       _validateStartupAuthSession = validateStartupAuthSession,
       _showStartupAnnouncementIfNeeded = showStartupAnnouncementIfNeeded,
       _resolveDialogContext = resolveDialogContext,
       _showUpdateDialog = showUpdateDialog,
       _logger = logger ?? AppLogger.instance,
       _appUpdateService = appUpdateService ?? AppUpdateService(),
       _taskGateService = taskGateService ?? StartupTaskGateService(),
       _deprecatedKeysCleaner =
           deprecatedKeysCleaner ?? DeprecatedKeysCleaner(),
       _cacheGovernanceService =
           cacheGovernanceService ??
           AppCacheGovernanceService(
             extraStores: buildDefaultFeatureCacheStores(),
           ),
       _database = database ?? AppDatabase.instance,
       _startupMinDuration = startupMinDuration ?? _defaultStartupMinDuration,
       _startupDeferredTasksDelay =
           startupDeferredTasksDelay ?? _defaultStartupDeferredTasksDelay;

  static const Duration _defaultStartupMinDuration = Duration(
    milliseconds: 250,
  );
  static const Duration _defaultStartupDeferredTasksDelay = Duration(
    seconds: 3,
  );
  static const Duration _startupTaskGap = Duration(milliseconds: 320);
  static const Duration _startupAnnouncementDelay = Duration(milliseconds: 480);
  static const Duration _storageMaintenanceInterval = Duration(days: 7);

  final Future<void> Function() _sendHeartbeat;
  final Future<void> Function() _sendVisitEvent;
  final Future<void> Function() _validateStartupAuthSession;
  final VoidCallback _showStartupAnnouncementIfNeeded;
  final Future<BuildContext?> Function() _resolveDialogContext;
  final StartupUpdateDialogPresenter _showUpdateDialog;
  final AppLogger _logger;
  final AppUpdateService _appUpdateService;
  final StartupTaskGateService _taskGateService;
  final DeprecatedKeysCleaner _deprecatedKeysCleaner;
  final AppCacheGovernanceService _cacheGovernanceService;
  final AppDatabase _database;
  final Duration _startupMinDuration;
  final Duration _startupDeferredTasksDelay;

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

  Future<void> _checkStartupUpdateIfNeeded({
    required bool Function() isMounted,
  }) async {
    if (kIsWeb) {
      _hasCheckedStartupUpdate = true;
      return;
    }
    if (_hasCheckedStartupUpdate || _isStartupUpdateInFlight) {
      return;
    }
    final shouldRun = await _taskGateService.claimDailyRun(
      'startup_update_check',
    );
    if (!shouldRun) {
      _hasCheckedStartupUpdate = true;
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
    await _runStartupDeferredTask(
      name: 'deprecatedPreferenceCleanup',
      task: _cleanupDeprecatedPreferenceKeys,
    );
    await _waitDeferredGap(_startupTaskGap, isMounted: isMounted);
    await _runStartupDeferredTask(
      name: 'cacheBudgetEnforcement',
      task: _enforceCacheBudgets,
    );
    await _waitDeferredGap(_startupTaskGap, isMounted: isMounted);
    await _runStartupDeferredTask(
      name: 'storageMaintenance',
      task: _runStorageMaintenanceIfNeeded,
    );
    await _waitDeferredGap(_startupTaskGap, isMounted: isMounted);
    await _runStartupDeferredTask(
      name: 'startupAuthValidation',
      task: _validateStartupAuthSession,
    );
    await _waitDeferredGap(_startupTaskGap, isMounted: isMounted);
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

  Future<void> _cleanupDeprecatedPreferenceKeys() async {
    final result = await _deprecatedKeysCleaner.cleanOnce();
    _logger.info(
      'Deprecated preference cleanup complete',
      context: <String, Object?>{
        'cleaned': result.cleaned,
        'removedCount': result.removedCount,
        'removedKeys':
            result.removedKeys.isEmpty ? null : result.removedKeys.join(','),
      },
    );
  }

  Future<void> _enforceCacheBudgets() async {
    await _cacheGovernanceService.enforceBudgets(collectSnapshot: false);
  }

  Future<void> _runStorageMaintenanceIfNeeded() async {
    final shouldRun = await _taskGateService.claimIntervalRun(
      'storage_maintenance',
      minInterval: _storageMaintenanceInterval,
    );
    if (!shouldRun) {
      _logger.info(
        'Storage maintenance skipped by task gate',
        context: <String, Object?>{
          'minIntervalDays': _storageMaintenanceInterval.inDays,
        },
      );
      return;
    }
    final report = await _database.runStorageMaintenance();
    _logger.info(
      'Storage maintenance complete',
      context: <String, Object?>{
        'totalDeleted': report.totalDeleted,
        'orphanedLocalReadingProgresses': report.orphanedLocalReadingProgresses,
        'orphanedLocalReadingRecords': report.orphanedLocalReadingRecords,
        'orphanedLocalReadingRecordSessions':
            report.orphanedLocalReadingRecordSessions,
        'orphanedLocalReadingBookStatuses':
            report.orphanedLocalReadingBookStatuses,
        'orphanedLocalTocSnapshots': report.orphanedLocalTocSnapshots,
        'orphanedLocalMetadataOverrides': report.orphanedLocalMetadataOverrides,
        'staleSearchSourceHits': report.staleSearchSourceHits,
      },
    );
  }

  Future<void> _runStartupDeferredTask({
    required String name,
    required Future<void> Function() task,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      await task();
      _logger.info(
        'Startup deferred task complete',
        context: <String, Object?>{
          'task': name,
          'costMs': stopwatch.elapsedMilliseconds,
          'elapsedMs': elapsedMilliseconds,
        },
      );
    } catch (error, stackTrace) {
      _logger.warn(
        'Startup deferred task failed',
        context: <String, Object?>{
          'task': name,
          'costMs': stopwatch.elapsedMilliseconds,
          'elapsedMs': elapsedMilliseconds,
          'error': error.toString(),
          'stackTrace': stackTrace.toString(),
        },
      );
    }
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

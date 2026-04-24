import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show FrameTiming;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:responsive_framework/responsive_framework.dart';
import '../core/analytics/analytics_service.dart';
import '../core/app_update/app_update_dialog.dart';
import '../core/app_update/app_update_service.dart';
import '../core/auth/auth_event_bus.dart';
import '../core/auth/auth_token_refresher_impl.dart';
import '../core/device/device_identity_service.dart';
import '../core/device/device_heartbeat_service.dart';
import '../core/logging/app_logger.dart';
import '../core/network/api_client.dart';
import '../domain/entities/announcement.dart';
import '../features/announcement/application/announcement_read_state_service.dart';
import '../features/announcement/application/announcement_service.dart';
import '../features/mine/application/advanced_theme_provider.dart';
import '../features/source/application/external_source_import_bridge.dart';
import '../features/source/application/source_runtime_facade.dart';
import 'layout/app_layout.dart';
import 'layout/app_spacing.dart';
import 'router.dart';
import 'startup_artwork_store.dart';
import 'theme/app_advanced_theme_tokens.dart';
import 'theme/app_theme.dart';
import 'theme/app_interface_typography_provider.dart';
import 'theme/app_theme_palette.dart';
import 'theme/app_theme_provider.dart';
import 'theme/app_theme_seed_provider.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seedColor = ref.watch(appSeedColorProvider);
    final themeMode = ref.watch(appThemeModeProvider);
    final interfaceFontSettings = ref.watch(appInterfaceFontSettingsProvider);
    final interfaceTextScale = ref.watch(appInterfaceTextScaleProvider);
    final interfaceFontWeight = ref.watch(appInterfaceFontWeightProvider);
    final activeAdvancedTheme =
        ref.watch(activeAdvancedThemeProvider).valueOrNull;

    final lightScheme = buildAppLightColorScheme(seedColor);
    final darkScheme = buildAppDarkColorScheme(seedColor);
    final lightAdvancedPalette = resolveAdvancedThemePaletteFromModeConfig(
      lightScheme,
      activeAdvancedTheme?.lightConfig,
    );
    final darkAdvancedPalette = resolveAdvancedThemePaletteFromModeConfig(
      darkScheme,
      activeAdvancedTheme?.darkConfig,
    );
    final lightAdvancedBackdrop = resolveAdvancedThemeBackdropFromModeConfig(
      lightScheme,
      activeAdvancedTheme?.lightConfig,
    );
    final darkAdvancedBackdrop = resolveAdvancedThemeBackdropFromModeConfig(
      darkScheme,
      activeAdvancedTheme?.darkConfig,
    );
    final fontFamily = resolveAppInterfaceFontFamily(interfaceFontSettings);
    final fontWeight = appInterfaceFontWeightValue(interfaceFontWeight);

    return MaterialApp.router(
      title: 'Selune',
      theme: AppTheme.build(
        lightScheme,
        advancedPalette: lightAdvancedPalette,
        advancedBackdrop: lightAdvancedBackdrop,
        fontFamily: fontFamily,
        fontWeight: fontWeight,
      ),
      darkTheme: AppTheme.build(
        darkScheme,
        advancedPalette: darkAdvancedPalette,
        advancedBackdrop: darkAdvancedBackdrop,
        fontFamily: fontFamily,
        fontWeight: fontWeight,
      ),
      themeMode: themeMode,
      themeAnimationDuration: const Duration(milliseconds: 180),
      themeAnimationCurve: Curves.easeOutCubic,
      routerConfig: appRouter,
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        final textScale = AppLayout.clampedTextScaleFactor(
          context,
          multiplier: interfaceTextScale,
        );
        final appChild = _SystemUiOverlayWrapper(
          child: child ?? const SizedBox.shrink(),
        );
        final responsiveChild = ResponsiveBreakpoints.builder(
          breakpoints: AppLayout.responsiveBreakpoints,
          child: appChild,
        );

        return MediaQuery(
          data: mediaQuery.copyWith(textScaler: TextScaler.linear(textScale)),
          child: responsiveChild,
        );
      },
    );
  }
}

class _SystemUiOverlayWrapper extends StatefulWidget {
  const _SystemUiOverlayWrapper({required this.child});

  final Widget child;

  @override
  State<_SystemUiOverlayWrapper> createState() =>
      _SystemUiOverlayWrapperState();
}

class _SystemUiOverlayWrapperState extends State<_SystemUiOverlayWrapper>
    with WidgetsBindingObserver {
  StreamSubscription<IncomingExternalImportPayload>? _incomingImportSub;
  StreamSubscription<AuthEvent>? _authEventSub;
  Brightness? _lastBrightness;
  bool _hasShownStartupAnnouncement = false;
  bool _startupAnnouncementScheduled = false;
  int _startupAnnouncementRetryCount = 0;
  bool _isStartupReady = false;
  Timer? _startupDelayTimer;
  Timer? _startupDeferredTasksTimer;
  bool _startupDeferredTasksScheduled = false;
  final AnnouncementService _announcementService = AnnouncementService();
  final AnnouncementReadStateService _announcementReadStateService =
      AnnouncementReadStateService();
  final AppUpdateService _appUpdateService = AppUpdateService();
  final DeviceIdentityService _deviceIdentityService = DeviceIdentityService();
  late final AuthTokenRefresherImpl _authTokenRefresher =
      AuthTokenRefresherImpl();
  late final DeviceHeartbeatService _deviceHeartbeatService =
      DeviceHeartbeatService(identityService: _deviceIdentityService);
  late final AnalyticsService _analyticsService = AnalyticsService(
    identityService: _deviceIdentityService,
  );
  bool _isHeartbeatInFlight = false;
  bool _isVisitInFlight = false;
  bool _isStartupUpdateInFlight = false;
  bool _hasCheckedStartupUpdate = false;
  DateTime? _lastHeartbeatAt;
  static const List<String> _dialogFontFallback = [
    'STKaiti',
    'Kaiti SC',
    'KaiTi',
    'Songti SC',
    'Noto Serif CJK SC',
    'serif',
  ];

  static const Duration _kStartupMinDuration = Duration(milliseconds: 250);
  static const Duration _kStartupDeferredTasksDelay = Duration(
    milliseconds: 1800,
  );
  static const Duration _kStartupTaskGap = Duration(milliseconds: 320);
  static const Duration _kStartupAnnouncementDelay = Duration(
    milliseconds: 480,
  );
  static const Duration _kHeartbeatThrottle = Duration(minutes: 2);
  final Stopwatch _startupStopwatch = Stopwatch()..start();
  bool _firstFrameMetricsLogged = false;
  final Completer<void> _startupFirstFrameCompleter = Completer<void>();

  @override
  void initState() {
    super.initState();
    AppLogger.instance.info('Startup init begin');
    ApiClient.defaultAuthTokenRefresher ??= _authTokenRefresher;
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addTimingsCallback(_onFrameTimings);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_startupFirstFrameCompleter.isCompleted) {
        _startupFirstFrameCompleter.complete();
      }
      AppLogger.instance.info(
        'Startup first frame callback',
        context: <String, Object?>{
          'elapsedMs': _startupStopwatch.elapsedMilliseconds,
        },
      );
    });
    _incomingImportSub = ExternalImportBridge.instance.payloadStream.listen(
      _onIncomingExternalImportPayload,
    );
    _authEventSub = AuthEventBus.instance.stream.listen(_handleAuthEvent);
    unawaited(ExternalImportBridge.instance.initialize());
    unawaited(_prepareStartup());
  }

  Future<void> _prepareStartup() async {
    await _startupFirstFrameCompleter.future;
    final remainingDelay = _kStartupMinDuration - _startupStopwatch.elapsed;
    await _waitStartupDelay(remainingDelay);

    if (!mounted) {
      return;
    }

    setState(() {
      _isStartupReady = true;
    });
    AppLogger.instance.info(
      'Startup ready',
      context: <String, Object?>{
        'elapsedMs': _startupStopwatch.elapsedMilliseconds,
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_warmupLocalDatabase());
      _scheduleStartupDeferredTasks();
    });
  }

  Future<void> _warmupLocalDatabase() async {
    final stopwatch = Stopwatch()..start();
    try {
      await SourceRuntimeFacade.instance.listScriptSources();
    } catch (_) {
      // Ignore warmup failures to avoid affecting app startup or first frame.
    } finally {
      AppLogger.instance.info(
        'Startup warmup local database',
        context: <String, Object?>{
          'costMs': stopwatch.elapsedMilliseconds,
          'elapsedMs': _startupStopwatch.elapsedMilliseconds,
        },
      );
    }
  }

  Future<BuildContext?> _resolveStartupDialogContext() async {
    for (var attempt = 0; attempt < 12; attempt += 1) {
      final navigatorContext = appRootNavigatorKey.currentContext;
      if (navigatorContext != null) {
        return navigatorContext;
      }
      await Future<void>.delayed(const Duration(milliseconds: 60));
    }
    return appRootNavigatorKey.currentContext;
  }

  Future<void> _checkStartupUpdateIfNeeded() async {
    if (_hasCheckedStartupUpdate || _isStartupUpdateInFlight) {
      return;
    }
    _isStartupUpdateInFlight = true;
    try {
      final result = await _appUpdateService.checkUpdate();
      _hasCheckedStartupUpdate = true;
      final release = result.release;
      if (!mounted || !result.hasUpdate || release == null) {
        return;
      }
      final dialogContext = await _resolveStartupDialogContext();
      if (!mounted || dialogContext == null || !dialogContext.mounted) {
        return;
      }
      await AppUpdateDialog.showUpdateDialog(dialogContext, release);
    } catch (_) {
      _hasCheckedStartupUpdate = true;
    } finally {
      _isStartupUpdateInFlight = false;
    }
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

  void _scheduleStartupDeferredTasks() {
    if (_startupDeferredTasksScheduled) {
      return;
    }
    _startupDeferredTasksScheduled = true;
    _startupDeferredTasksTimer?.cancel();
    _startupDeferredTasksTimer = Timer(_kStartupDeferredTasksDelay, () {
      unawaited(_runStartupDeferredTasks());
    });
  }

  Future<void> _runStartupDeferredTasks() async {
    if (!mounted) {
      return;
    }
    AppLogger.instance.info(
      'Startup deferred tasks begin',
      context: <String, Object?>{
        'elapsedMs': _startupStopwatch.elapsedMilliseconds,
      },
    );
    _showStartupAnnouncementIfNeeded();
    await _waitDeferredGap(_kStartupAnnouncementDelay);
    if (!mounted) {
      return;
    }
    await _runStartupDeferredTask(name: 'heartbeat', task: _sendHeartbeat);
    await _waitDeferredGap(_kStartupTaskGap);
    await _runStartupDeferredTask(name: 'visit', task: _sendVisitEvent);
    await _waitDeferredGap(_kStartupTaskGap);
    await _runStartupDeferredTask(
      name: 'updateCheck',
      task: _checkStartupUpdateIfNeeded,
    );
    AppLogger.instance.info(
      'Startup deferred tasks complete',
      context: <String, Object?>{
        'elapsedMs': _startupStopwatch.elapsedMilliseconds,
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_sendHeartbeat());
      unawaited(_sendVisitEvent());
    }
  }

  Future<void> _sendHeartbeat() async {
    if (_isHeartbeatInFlight) {
      return;
    }
    final now = DateTime.now();
    final last = _lastHeartbeatAt;
    if (last != null && now.difference(last) < _kHeartbeatThrottle) {
      return;
    }
    _isHeartbeatInFlight = true;
    try {
      await _deviceHeartbeatService.sendHeartbeat();
      _lastHeartbeatAt = now;
    } catch (_) {
      // Ignore heartbeat failures to avoid blocking startup or resume.
    } finally {
      _isHeartbeatInFlight = false;
    }
  }

  Future<void> _sendVisitEvent() async {
    if (_isVisitInFlight) {
      return;
    }
    _isVisitInFlight = true;
    try {
      await _analyticsService.trackVisit(visitCount: 1, visitSeconds: 0);
    } catch (_) {
      // Ignore analytics failures to avoid blocking startup or resume.
    } finally {
      _isVisitInFlight = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    WidgetsBinding.instance.removeTimingsCallback(_onFrameTimings);
    _incomingImportSub?.cancel();
    _authEventSub?.cancel();
    _startupDelayTimer?.cancel();
    _startupDeferredTasksTimer?.cancel();
    super.dispose();
  }

  Future<void> _runStartupDeferredTask({
    required String name,
    required Future<void> Function() task,
  }) async {
    final stopwatch = Stopwatch()..start();
    await task();
    AppLogger.instance.info(
      'Startup deferred task complete',
      context: <String, Object?>{
        'task': name,
        'costMs': stopwatch.elapsedMilliseconds,
        'elapsedMs': _startupStopwatch.elapsedMilliseconds,
      },
    );
  }

  Future<void> _waitDeferredGap(Duration duration) async {
    if (!mounted || duration <= Duration.zero) {
      return;
    }
    await Future<void>.delayed(duration);
  }

  void _onFrameTimings(List<FrameTiming> timings) {
    if (_firstFrameMetricsLogged || timings.isEmpty) {
      return;
    }
    _firstFrameMetricsLogged = true;
    final frame = timings.first;
    AppLogger.instance.info(
      'Startup first frame timing',
      context: <String, Object?>{
        'buildMs': frame.buildDuration.inMilliseconds,
        'rasterMs': frame.rasterDuration.inMilliseconds,
        'totalMs': frame.totalSpan.inMilliseconds,
        'vsyncOverheadMs': frame.vsyncOverhead.inMilliseconds,
        'elapsedMs': _startupStopwatch.elapsedMilliseconds,
      },
    );
  }

  void _handleAuthEvent(AuthEvent event) {
    if (!mounted) {
      return;
    }
    if (event.type == AuthEventType.loggedIn) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    if (!mounted) {
      return;
    }

    final action =
        event.type == AuthEventType.sessionExpired
            ? SnackBarAction(
              label: '去登录',
              onPressed: () {
                if (!mounted) {
                  return;
                }
                appRouter.push('/auth');
              },
            )
            : null;

    messenger.showSnackBar(
      SnackBar(content: Text(event.message), action: action),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final brightness = Theme.of(context).brightness;
    if (_lastBrightness == brightness) {
      return;
    }
    _lastBrightness = brightness;

    final base =
        brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark;

    final style = base.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
    );

    SystemChrome.setSystemUIOverlayStyle(style);
  }

  void _showStartupAnnouncementIfNeeded() {
    if (!_isStartupReady ||
        _hasShownStartupAnnouncement ||
        _startupAnnouncementScheduled) {
      return;
    }

    _startupAnnouncementScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startupAnnouncementScheduled = false;
      if (!mounted || _hasShownStartupAnnouncement) {
        return;
      }

      final navigatorContext = appRootNavigatorKey.currentContext;
      if (navigatorContext == null) {
        if (_startupAnnouncementRetryCount < 10) {
          _startupAnnouncementRetryCount += 1;
          _showStartupAnnouncementIfNeeded();
        }
        return;
      }

      _startupAnnouncementRetryCount = 0;
      unawaited(_tryShowLatestAnnouncement());
    });
  }

  Future<void> _tryShowLatestAnnouncement() async {
    Announcement? latest;
    try {
      latest = await _announcementService.fetchLatestAnnouncement();
    } catch (_) {
      return;
    }

    if (!mounted) {
      return;
    }

    final announcement = latest;
    if (announcement == null) {
      return;
    }

    final active = announcement.isActiveAt(DateTime.now().toUtc());
    if (!active) {
      return;
    }

    final isRead = await _announcementReadStateService.isRead(announcement.id);
    if (isRead) {
      return;
    }

    final dialogContext = appRootNavigatorKey.currentContext;
    if (!mounted || dialogContext == null || !dialogContext.mounted) {
      return;
    }

    _hasShownStartupAnnouncement = true;
    showDialog<void>(
      context: dialogContext,
      builder: (context) {
        return _buildAnnouncementDialog(context, announcement);
      },
    );
  }

  Widget _buildAnnouncementDialog(
    BuildContext context,
    Announcement announcement,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final dialogMaxHeight = math.min(356.0, screenHeight * 0.44);
    final contentMaxHeight = math.min(110.0, screenHeight * 0.135);
    final accent = switch (announcement.level) {
      AnnouncementLevel.urgent => colorScheme.error,
      AnnouncementLevel.important => colorScheme.tertiary,
      AnnouncementLevel.info => colorScheme.primary,
    };
    final surface = colorScheme.surface;
    final backgroundTop = Color.alphaBlend(
      accent.withValues(alpha: 0.18),
      surface,
    );
    final backgroundBottom = Color.alphaBlend(
      colorScheme.secondary.withValues(alpha: 0.12),
      surface,
    );
    final contentText =
        announcement.content.trim().isEmpty
            ? '暂无公告正文。'
            : announcement.content.trim();
    final publishLabel = _formatAnnouncementDialogTime(
      announcement.publishFrom,
    );
    final titleText =
        announcement.title.trim().isEmpty ? '公告更新' : announcement.title.trim();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: AppSpacing.dialogInsetPadding(context),
      child: Align(
        alignment: const Alignment(0, -0.18),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: math.min(AppLayout.dialogMaxWidth(context), 340),
            maxHeight: dialogMaxHeight,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [backgroundTop, backgroundBottom],
                ),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.35),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 24,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -46,
                    top: -42,
                    child: Container(
                      width: 132,
                      height: 132,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Positioned(
                    left: -34,
                    bottom: -46,
                    child: Container(
                      width: 124,
                      height: 124,
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildAnnouncementLevelChip(
                                    context,
                                    announcement,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    titleText,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          height: 1.15,
                                          fontFamilyFallback:
                                              _dialogFontFallback,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    publishLabel,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: '关闭',
                              onPressed: () => Navigator.of(context).pop(),
                              style: IconButton.styleFrom(
                                minimumSize: const Size(34, 34),
                                padding: EdgeInsets.zero,
                                backgroundColor: colorScheme.surface.withValues(
                                  alpha: 0.58,
                                ),
                              ),
                              icon: Icon(
                                Icons.close_rounded,
                                color: colorScheme.onSurfaceVariant,
                                size: 18,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                          decoration: BoxDecoration(
                            color: colorScheme.surface.withValues(alpha: 0.88),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: colorScheme.outlineVariant.withValues(
                                alpha: 0.22,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 34,
                                height: 3,
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                              const SizedBox(height: 10),
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: 0,
                                  maxHeight: contentMaxHeight,
                                ),
                                child: ScrollConfiguration(
                                  behavior: const MaterialScrollBehavior()
                                      .copyWith(overscroll: false),
                                  child: SingleChildScrollView(
                                    child: Text(
                                      contentText,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            height: 1.5,
                                            fontFamilyFallback:
                                                _dialogFontFallback,
                                          ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('稍后'),
                            ),
                            const Spacer(),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: accent,
                                foregroundColor: colorScheme.onPrimary,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 11,
                                ),
                              ),
                              onPressed: () {
                                Navigator.of(context).pop();
                                unawaited(
                                  _announcementReadStateService.markRead(
                                    announcement.id,
                                  ),
                                );
                              },
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.check_circle_outline_rounded,
                                    size: 17,
                                  ),
                                  SizedBox(width: 6),
                                  Text('我已知晓'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnnouncementLevelChip(
    BuildContext context,
    Announcement announcement,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final (label, color) = switch (announcement.level) {
      AnnouncementLevel.urgent => ('紧急', colorScheme.error),
      AnnouncementLevel.important => ('重要', colorScheme.tertiary),
      AnnouncementLevel.info => ('通知', colorScheme.primary),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 11,
          fontFamilyFallback: _dialogFontFallback,
        ),
      ),
    );
  }

  String _formatAnnouncementDialogTime(DateTime time) {
    final local = time.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$month-$day $hour:$minute';
  }

  void _onIncomingExternalImportPayload(IncomingExternalImportPayload payload) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final target = switch (payload.type) {
        ExternalImportPayloadType.scriptSource => '/source',
        ExternalImportPayloadType.localBook => '/bookshelf',
        ExternalImportPayloadType.advancedTheme =>
          '/appearance/advanced-themes',
      };
      _safeGo(target);
    });
  }

  void _safeGo(String targetPath) {
    final currentUri = appRouter.routeInformationProvider.value.uri;
    if (currentUri.path == targetPath) {
      return;
    }
    appRouter.go(targetPath);
  }

  @override
  Widget build(BuildContext context) {
    final style =
        _isStartupReady
            ? _adaptiveOverlayStyle(context)
            : _startupOverlayStyle(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: style,
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          if (!_isStartupReady) const _StartupGuardPage(),
        ],
      ),
    );
  }

  SystemUiOverlayStyle _adaptiveOverlayStyle(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final base =
        brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark;
    return base.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
    );
  }

  SystemUiOverlayStyle _startupOverlayStyle(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final base =
        brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark;
    final navColor = Theme.of(context).colorScheme.surface;
    return base.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: navColor,
      systemNavigationBarDividerColor: Colors.transparent,
    );
  }
}

class _StartupGuardPage extends StatelessWidget {
  const _StartupGuardPage();

  @override
  Widget build(BuildContext context) {
    return const _StartupGuardArtwork();
  }
}

class _StartupGuardArtwork extends StatefulWidget {
  const _StartupGuardArtwork();

  @override
  State<_StartupGuardArtwork> createState() => _StartupGuardArtworkState();
}

class _StartupGuardArtworkState extends State<_StartupGuardArtwork> {
  static const String _fallbackStartupArtwork =
      'assets/branding/selune_launch_scene.png';

  @override
  Widget build(BuildContext context) {
    final resolvedPath = StartupArtworkStore.primedImagePath?.trim();
    final useFile =
        resolvedPath != null &&
        resolvedPath.isNotEmpty &&
        File(resolvedPath).existsSync();
    final ImageProvider imageProvider =
        useFile
            ? FileImage(File(resolvedPath))
            : const AssetImage(_fallbackStartupArtwork);
    return ColoredBox(
      color: const Color(0xFFF6F8FB),
      child: SizedBox.expand(
        child: Image(
          image: imageProvider,
          fit: BoxFit.fill,
          alignment: Alignment.center,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}

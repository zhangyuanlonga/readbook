import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:circular_theme_reveal/circular_theme_reveal.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'composition/app_providers.dart' as app_providers;
import 'platform/app_platform_capabilities.dart';
import 'tasks/app_task_manager.dart';
import '../core/app_update/app_update_dialog.dart';
import '../core/app_update/app_update_release.dart';
import '../core/auth/auth_event_bus.dart';
import '../core/logging/app_logger.dart';
import '../domain/entities/announcement.dart';
import '../features/mine/application/advanced_theme_provider.dart';
import '../features/source/application/external_import_catalog.dart';
import '../features/source/application/external_import_diagnostics.dart';
import '../features/source/application/external_source_import_bridge.dart';
import 'widgets/app_task_status.dart';
import 'widgets/import_export_copy.dart';
import 'widgets/import_export_task_overlay.dart';
import 'lifecycle/app_lifecycle_coordinator.dart';
import 'layout/app_layout.dart';
import 'router.dart';
import 'startup/app_announcement_coordinator.dart';
import 'startup/app_startup_coordinator.dart';
import 'startup_artwork_store.dart';
import 'startup_artwork_image_provider.dart';
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
    final activeThemeAppearanceSnapshot = ref.watch(
      activeThemeAppearanceSnapshotProvider,
    );

    final lightScheme = buildAppLightColorScheme(seedColor);
    final darkScheme = buildAppDarkColorScheme(seedColor);
    final lightAdvancedPalette = resolveAdvancedThemePaletteFromModeConfig(
      lightScheme,
      activeThemeAppearanceSnapshot?.lightConfig,
    );
    final darkAdvancedPalette = resolveAdvancedThemePaletteFromModeConfig(
      darkScheme,
      activeThemeAppearanceSnapshot?.darkConfig,
    );
    final lightAdvancedBackdrop = resolveAdvancedThemeBackdropFromModeConfig(
      lightScheme,
      activeThemeAppearanceSnapshot?.lightConfig,
    );
    final darkAdvancedBackdrop = resolveAdvancedThemeBackdropFromModeConfig(
      darkScheme,
      activeThemeAppearanceSnapshot?.darkConfig,
    );
    final themeBoundAppFontFamily =
        activeThemeAppearanceSnapshot?.appInterfaceFontFamilyKey?.trim();
    final fontFamily =
        themeBoundAppFontFamily != null && themeBoundAppFontFamily.isNotEmpty
            ? themeBoundAppFontFamily
            : resolveAppInterfaceFontFamily(interfaceFontSettings);
    final fontWeight = appInterfaceFontWeightValue(interfaceFontWeight);

    return MaterialApp.router(
      title: 'Selune',
      theme: AppTheme.build(
        lightScheme,
        advancedPalette: lightAdvancedPalette,
        advancedBackdrop: lightAdvancedBackdrop,
        advancedModeConfig: activeThemeAppearanceSnapshot?.lightConfig,
        fontFamily: fontFamily,
        fontWeight: fontWeight,
      ),
      darkTheme: AppTheme.build(
        darkScheme,
        advancedPalette: darkAdvancedPalette,
        advancedBackdrop: darkAdvancedBackdrop,
        advancedModeConfig: activeThemeAppearanceSnapshot?.darkConfig,
        fontFamily: fontFamily,
        fontWeight: fontWeight,
      ),
      themeMode: themeMode,
      themeAnimationDuration: const Duration(milliseconds: 180),
      themeAnimationCurve: Curves.easeOutCubic,
      routerConfig: appRouter,
      builder: (context, child) {
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

        return _MobileKeyboardInsetStabilizer(
          textScale: textScale,
          child: CircularThemeRevealOverlay(child: responsiveChild),
        );
      },
    );
  }
}

class _MobileKeyboardInsetStabilizer extends StatefulWidget {
  const _MobileKeyboardInsetStabilizer({
    required this.textScale,
    required this.child,
  });

  final double textScale;
  final Widget child;

  @override
  State<_MobileKeyboardInsetStabilizer> createState() =>
      _MobileKeyboardInsetStabilizerState();
}

class _MobileKeyboardInsetStabilizerState
    extends State<_MobileKeyboardInsetStabilizer> {
  static const Duration _keyboardInsetSettleDuration = Duration(
    milliseconds: 72,
  );

  Timer? _keyboardInsetSettleTimer;
  double _stableBottomInset = 0;
  double _pendingBottomInset = 0;
  bool _didSeedStableInset = false;

  bool get _useAndroidPanInsetsStrategy =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  bool get _useIosStabilizedInsetsStrategy =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncKeyboardInset(MediaQuery.viewInsetsOf(context).bottom);
  }

  @override
  void dispose() {
    _keyboardInsetSettleTimer?.cancel();
    super.dispose();
  }

  void _syncKeyboardInset(double rawBottomInset) {
    if (_useAndroidPanInsetsStrategy) {
      _keyboardInsetSettleTimer?.cancel();
      _keyboardInsetSettleTimer = null;
      _pendingBottomInset = 0;
      _stableBottomInset = 0;
      _didSeedStableInset = true;
      return;
    }

    if (!_useIosStabilizedInsetsStrategy) {
      _keyboardInsetSettleTimer?.cancel();
      _keyboardInsetSettleTimer = null;
      _pendingBottomInset = rawBottomInset;
      _stableBottomInset = rawBottomInset;
      _didSeedStableInset = true;
      return;
    }

    _pendingBottomInset = rawBottomInset;
    if (!_didSeedStableInset) {
      _stableBottomInset = rawBottomInset;
      _didSeedStableInset = true;
      return;
    }
    if (rawBottomInset <= 0.5) {
      _keyboardInsetSettleTimer?.cancel();
      _keyboardInsetSettleTimer = null;
      if (_stableBottomInset <= 0.5) {
        return;
      }
      setState(() {
        _stableBottomInset = 0;
      });
      return;
    }
    if ((_stableBottomInset - rawBottomInset).abs() < 0.5) {
      return;
    }

    _keyboardInsetSettleTimer?.cancel();
    _keyboardInsetSettleTimer = Timer(_keyboardInsetSettleDuration, () {
      if (!mounted) {
        return;
      }
      if ((_stableBottomInset - _pendingBottomInset).abs() < 0.5) {
        return;
      }
      setState(() {
        _stableBottomInset = _pendingBottomInset;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final effectiveBottomInset =
        _useAndroidPanInsetsStrategy ? 0.0 : _stableBottomInset;
    final effectiveBottomPadding =
        _useAndroidPanInsetsStrategy
            ? mediaQuery.viewPadding.bottom
            : mediaQuery.padding.bottom;
    final stabilizedMediaQuery =
        (_useAndroidPanInsetsStrategy || _useIosStabilizedInsetsStrategy)
            ? mediaQuery.copyWith(
              textScaler: TextScaler.linear(widget.textScale),
              viewInsets: mediaQuery.viewInsets.copyWith(
                bottom: effectiveBottomInset,
              ),
              padding: mediaQuery.padding.copyWith(
                bottom: effectiveBottomPadding,
              ),
            )
            : mediaQuery.copyWith(
              textScaler: TextScaler.linear(widget.textScale),
            );
    return MediaQuery(data: stabilizedMediaQuery, child: widget.child);
  }
}

class _SystemUiOverlayWrapper extends ConsumerStatefulWidget {
  const _SystemUiOverlayWrapper({required this.child});

  final Widget child;

  @override
  ConsumerState<_SystemUiOverlayWrapper> createState() =>
      _SystemUiOverlayWrapperState();
}

class _SystemUiOverlayWrapperState
    extends ConsumerState<_SystemUiOverlayWrapper>
    with WidgetsBindingObserver {
  Color? _lastOverlayBaseColor;
  bool _isStartupReady = false;
  ImportExportTaskStatus? _externalImportStatus;
  Announcement? _startupAnnouncementBanner;
  Timer? _startupAnnouncementBannerTimer;
  late final AppLifecycleCoordinator _lifecycleCoordinator;
  late final AppAnnouncementCoordinator _announcementCoordinator;
  late final AppStartupCoordinator _startupCoordinator;
  static const Duration _startupAnnouncementBannerDuration = Duration(
    seconds: 7,
  );
  static const List<String> _dialogFontFallback = [
    'STKaiti',
    'Kaiti SC',
    'KaiTi',
    'Songti SC',
    'Noto Serif CJK SC',
    'serif',
  ];

  @override
  void initState() {
    super.initState();
    _lifecycleCoordinator =
        ref.read(app_providers.appLifecycleCoordinatorFactoryProvider)();
    _announcementCoordinator =
        ref.read(app_providers.appAnnouncementCoordinatorFactoryProvider)();
    _startupCoordinator = ref.read(
      app_providers.appStartupCoordinatorFactoryProvider,
    )(
      sendHeartbeat: _lifecycleCoordinator.sendHeartbeat,
      sendVisitEvent: _lifecycleCoordinator.sendVisitEvent,
      showStartupAnnouncementIfNeeded: _showStartupAnnouncementIfNeeded,
      resolveDialogContext: _resolveStartupDialogContext,
      showUpdateDialog: _showUpdateReleaseDialog,
    );
    AppLogger.instance.info('Startup init begin');
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addTimingsCallback(
      _startupCoordinator.onFrameTimings,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startupCoordinator.notifyFirstFrameCallback();
    });
    unawaited(
      _lifecycleCoordinator.initialize(
        onIncomingExternalImportPayload: _onIncomingExternalImportPayload,
        onAuthEvent: _handleAuthEvent,
      ),
    );
    unawaited(
      _startupCoordinator.prepareStartup(
        isMounted: () => mounted,
        waitUntilReady: _waitUntilStartupArtworkReady,
        markStartupReady: _markStartupReady,
      ),
    );
  }

  Future<void> _waitUntilStartupArtworkReady() async {
    return;
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleCoordinator.handleAppLifecycleState(state);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    WidgetsBinding.instance.removeTimingsCallback(
      _startupCoordinator.onFrameTimings,
    );
    _startupAnnouncementBannerTimer?.cancel();
    _startupCoordinator.dispose();
    _lifecycleCoordinator.dispose();
    super.dispose();
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
    final theme = Theme.of(context);
    final backgroundColor =
        theme.appBarTheme.backgroundColor ?? theme.scaffoldBackgroundColor;
    if (_lastOverlayBaseColor?.toARGB32() == backgroundColor.toARGB32()) {
      return;
    }
    _lastOverlayBaseColor = backgroundColor;

    final base =
        ThemeData.estimateBrightnessForColor(backgroundColor) == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark;

    final style = base.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
    );

    SystemChrome.setSystemUIOverlayStyle(style);
  }

  void _markStartupReady() {
    if (!mounted) {
      return;
    }
    setState(() {
      _isStartupReady = true;
    });
  }

  void _showStartupAnnouncementIfNeeded() {
    _announcementCoordinator.showStartupAnnouncementIfNeeded(
      isStartupReady: _isStartupReady,
      isMounted: () => mounted,
      currentNavigatorContext: () => appRootNavigatorKey.currentContext,
      presentAnnouncement: _presentStartupAnnouncement,
    );
  }

  void _presentStartupAnnouncement(Announcement announcement) {
    if (!mounted) {
      return;
    }
    _startupAnnouncementBannerTimer?.cancel();
    setState(() {
      _startupAnnouncementBanner = announcement;
    });
    _startupAnnouncementBannerTimer = Timer(
      _startupAnnouncementBannerDuration,
      () => _dismissStartupAnnouncementBanner(markRead: true),
    );
  }

  Future<void> _showUpdateReleaseDialog(
    BuildContext context,
    AppUpdateRelease release,
  ) {
    return AppUpdateDialog.showUpdateDialog(context, release);
  }

  void _dismissStartupAnnouncementBanner({required bool markRead}) {
    final announcement = _startupAnnouncementBanner;
    _startupAnnouncementBannerTimer?.cancel();
    _startupAnnouncementBannerTimer = null;
    if (!mounted || announcement == null) {
      return;
    }
    setState(() {
      _startupAnnouncementBanner = null;
    });
    if (markRead) {
      unawaited(_announcementCoordinator.markRead(announcement.id));
    }
  }

  void _openStartupAnnouncement(Announcement announcement) {
    _dismissStartupAnnouncementBanner(markRead: true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      appRouter.push('/announcements/${Uri.encodeComponent(announcement.id)}');
    });
  }

  String _formatAnnouncementBannerTime(DateTime time) {
    final local = time.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$month-$day $hour:$minute';
  }

  void _onIncomingExternalImportPayload(IncomingExternalImportPayload payload) {
    final localFileImport =
        ref.read(appPlatformCapabilitiesProvider).localFileImport;
    if (!localFileImport.isSupported) {
      return;
    }

    final taskId =
        'external-import-handoff:${DateTime.now().microsecondsSinceEpoch}';
    final taskManager = ref.read(appTaskManagerProvider);
    final handoffStatus = ImportExportCopy.running(
      title: '已接收外部文件',
      message:
          '正在接管${ExternalImportDiagnostics.payloadLabel(payload.type)}并跳转到对应页面…',
      detail: payload.label,
    );
    taskManager.startTask(
      id: taskId,
      status: handoffStatus.toAppTaskStatusData(
        kind: _externalImportTaskKind(payload.type),
      ),
      channel: _externalImportTaskChannel(payload.type),
      priority: AppTaskPriority.userInitiated,
      recoveryKey: 'external-import:${payload.uri}',
    );
    if (mounted) {
      setState(() {
        _externalImportStatus = handoffStatus;
      });
      Future<void>.delayed(const Duration(milliseconds: 900), () {
        if (!mounted) {
          return;
        }
        setState(() {
          _externalImportStatus = null;
        });
        taskManager.updateTask(
          taskId,
          handoffStatus
              .toAppTaskStatusData(kind: _externalImportTaskKind(payload.type))
              .copyWith(
                title: '外部文件已转交',
                message: '已跳转到对应页面继续处理。',
                result: AppTaskStatusResult.success,
              ),
        );
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ExternalImportDiagnostics.logNavigationScheduled(payload);
      final target = ExternalImportCatalog.routeForPayloadType(payload.type);
      _safeGo(target);
    });
  }

  AppTaskStatusKind _externalImportTaskKind(ExternalImportPayloadType type) {
    return switch (type) {
      ExternalImportPayloadType.localBook => AppTaskStatusKind.localBookImport,
      ExternalImportPayloadType.advancedTheme => AppTaskStatusKind.themeImport,
      ExternalImportPayloadType.font => AppTaskStatusKind.fontImport,
    };
  }

  AppTaskChannel _externalImportTaskChannel(ExternalImportPayloadType type) {
    return switch (type) {
      ExternalImportPayloadType.localBook => AppTaskChannel.localBookImport,
      ExternalImportPayloadType.advancedTheme ||
      ExternalImportPayloadType.font => AppTaskChannel.resourceImport,
    };
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
    final showStartupGuard =
        !_isStartupReady && !StartupArtworkStore.primedDisabled;
    final style =
        !showStartupGuard
            ? _adaptiveOverlayStyle(context)
            : _startupOverlayStyle(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: style,
      child: ImportExportTaskOverlay(
        status: _externalImportStatus,
        child: Stack(
          fit: StackFit.expand,
          children: [
            widget.child,
            _StartupAnnouncementBannerOverlay(
              announcement: _startupAnnouncementBanner,
              fontFallback: _dialogFontFallback,
              formatTime: _formatAnnouncementBannerTime,
              onClose: () => _dismissStartupAnnouncementBanner(markRead: true),
              onOpen: _openStartupAnnouncement,
            ),
            if (showStartupGuard) const _StartupGuardPage(),
          ],
        ),
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

class _StartupAnnouncementBannerOverlay extends StatelessWidget {
  const _StartupAnnouncementBannerOverlay({
    required this.announcement,
    required this.fontFallback,
    required this.formatTime,
    required this.onClose,
    required this.onOpen,
  });

  final Announcement? announcement;
  final List<String> fontFallback;
  final String Function(DateTime time) formatTime;
  final VoidCallback onClose;
  final ValueChanged<Announcement> onOpen;

  @override
  Widget build(BuildContext context) {
    final announcement = this.announcement;
    return IgnorePointer(
      ignoring: announcement == null,
      child: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            reverseDuration: const Duration(milliseconds: 180),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              final offsetAnimation = Tween<Offset>(
                begin: const Offset(0, -0.18),
                end: Offset.zero,
              ).animate(animation);
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(position: offsetAnimation, child: child),
              );
            },
            child:
                announcement == null
                    ? const SizedBox(
                      key: ValueKey('startup_announcement_banner_empty'),
                      width: double.infinity,
                      height: 0,
                    )
                    : _StartupAnnouncementBanner(
                      key: ValueKey(
                        'startup_announcement_banner_${announcement.id}',
                      ),
                      announcement: announcement,
                      fontFallback: fontFallback,
                      formatTime: formatTime,
                      onClose: onClose,
                      onOpen: () => onOpen(announcement),
                    ),
          ),
        ),
      ),
    );
  }
}

class _StartupAnnouncementBanner extends StatelessWidget {
  const _StartupAnnouncementBanner({
    super.key,
    required this.announcement,
    required this.fontFallback,
    required this.formatTime,
    required this.onClose,
    required this.onOpen,
  });

  final Announcement announcement;
  final List<String> fontFallback;
  final String Function(DateTime time) formatTime;
  final VoidCallback onClose;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final horizontal = AppLayout.isDesktopLike(context) ? 24.0 : 12.0;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final maxWidth =
        AppLayout.isDesktopLike(context) ? 680.0 : screenWidth - horizontal * 2;
    final (label, accent, icon) = switch (announcement.level) {
      AnnouncementLevel.urgent => (
        '紧急公告',
        colorScheme.error,
        Icons.priority_high_rounded,
      ),
      AnnouncementLevel.important => (
        '重要公告',
        colorScheme.tertiary,
        Icons.campaign_rounded,
      ),
      AnnouncementLevel.info => (
        '公告通知',
        colorScheme.primary,
        Icons.notifications_active_outlined,
      ),
    };
    final title =
        announcement.title.trim().isEmpty ? '公告更新' : announcement.title.trim();
    final summary = announcement.content.trim();

    return Padding(
      padding: EdgeInsets.fromLTRB(horizontal, 10, horizontal, 0),
      child: Material(
        color: Colors.transparent,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Color.alphaBlend(
                accent.withValues(alpha: 0.12),
                colorScheme.surface,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: accent.withValues(alpha: 0.28)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.16),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: onOpen,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: accent, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                label,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: accent,
                                  fontWeight: FontWeight.w800,
                                  fontFamilyFallback: fontFallback,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  formatTime(announcement.publishFrom),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              fontFamilyFallback: fontFallback,
                            ),
                          ),
                          if (summary.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              summary,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontFamilyFallback: fontFallback,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    TextButton(onPressed: onOpen, child: const Text('查看')),
                    Semantics(
                      button: true,
                      label: '关闭',
                      child: IconButton(
                        onPressed: onClose,
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
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
  int _seenRevision = -1;
  ImageProvider? _imageProvider;
  Object? _imageKey;
  Timer? _artworkPollTimer;

  @override
  void initState() {
    super.initState();
    _syncArtwork(precache: false);
    _artworkPollTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!mounted) {
        return;
      }
      if (_seenRevision != StartupArtworkStore.revision ||
          StartupArtworkStore.isPriming) {
        _syncArtwork();
      }
      if (!StartupArtworkStore.isPriming &&
          _seenRevision == StartupArtworkStore.revision) {
        _artworkPollTimer?.cancel();
        _artworkPollTimer = null;
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncArtwork();
  }

  @override
  void dispose() {
    _artworkPollTimer?.cancel();
    super.dispose();
  }

  void _syncArtwork({bool precache = true}) {
    if (StartupArtworkStore.isPriming &&
        StartupArtworkStore.primedImagePath == null &&
        _imageProvider != null) {
      return;
    }
    final revision = StartupArtworkStore.revision;
    final hasExpectedProvider = _imageProvider != null;
    if (_seenRevision == revision && hasExpectedProvider) {
      return;
    }
    _seenRevision = revision;
    final resolvedPath = StartupArtworkStore.primedImagePath?.trim();
    final fileProvider = resolveStartupArtworkFileProvider(resolvedPath);
    final ImageProvider nextProvider =
        fileProvider ?? const AssetImage(_fallbackStartupArtwork);
    final nextKey = resolvedPath ?? _fallbackStartupArtwork;
    _imageProvider = nextProvider;
    _imageKey = nextKey;
    if (precache) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          precacheImage(nextProvider, context);
        }
      });
    }
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_seenRevision != StartupArtworkStore.revision) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _syncArtwork();
        }
      });
    }
    final imageProvider =
        _imageProvider ??
        (StartupArtworkStore.isPriming
            ? null
            : const AssetImage(_fallbackStartupArtwork));
    return ColoredBox(
      color: const Color(0xFFF6F8FB),
      child: SizedBox.expand(
        child:
            imageProvider == null
                ? const SizedBox.expand()
                : Image(
                  key: ValueKey<Object?>(_imageKey),
                  image: imageProvider,
                  fit: BoxFit.fill,
                  alignment: Alignment.center,
                  filterQuality: FilterQuality.high,
                ),
      ),
    );
  }
}

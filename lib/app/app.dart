import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'composition/app_providers.dart' as app_providers;
import 'platform/app_platform_capabilities.dart';
import '../core/app_update/app_update_dialog.dart';
import '../core/app_update/app_update_release.dart';
import '../core/auth/auth_event_bus.dart';
import '../core/logging/app_logger.dart';
import '../domain/entities/announcement.dart';
import '../features/mine/application/advanced_theme_provider.dart';
import '../features/source/application/external_import_catalog.dart';
import '../features/source/application/external_import_diagnostics.dart';
import '../features/source/application/external_source_import_bridge.dart';
import 'widgets/import_export_copy.dart';
import 'widgets/import_export_task_overlay.dart';
import 'lifecycle/app_lifecycle_coordinator.dart';
import 'layout/app_layout.dart';
import 'layout/app_spacing.dart';
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
    final themeBoundAppFontFamily =
        activeAdvancedTheme?.appInterfaceFontFamilyKey?.trim();
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
          child: responsiveChild,
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
  late final AppLifecycleCoordinator _lifecycleCoordinator;
  late final AppAnnouncementCoordinator _announcementCoordinator;
  late final AppStartupCoordinator _startupCoordinator;
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
    if (StartupArtworkStore.primedDisabled) {
      return;
    }
    for (var attempt = 0; attempt < 6; attempt += 1) {
      if (!StartupArtworkStore.isPriming) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
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
    final dialogContext = appRootNavigatorKey.currentContext;
    if (!mounted || dialogContext == null || !dialogContext.mounted) {
      return;
    }
    showDialog<void>(
      context: dialogContext,
      builder: (context) {
        return _buildAnnouncementDialog(context, announcement);
      },
    );
  }

  Future<void> _showUpdateReleaseDialog(
    BuildContext context,
    AppUpdateRelease release,
  ) {
    return AppUpdateDialog.showUpdateDialog(context, release);
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
                      mainAxisSize: MainAxisSize.max,
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
                        Flexible(
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                            decoration: BoxDecoration(
                              color: colorScheme.surface.withValues(
                                alpha: 0.88,
                              ),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: colorScheme.outlineVariant.withValues(
                                  alpha: 0.22,
                                ),
                              ),
                            ),
                            child: ScrollConfiguration(
                              behavior: const MaterialScrollBehavior().copyWith(
                                overscroll: false,
                              ),
                              child: SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 34,
                                      height: 3,
                                      decoration: BoxDecoration(
                                        color: accent.withValues(alpha: 0.7),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    ConstrainedBox(
                                      constraints: BoxConstraints(
                                        minHeight: 0,
                                        maxHeight: contentMaxHeight,
                                      ),
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
                                  ],
                                ),
                              ),
                            ),
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
                                  _announcementCoordinator.markRead(
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
    if (!ref.read(appPlatformCapabilitiesProvider).supportsLocalFileImport) {
      return;
    }

    if (mounted) {
      setState(() {
        _externalImportStatus = ImportExportCopy.running(
          title: '已接收外部文件',
          message:
              '正在接管${ExternalImportDiagnostics.payloadLabel(payload.type)}并跳转到对应页面…',
          detail: payload.label,
        );
      });
      Future<void>.delayed(const Duration(milliseconds: 900), () {
        if (!mounted) {
          return;
        }
        setState(() {
          _externalImportStatus = null;
        });
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
        _imageProvider ?? const AssetImage(_fallbackStartupArtwork);
    return ColoredBox(
      color: const Color(0xFFF6F8FB),
      child: SizedBox.expand(
        child: Image(
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

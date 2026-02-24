import 'dart:async';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/datasources/local/app_database.dart';
import 'router.dart';
import 'theme/app_dynamic_color_provider.dart';
import 'theme/app_theme.dart';
import 'theme/app_theme_provider.dart';
import 'theme/app_theme_seed_provider.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seedColor = ref.watch(appSeedColorProvider);
    final themeMode = ref.watch(appThemeModeProvider);
    final dynamicColorEnabled = ref.watch(appDynamicColorEnabledProvider);

    return DynamicColorBuilder(
      builder: (dynamicLightScheme, dynamicDarkScheme) {
        final fallbackLightScheme = ColorScheme.fromSeed(
          seedColor: seedColor,
          dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
          brightness: Brightness.light,
        );

        final fallbackDarkScheme = ColorScheme.fromSeed(
          seedColor: seedColor,
          dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
          brightness: Brightness.dark,
        );

        final lightScheme =
            dynamicColorEnabled && dynamicLightScheme != null
                ? dynamicLightScheme
                : fallbackLightScheme;

        final darkScheme =
            dynamicColorEnabled && dynamicDarkScheme != null
                ? dynamicDarkScheme
                : fallbackDarkScheme;

        return MaterialApp.router(
          title: '源阅',
          theme: AppTheme.build(lightScheme),
          darkTheme: AppTheme.build(darkScheme),
          themeMode: themeMode,
          themeAnimationDuration: const Duration(milliseconds: 180),
          themeAnimationCurve: Curves.easeOutCubic,
          routerConfig: appRouter,
          builder: (context, child) {
            return _SystemUiOverlayWrapper(
              child: child ?? const SizedBox.shrink(),
            );
          },
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

class _SystemUiOverlayWrapperState extends State<_SystemUiOverlayWrapper> {
  Brightness? _lastBrightness;
  bool _hasShownStartupAnnouncement = false;
  bool _startupAnnouncementScheduled = false;
  int _startupAnnouncementRetryCount = 0;
  bool _isStartupReady = false;
  Timer? _startupDelayTimer;

  static const Duration _kStartupMinDuration = Duration(seconds: 2);

  @override
  void initState() {
    super.initState();
    unawaited(_prepareStartup());
  }

  Future<void> _prepareStartup() async {
    final startedAt = DateTime.now();

    try {
      await AppDatabase.instance.countSourceListItems();
    } catch (_) {
      // Ignore warmup failures and continue startup.
    }

    final elapsed = DateTime.now().difference(startedAt);
    final remaining = _kStartupMinDuration - elapsed;
    if (remaining > Duration.zero) {
      await _waitStartupDelay(remaining);
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isStartupReady = true;
    });
    _showStartupAnnouncementIfNeeded();
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

  @override
  void dispose() {
    _startupDelayTimer?.cancel();
    super.dispose();
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
      _hasShownStartupAnnouncement = true;
      showDialog<void>(
        context: navigatorContext,
        builder: (context) {
          return AlertDialog(
            title: const Text('公告'),
            content: const Text(
              '该 App 为初版，目的是适配阅读书源，保证每天一版本更新，书源问题和更新APP，请在我的页面点击书源反馈入口进行反馈。',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('我知道了'),
              ),
            ],
          );
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final base =
        brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark;

    final style = base.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
    );

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
}

class _StartupGuardPage extends StatelessWidget {
  const _StartupGuardPage();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ColoredBox(
      color: colorScheme.surface,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_stories_rounded,
              size: 44,
              color: colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              '源阅启动中',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

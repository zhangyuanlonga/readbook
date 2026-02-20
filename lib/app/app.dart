import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _showStartupAnnouncementIfNeeded();

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
    if (_hasShownStartupAnnouncement || _startupAnnouncementScheduled) {
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
              '该 App 为初版，目的是适配阅读书源，如有书源错误或者其他问题，请在我的页面点击书源反馈入口进行反馈。',
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
      child: widget.child,
    );
  }
}

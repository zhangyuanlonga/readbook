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
          title: 'Flutter AppRead',
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

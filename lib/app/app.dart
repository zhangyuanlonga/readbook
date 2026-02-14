import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';
import 'theme/app_theme.dart';
import 'theme/app_theme_provider.dart';
import 'theme/app_theme_seed_provider.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seedColor = ref.watch(appSeedColorProvider);

    final lightScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
      brightness: Brightness.light,
    );

    final darkScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
      brightness: Brightness.dark,
    );

    final themeMode = ref.watch(appThemeModeProvider);

    return MaterialApp.router(
      title: 'Flutter AppRead',
      theme: AppTheme.build(lightScheme),
      darkTheme: AppTheme.build(darkScheme),
      themeMode: themeMode,
      routerConfig: appRouter,
    );
  }
}

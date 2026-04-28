import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'startup_artwork_store.dart';
import '../features/source/application/source_health_service.dart';
import '../features/source/application/source_runtime_diagnostics_service.dart';
import '../features/mine/application/advanced_theme_provider.dart';
import '../features/mine/providers.dart';
import '../features/reader/application/reader_font_registry_service.dart';
import '../core/logging/app_logger.dart';
import '../core/storage/managed_file_path_resolver.dart';
import 'navigation/app_navigation_style_provider.dart';
import 'startup/managed_asset_path_migration_service.dart';
import 'theme/app_interface_typography_provider.dart';
import 'theme/app_theme_provider.dart';
import 'theme/app_theme_seed_provider.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  _configureImagePicker();
  PlatformInAppWebViewController.debugLoggingSettings.enabled = false;
  final prefs = await SharedPreferences.getInstance();
  await ManagedFilePathResolver.primeCurrentRoots();
  await ManagedAssetPathMigrationService(
    preferences: prefs,
    logger: AppLogger.instance,
  ).migrate();
  AppNavigationStylePreferenceNotifier.prime(prefs);
  AppNavigationLabelVisibilityNotifier.prime(prefs);
  AppStandardNavigationBarAppearanceNotifier.prime(prefs);
  AppCupertinoDockAppearanceNotifier.prime(prefs);
  AppThemeModeNotifier.prime(prefs);
  AppSeedColorNotifier.prime(prefs);
  ActiveAdvancedThemeIdNotifier.prime(prefs);
  AppInterfaceFontSettingsNotifier.prime(prefs);
  AppInterfaceTextScaleNotifier.prime(prefs);
  AppInterfaceFontWeightNotifier.prime(prefs);
  MinePageVisibilityNotifier.prime(prefs);
  MinePageStartupDestinationNotifier.prime(prefs);
  await Future.wait<void>([
    ReaderFontRegistryService().restoreRegisteredFonts(),
    StartupArtworkStore.prime(preferences: prefs),
  ]);
  runApp(const ProviderScope(child: App()));
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_runDeferredBootstrapTasks());
  });
}

Future<void> _runDeferredBootstrapTasks() async {
  try {
    await SourceRuntimeDiagnosticsService.instance.reportRecoveredInvocations(
      logger: AppLogger.instance,
    );
  } catch (error, stackTrace) {
    AppLogger.instance.warn(
      'Deferred diagnostics recovery failed',
      context: <String, Object?>{
        'error': error.toString(),
        'stackTrace': stackTrace.toString(),
      },
    );
  }

  try {
    await SourceHealthService.instance.hydrate();
  } catch (error, stackTrace) {
    AppLogger.instance.warn(
      'Deferred source health hydrate failed',
      context: <String, Object?>{
        'error': error.toString(),
        'stackTrace': stackTrace.toString(),
      },
    );
  }
}

void _configureImagePicker() {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    return;
  }

  final implementation = ImagePickerPlatform.instance;
  if (implementation is ImagePickerAndroid) {
    implementation.useAndroidPhotoPicker = true;
  }
}

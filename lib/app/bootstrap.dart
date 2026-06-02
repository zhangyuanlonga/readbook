import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'router.dart';
import 'startup_artwork_store.dart';
import '../features/mine/application/advanced_theme_provider.dart';
import '../features/mine/application/mine_page_session_service.dart';
import '../features/mine/providers.dart';
import '../features/reader/application/reader_font_registry_service.dart';
import '../core/logging/app_logger.dart';
import '../core/logging/source_log_store.dart';
import '../core/storage/managed_file_path_resolver.dart';
import 'navigation/app_navigation_style_provider.dart';
import 'platform/app_platform_capabilities.dart';
import 'platform/desktop_window_bootstrap.dart';
import 'startup/managed_asset_path_migration_service.dart';
import 'theme/app_interface_typography_provider.dart';
import 'theme/app_theme_provider.dart';
import 'theme/app_theme_seed_provider.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DesktopWindowBootstrap.configure();
  unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
  _configureImagePicker();
  final prefs = await SharedPreferences.getInstance();
  AppNavigationStylePreferenceNotifier.prime(prefs);
  AppNavigationLabelVisibilityNotifier.prime(prefs);
  AppStandardNavigationBarAppearanceNotifier.prime(prefs);
  AppCupertinoDockAppearanceNotifier.prime(prefs);
  AppThemeModeNotifier.prime(prefs);
  AppSeedColorNotifier.prime(prefs);
  ActiveAdvancedThemeIdNotifier.prime(prefs);
  ActiveThemeAppearanceSnapshotNotifier.prime(prefs);
  MinePageSessionPriming.prime(prefs);
  AuthSessionSnapshotBootstrap.prime(prefs);
  AppInterfaceFontSettingsNotifier.prime(prefs);
  AppInterfaceTextScaleNotifier.prime(prefs);
  AppInterfaceFontWeightNotifier.prime(prefs);
  MinePageVisibilityNotifier.prime(prefs);
  MinePageStartupDestinationNotifier.prime(prefs);
  StartupArtworkStore.primeStartupEnabledSync(prefs);
  unawaited(StartupArtworkStore.prime(preferences: prefs));
  runApp(const ProviderScope(child: App()));
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_runDeferredBootstrapTasks(prefs));
  });
}

Future<void> _runDeferredBootstrapTasks(SharedPreferences prefs) async {
  final capabilities = AppPlatformCapabilities.current();

  try {
    await ManagedFilePathResolver.primeCurrentRoots();
  } catch (_) {
    // Path root priming can be retried lazily by individual resolvers.
  }

  try {
    await SourceLogStore.instance.restore();
  } catch (_) {
    // Ignore startup log restoration failures.
  }

  if (capabilities.supportsManagedFileStorage) {
    try {
      await ReaderFontRegistryService().restoreRegisteredFonts();
    } catch (_) {
      // Ignore broken font restoration during startup.
    }
  }

  if (capabilities.supportsManagedFileStorage &&
      capabilities.supportsNativeSqlite) {
    try {
      await ManagedAssetPathMigrationService(
        preferences: prefs,
        logger: AppLogger.instance,
      ).migrate();
    } catch (error, stackTrace) {
      AppLogger.instance.warn(
        'Deferred managed asset migration failed',
        context: <String, Object?>{
          'error': error.toString(),
          'stackTrace': stackTrace.toString(),
        },
      );
    }
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

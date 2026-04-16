import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import '../features/source/application/source_health_service.dart';
import '../features/source/application/source_runtime_diagnostics_service.dart';
import '../core/logging/app_logger.dart';
import 'navigation/app_navigation_style_provider.dart';
import 'theme/app_theme_provider.dart';
import 'theme/app_theme_seed_provider.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  _configureImagePicker();
  PlatformInAppWebViewController.debugLoggingSettings.enabled = false;
  final prefs = await SharedPreferences.getInstance();
  AppNavigationStylePreferenceNotifier.prime(prefs);
  AppNavigationLabelVisibilityNotifier.prime(prefs);
  AppThemeModeNotifier.prime(prefs);
  AppSeedColorNotifier.prime(prefs);
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

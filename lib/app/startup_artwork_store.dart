import 'package:shared_preferences/shared_preferences.dart';

import '../features/mine/application/launch_image_gallery_service.dart';

class StartupArtworkStore {
  StartupArtworkStore._();

  static String? _primedImagePath;
  static bool _primedDisabled = false;
  static bool _isPriming = false;
  static int _revision = 0;

  static String? get primedImagePath => _primedImagePath;
  static bool get primedDisabled => _primedDisabled;
  static bool get isPriming => _isPriming;
  static int get revision => _revision;

  static void primeStartupEnabledSync(SharedPreferences _) {
    _primedDisabled = false;
    _revision += 1;
  }

  static Future<void> prime({SharedPreferences? preferences}) async {
    _isPriming = true;
    _revision += 1;
    try {
      if (_primedDisabled) {
        _primedImagePath = null;
        return;
      }
      final launchImageGalleryService = LaunchImageGalleryService(
        preferences: preferences,
      );
      _primedDisabled = false;
      final resolved =
          await launchImageGalleryService.loadStartupSnapshotPath();
      final normalized = resolved?.trim() ?? '';
      _primedImagePath = normalized.isEmpty ? null : normalized;
    } catch (_) {
      _primedDisabled = false;
      _primedImagePath = null;
    } finally {
      _isPriming = false;
      _revision += 1;
    }
  }
}

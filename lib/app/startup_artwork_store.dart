import 'package:shared_preferences/shared_preferences.dart';

import '../features/mine/application/advanced_theme_service.dart';
import '../features/mine/application/launch_image_gallery_service.dart';

class StartupArtworkStore {
  StartupArtworkStore._();

  static String? _primedImagePath;
  static bool _primedDisabled = false;

  static String? get primedImagePath => _primedImagePath;
  static bool get primedDisabled => _primedDisabled;

  static Future<void> prime({SharedPreferences? preferences}) async {
    try {
      final activeTheme =
          await AdvancedThemeService(
            preferences: preferences,
          ).loadActiveTheme();
      final launchImageGalleryService = LaunchImageGalleryService(
        preferences: preferences,
      );
      if (!await launchImageGalleryService.loadStartupEnabled()) {
        _primedDisabled = true;
        _primedImagePath = null;
        return;
      }
      _primedDisabled = false;
      final resolved = await launchImageGalleryService
          .loadLaunchImagePathForGallery(activeTheme?.launchImageGalleryId);
      final normalized = resolved?.trim() ?? '';
      _primedImagePath = normalized.isEmpty ? null : normalized;
    } catch (_) {
      _primedDisabled = false;
      _primedImagePath = null;
    }
  }
}

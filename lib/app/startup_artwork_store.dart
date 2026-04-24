import 'package:shared_preferences/shared_preferences.dart';

import '../features/mine/application/advanced_theme_service.dart';
import '../features/mine/application/launch_image_gallery_service.dart';

class StartupArtworkStore {
  StartupArtworkStore._();

  static String? _primedImagePath;

  static String? get primedImagePath => _primedImagePath;

  static Future<void> prime({SharedPreferences? preferences}) async {
    try {
      final activeTheme =
          await AdvancedThemeService(
            preferences: preferences,
          ).loadActiveTheme();
      final resolved = await LaunchImageGalleryService(
        preferences: preferences,
      ).loadLaunchImagePathForGallery(activeTheme?.launchImageGalleryId);
      final normalized = resolved?.trim() ?? '';
      _primedImagePath = normalized.isEmpty ? null : normalized;
    } catch (_) {
      _primedImagePath = null;
    }
  }
}

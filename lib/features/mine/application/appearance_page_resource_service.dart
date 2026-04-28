import '../../../core/media/image_selection_service.dart';
import '../../reader/application/reader_font_registry_service.dart';
import 'app_background_service.dart';

class AppearancePageResources {
  const AppearancePageResources({
    required this.backgroundPaths,
    required this.availableFonts,
  });

  final List<String> backgroundPaths;
  final List<ReaderCustomFontEntry> availableFonts;
}

class AppearancePageResourceService {
  const AppearancePageResourceService({
    required AppBackgroundService backgroundService,
    required ReaderFontRegistryService fontRegistryService,
  }) : _backgroundService = backgroundService,
       _fontRegistryService = fontRegistryService;

  final AppBackgroundService _backgroundService;
  final ReaderFontRegistryService _fontRegistryService;

  Future<AppearancePageResources> loadResources() async {
    final backgroundPaths = await _backgroundService.loadBackgroundPaths();
    final availableFonts = await _fontRegistryService.listRegisteredFonts();
    return AppearancePageResources(
      backgroundPaths: List<String>.unmodifiable(backgroundPaths),
      availableFonts: List<ReaderCustomFontEntry>.unmodifiable(availableFonts),
    );
  }

  Future<int> importBackgrounds(List<PickedImageData> pickedImages) async {
    var importedCount = 0;
    for (final picked in pickedImages) {
      await _backgroundService.importBackground(
        bytes: picked.bytes,
        fileName: picked.name,
      );
      importedCount += 1;
    }
    return importedCount;
  }

  Future<void> deleteBackground(String path) {
    return _backgroundService.deleteBackground(path);
  }
}

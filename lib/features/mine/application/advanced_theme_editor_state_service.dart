import 'package:flutter/material.dart';

import '../../../app/theme/app_theme_palette.dart';
import '../../../domain/entities/app_advanced_theme.dart';
import '../../../domain/entities/bottom_nav_icon_gallery.dart';
import '../../../domain/entities/cover_gallery.dart';
import '../../../domain/entities/launch_image_gallery.dart';
import '../../reader/application/reader_font_registry_service.dart';
import 'advanced_theme_service.dart';
import 'app_background_service.dart';
import 'cover_gallery_service.dart';
import 'launch_image_gallery_service.dart';
import 'reader_background_service.dart';
import '../../../app/navigation/bottom_nav_icon_gallery_service.dart';
import '../../../core/media/image_selection_service.dart';

class AdvancedThemeEditorAppearanceLinks {
  const AdvancedThemeEditorAppearanceLinks({
    required this.backgroundLibraryPaths,
    required this.readerBackgroundLibraryPaths,
    required this.bottomNavGalleries,
    required this.coverGalleries,
    required this.launchImageGalleries,
    required this.availableFonts,
    required this.activeBottomNavGalleryName,
  });

  final List<String> backgroundLibraryPaths;
  final List<String> readerBackgroundLibraryPaths;
  final List<BottomNavIconGallery> bottomNavGalleries;
  final List<CoverGallery> coverGalleries;
  final List<LaunchImageGallery> launchImageGalleries;
  final List<ReaderCustomFontEntry> availableFonts;
  final String? activeBottomNavGalleryName;
}

class AdvancedThemeEditorStateService {
  const AdvancedThemeEditorStateService({
    required AdvancedThemeService service,
    required BottomNavIconGalleryService bottomNavIconGalleryService,
    required AppBackgroundService appBackgroundService,
    required CoverGalleryService coverGalleryService,
    required LaunchImageGalleryService launchImageGalleryService,
    required ReaderBackgroundService readerBackgroundService,
    required ReaderFontRegistryService fontRegistryService,
  }) : _service = service,
       _bottomNavIconGalleryService = bottomNavIconGalleryService,
       _appBackgroundService = appBackgroundService,
       _coverGalleryService = coverGalleryService,
       _launchImageGalleryService = launchImageGalleryService,
       _readerBackgroundService = readerBackgroundService,
       _fontRegistryService = fontRegistryService;

  final AdvancedThemeService _service;
  final BottomNavIconGalleryService _bottomNavIconGalleryService;
  final AppBackgroundService _appBackgroundService;
  final CoverGalleryService _coverGalleryService;
  final LaunchImageGalleryService _launchImageGalleryService;
  final ReaderBackgroundService _readerBackgroundService;
  final ReaderFontRegistryService _fontRegistryService;

  AppAdvancedTheme createDraft(Color seedColor) {
    final now = DateTime.now().toUtc();
    return AppAdvancedTheme(
      id: _service.createThemeId(),
      name: '未命名主题',
      createdAt: now,
      updatedAt: now,
      lightConfig: _modeConfigFromScheme(buildAppLightColorScheme(seedColor)),
      darkConfig: _modeConfigFromScheme(buildAppDarkColorScheme(seedColor)),
    );
  }

  Future<AppAdvancedTheme?> loadDraft(String? themeId) async {
    final normalized = themeId?.trim() ?? '';
    if (normalized.isEmpty) {
      return null;
    }
    final themes = await _service.loadThemes();
    for (final theme in themes) {
      if (theme.id == normalized) {
        return theme;
      }
    }
    return null;
  }

  Future<AdvancedThemeEditorAppearanceLinks> loadAppearanceLinks() async {
    final backgroundPaths = await _appBackgroundService.loadBackgroundPaths();
    final readerBackgroundPaths =
        await _readerBackgroundService.loadBackgroundPaths();
    final activeGallery =
        await _bottomNavIconGalleryService.loadActiveGallery();
    final galleries = await _bottomNavIconGalleryService.loadGalleries();
    final coverGalleries = await _coverGalleryService.loadGalleries();
    final launchImageGalleries =
        await _launchImageGalleryService.loadGalleries();
    final fonts = await _fontRegistryService.listRegisteredFonts();
    return AdvancedThemeEditorAppearanceLinks(
      backgroundLibraryPaths: List<String>.unmodifiable(backgroundPaths),
      readerBackgroundLibraryPaths:
          List<String>.unmodifiable(readerBackgroundPaths),
      bottomNavGalleries: List<BottomNavIconGallery>.unmodifiable(galleries),
      coverGalleries: List<CoverGallery>.unmodifiable(coverGalleries),
      launchImageGalleries:
          List<LaunchImageGallery>.unmodifiable(launchImageGalleries),
      availableFonts: List<ReaderCustomFontEntry>.unmodifiable(fonts),
      activeBottomNavGalleryName: activeGallery?.name,
    );
  }

  Future<AppAdvancedTheme> applyWallpaper({
    required AppAdvancedTheme draft,
    required AppAdvancedThemeMode mode,
    required PickedImageData picked,
  }) async {
    final currentConfig = draft.configFor(mode);
    final previousPath = currentConfig.wallpaperPath?.trim();
    final path = await _service.saveWallpaper(
      themeId: draft.id,
      mode: mode,
      bytes: picked.bytes,
      fileName: picked.name,
    );
    if (previousPath != null &&
        previousPath.isNotEmpty &&
        previousPath != path) {
      await _service.deleteWallpaper(previousPath);
    }
    return draft.copyWithModeConfig(mode, currentConfig.copyWith(wallpaperPath: path));
  }

  AppAdvancedThemeModeConfig _modeConfigFromScheme(ColorScheme colorScheme) {
    return AppAdvancedThemeModeConfig(
      colors: AppAdvancedThemeColors(
        primaryColorValue: colorScheme.primary.toARGB32(),
        secondaryColorValue: colorScheme.secondary.toARGB32(),
        noticeAccentColorValue: colorScheme.tertiary.toARGB32(),
        noticeSurfaceColorValue: colorScheme.tertiaryContainer.toARGB32(),
        primaryContainerColorValue: colorScheme.primaryContainer.toARGB32(),
        backgroundColorValue: colorScheme.surface.toARGB32(),
        surfaceColorValue: colorScheme.surfaceContainerLow.toARGB32(),
        searchFieldBackgroundColorValue:
            colorScheme.surfaceContainerHighest.toARGB32(),
        elevatedSurfaceColorValue: colorScheme.surfaceContainerHigh.toARGB32(),
        cardColorValue: colorScheme.surface.toARGB32(),
        cardTextColorValue: colorScheme.onSurface.toARGB32(),
        cardBorderColorValue: colorScheme.outlineVariant.toARGB32(),
        iconBackgroundColorValue: Color.alphaBlend(
          colorScheme.onSurface.withValues(alpha: 0.04),
          colorScheme.surface,
        ).toARGB32(),
        textPrimaryColorValue: colorScheme.onSurface.toARGB32(),
        textSecondaryColorValue: colorScheme.onSurfaceVariant.toARGB32(),
        buttonTextColorValue: colorScheme.onPrimary.toARGB32(),
        outlineColorValue: colorScheme.outline.toARGB32(),
        shadowColorValue:
            colorScheme.primary.withValues(alpha: 0.18).toARGB32(),
        wallpaperOverlayColorValue: colorScheme.surface.toARGB32(),
      ),
      readerWallpaperOverlayOpacity: 0,
      wallpaperOverlayOpacity:
          colorScheme.brightness == Brightness.dark ? 0.46 : 0.28,
    );
  }
}

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../app/navigation/bottom_nav_icon_gallery_service.dart';
import '../../../app/images/file_image_cache.dart';
import '../../../core/storage/managed_asset_store.dart';
import '../../../domain/entities/app_advanced_theme.dart';
import '../../../domain/entities/bottom_nav_icon_gallery.dart';
import '../../../domain/entities/managed_asset.dart';
import 'cover_gallery_service.dart';
import 'launch_image_gallery_service.dart';
import '../../reader/application/reader_font_registry_service.dart';
import 'reader_background_service.dart';

class AdvancedThemeService {
  static const String _activeThemeIdKey = 'app.advancedThemes.activeId';
  static const String _colorExportType = 'advanced_theme_colors';
  static const int _legacyColorExportVersion = 1;
  static const int _colorExportVersion = 2;
  static const String _bundleExportType = 'advanced_theme_bundle';
  static const int _bundleExportVersion = 1;

  AdvancedThemeService({
    SharedPreferences? preferences,
    ManagedAssetStore? assetStore,
  }) : _preferencesFuture =
           preferences == null
               ? SharedPreferences.getInstance()
               : Future.value(preferences),
       _assetStore = assetStore ?? ManagedAssetStore();

  final Future<SharedPreferences> _preferencesFuture;
  final ManagedAssetStore _assetStore;

  static const Uuid _uuid = Uuid();
  static const String _themesKey = 'app.advancedThemes';

  static String? readActiveThemeId(SharedPreferences prefs) {
    final raw = prefs.getString(_activeThemeIdKey)?.trim();
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return raw;
  }

  Future<List<AppAdvancedTheme>> loadThemes() async {
    final prefs = await _preferencesFuture;
    final raw = prefs.getString(_themesKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <AppAdvancedTheme>[];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <AppAdvancedTheme>[];
      }
      final themes = decoded
          .whereType<Map>()
          .map(
            (item) => AppAdvancedTheme.fromJson(
              item.map((key, value) => MapEntry(key.toString(), value)),
            ),
          )
          .toList(growable: false);
      var changed = false;
      final normalizedThemes = <AppAdvancedTheme>[];
      for (final theme in themes) {
        final normalizedTheme = await _normalizeThemeForRuntime(theme);
        if (_themeNeedsPersistenceNormalization(theme, normalizedTheme)) {
          changed = true;
        }
        normalizedThemes.add(normalizedTheme);
      }
      normalizedThemes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      if (changed) {
        await saveThemes(normalizedThemes);
      }
      return normalizedThemes;
    } catch (_) {
      return const <AppAdvancedTheme>[];
    }
  }

  Future<void> saveThemes(List<AppAdvancedTheme> themes) async {
    final prefs = await _preferencesFuture;
    if (themes.isEmpty) {
      await prefs.remove(_themesKey);
      return;
    }
    final persistedThemes = <Map<String, dynamic>>[];
    for (final theme in themes) {
      persistedThemes.add(
        (await _normalizeThemeForPersistence(theme)).toJson(),
      );
    }
    await prefs.setString(_themesKey, jsonEncode(persistedThemes));
  }

  Future<AppAdvancedTheme> _normalizeThemeForRuntime(
    AppAdvancedTheme theme,
  ) async {
    return theme.copyWith(
      lightConfig: await _normalizeModeConfigForRuntime(theme.lightConfig),
      darkConfig: await _normalizeModeConfigForRuntime(theme.darkConfig),
    );
  }

  Future<AppAdvancedTheme> _normalizeThemeForPersistence(
    AppAdvancedTheme theme,
  ) async {
    return theme.copyWith(
      lightConfig: await _normalizeModeConfigForPersistence(theme.lightConfig),
      darkConfig: await _normalizeModeConfigForPersistence(theme.darkConfig),
    );
  }

  Future<AppAdvancedThemeModeConfig> _normalizeModeConfigForRuntime(
    AppAdvancedThemeModeConfig config,
  ) async {
    return config.copyWith(
      wallpaperAsset: await _assetStore.normalizeRefForRuntime(
        config.wallpaperAsset,
      ),
      clearWallpaperAsset: config.wallpaperAsset == null,
      readerWallpaperAsset: await _assetStore.normalizeRefForRuntime(
        config.readerWallpaperAsset,
      ),
      clearReaderWallpaperAsset: config.readerWallpaperAsset == null,
    );
  }

  Future<AppAdvancedThemeModeConfig> _normalizeModeConfigForPersistence(
    AppAdvancedThemeModeConfig config,
  ) async {
    return config.copyWith(
      wallpaperAsset: await _assetStore.relativizeRef(config.wallpaperAsset),
      clearWallpaperAsset: config.wallpaperAsset == null,
      readerWallpaperAsset: await _assetStore.relativizeRef(
        config.readerWallpaperAsset,
      ),
      clearReaderWallpaperAsset: config.readerWallpaperAsset == null,
    );
  }

  bool _themeNeedsPersistenceNormalization(
    AppAdvancedTheme original,
    AppAdvancedTheme normalized,
  ) {
    return original.lightConfig.wallpaperAsset?.normalizedRelativePath !=
            normalized.lightConfig.wallpaperAsset?.normalizedRelativePath ||
        original.lightConfig.wallpaperAsset?.normalizedResolvedPath !=
            normalized.lightConfig.wallpaperAsset?.normalizedResolvedPath ||
        original.lightConfig.readerWallpaperAsset?.normalizedRelativePath !=
            normalized
                .lightConfig
                .readerWallpaperAsset
                ?.normalizedRelativePath ||
        original.lightConfig.readerWallpaperAsset?.normalizedResolvedPath !=
            normalized
                .lightConfig
                .readerWallpaperAsset
                ?.normalizedResolvedPath ||
        original.darkConfig.wallpaperAsset?.normalizedRelativePath !=
            normalized.darkConfig.wallpaperAsset?.normalizedRelativePath ||
        original.darkConfig.wallpaperAsset?.normalizedResolvedPath !=
            normalized.darkConfig.wallpaperAsset?.normalizedResolvedPath ||
        original.darkConfig.readerWallpaperAsset?.normalizedRelativePath !=
            normalized
                .darkConfig
                .readerWallpaperAsset
                ?.normalizedRelativePath ||
        original.darkConfig.readerWallpaperAsset?.normalizedResolvedPath !=
            normalized.darkConfig.readerWallpaperAsset?.normalizedResolvedPath;
  }

  Future<String?> loadActiveThemeId() async {
    final prefs = await _preferencesFuture;
    return readActiveThemeId(prefs);
  }

  Future<void> saveActiveThemeId(String? themeId) async {
    final prefs = await _preferencesFuture;
    final normalized = themeId?.trim();
    if (normalized == null || normalized.isEmpty) {
      await prefs.remove(_activeThemeIdKey);
      return;
    }
    await prefs.setString(_activeThemeIdKey, normalized);
  }

  Future<AppAdvancedTheme?> loadActiveTheme() async {
    final activeId = await loadActiveThemeId();
    if (activeId == null) {
      return null;
    }
    final themes = await loadThemes();
    for (final theme in themes) {
      if (theme.id == activeId) {
        return theme;
      }
    }
    return null;
  }

  Future<AppAdvancedTheme> saveTheme(AppAdvancedTheme theme) async {
    final themes = await loadThemes();
    final now = DateTime.now().toUtc();
    final normalized = theme.copyWith(updatedAt: now);
    final existingIndex = themes.indexWhere((item) => item.id == normalized.id);
    final updated = [...themes];
    if (existingIndex >= 0) {
      updated[existingIndex] = normalized;
    } else {
      updated.add(normalized.copyWith(createdAt: now));
    }
    await saveThemes(updated);
    return normalized;
  }

  Future<void> deleteTheme(
    String themeId, {
    bool deleteAssociatedResources = true,
  }) async {
    final themes = await loadThemes();
    AppAdvancedTheme? removedTheme;
    final updated = themes
        .where((item) {
          final matched = item.id == themeId;
          if (matched) {
            removedTheme = item;
          }
          return !matched;
        })
        .toList(growable: false);
    await saveThemes(updated);
    if (removedTheme != null && deleteAssociatedResources) {
      final targetTheme = removedTheme!;
      final appearancePaths = <String>{
        ...[
              targetTheme.lightConfig.wallpaperPath,
              targetTheme.darkConfig.wallpaperPath,
            ]
            .whereType<String>()
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty),
      };
      final readerPaths = <String>{
        ...[
              targetTheme.lightConfig.readerWallpaperPath,
              targetTheme.darkConfig.readerWallpaperPath,
            ]
            .whereType<String>()
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty),
      };
      final coverGalleryIds = _coverGalleryIdsForTheme(targetTheme);
      final launchGalleryId = targetTheme.launchImageGalleryId?.trim();
      final bottomNavGalleryId = targetTheme.bottomNavGalleryId?.trim();

      for (final path in appearancePaths) {
        if (!_isAppearanceBackgroundReferenced(updated, path)) {
          await deleteWallpaper(path);
        }
      }
      for (final path in readerPaths) {
        if (!_isReaderBackgroundReferenced(updated, path)) {
          await ReaderBackgroundService().deleteBackground(path);
        }
      }
      for (final galleryId in coverGalleryIds) {
        if (!_isCoverGalleryReferenced(updated, galleryId)) {
          await _safeDeleteCoverGallery(galleryId);
        }
      }
      if (launchGalleryId != null &&
          launchGalleryId.isNotEmpty &&
          !_isLaunchGalleryReferenced(updated, launchGalleryId)) {
        await _safeDeleteLaunchGallery(launchGalleryId);
      }
      if (bottomNavGalleryId != null &&
          bottomNavGalleryId.isNotEmpty &&
          !_isBottomNavGalleryReferenced(updated, bottomNavGalleryId)) {
        await _safeDeleteBottomNavGallery(bottomNavGalleryId);
      }
    }
    if (deleteAssociatedResources) {
      final directory = await _themeDirectory(themeId);
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    }
  }

  Future<AppAdvancedTheme> duplicateTheme(
    AppAdvancedTheme source, {
    String? name,
  }) async {
    final now = DateTime.now().toUtc();
    final cloneId = 'advanced_theme_${_uuid.v4()}';
    final cloneName =
        name?.trim().isNotEmpty == true ? name!.trim() : '${source.name} 副本';
    final lightWallpaperPath = await _duplicateWallpaper(
      sourcePath: source.lightConfig.wallpaperPath,
      readerAsset: false,
    );
    final darkWallpaperPath = await _duplicateWallpaper(
      sourcePath: source.darkConfig.wallpaperPath,
      readerAsset: false,
    );
    final lightReaderWallpaperPath = await _duplicateWallpaper(
      sourcePath: source.lightConfig.readerWallpaperPath,
      readerAsset: true,
    );
    final darkReaderWallpaperPath = await _duplicateWallpaper(
      sourcePath: source.darkConfig.readerWallpaperPath,
      readerAsset: true,
    );
    final clone = source.copyWith(
      id: cloneId,
      name: cloneName,
      createdAt: now,
      updatedAt: now,
      lightConfig: source.lightConfig.copyWith(
        wallpaperPath: lightWallpaperPath,
        clearWallpaperPath: lightWallpaperPath == null,
        readerWallpaperPath: lightReaderWallpaperPath,
        clearReaderWallpaperPath: lightReaderWallpaperPath == null,
      ),
      darkConfig: source.darkConfig.copyWith(
        wallpaperPath: darkWallpaperPath,
        clearWallpaperPath: darkWallpaperPath == null,
        readerWallpaperPath: darkReaderWallpaperPath,
        clearReaderWallpaperPath: darkReaderWallpaperPath == null,
      ),
    );
    return saveTheme(clone);
  }

  String createThemeId() {
    return 'advanced_theme_${_uuid.v4()}';
  }

  String encodeThemeColorJson(AppAdvancedTheme theme) {
    return const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
      'type': _colorExportType,
      'version': _colorExportVersion,
      'name': theme.name,
      'lightConfig': _encodeThemeColorModeConfig(theme.lightConfig),
      'darkConfig': _encodeThemeColorModeConfig(theme.darkConfig),
    });
  }

  Future<AppAdvancedTheme> importThemeColorJson(String rawJson) async {
    final fingerprint = _computeImportFingerprint(utf8.encode(rawJson));
    await _ensureImportFingerprintAvailable(fingerprint);
    final decoded = jsonDecode(rawJson);
    if (decoded is! Map) {
      throw const FormatException('Invalid theme JSON.');
    }
    final payload = decoded.map(
      (key, value) => MapEntry(key.toString(), value),
    );
    final type = payload['type']?.toString().trim() ?? '';
    if (type != _colorExportType) {
      throw const FormatException('Unsupported theme JSON type.');
    }
    final version = payload['version'];
    final normalizedVersion =
        version is num ? version.toInt() : int.tryParse('$version');
    if (normalizedVersion != _legacyColorExportVersion &&
        normalizedVersion != _colorExportVersion) {
      throw const FormatException('Unsupported theme JSON version.');
    }

    final rawName = payload['name']?.toString().trim() ?? '';
    final now = DateTime.now().toUtc();
    final lightConfig =
        normalizedVersion == _legacyColorExportVersion
            ? AppAdvancedThemeModeConfig(
              colors: _readExportedColors(payload, 'lightColors'),
            )
            : _readExportedModeConfig(payload, 'lightConfig');
    final darkConfig =
        normalizedVersion == _legacyColorExportVersion
            ? AppAdvancedThemeModeConfig(
              colors: _readExportedColors(payload, 'darkColors'),
            )
            : _readExportedModeConfig(payload, 'darkConfig');

    final importedTheme = AppAdvancedTheme(
      id: createThemeId(),
      name: rawName.isEmpty ? '导入主题' : rawName,
      createdAt: now,
      updatedAt: now,
      lightConfig: lightConfig,
      darkConfig: darkConfig,
      importFingerprint: fingerprint,
    );
    return saveTheme(importedTheme);
  }

  Future<List<int>> encodeThemeBundleZip(AppAdvancedTheme theme) async {
    final archive = Archive();
    final manifest = <String, dynamic>{
      'type': _bundleExportType,
      'version': _bundleExportVersion,
      'theme': theme.toJson(),
      'resources': <String, String?>{},
    };

    Future<String?> addThemeFile(String key, String? path) async {
      final normalized = path?.trim() ?? '';
      if (normalized.isEmpty) {
        return null;
      }
      final file = File(normalized);
      if (!await file.exists()) {
        return null;
      }
      final bundlePath =
          'theme_resources/$key${p.extension(file.path).isEmpty ? '.png' : p.extension(file.path)}';
      archive.addFile(
        ArchiveFile(bundlePath, await file.length(), await file.readAsBytes()),
      );
      return bundlePath;
    }

    manifest['resources']['lightWallpaperPath'] = await addThemeFile(
      'light_wallpaper',
      theme.lightConfig.wallpaperPath,
    );
    manifest['resources']['darkWallpaperPath'] = await addThemeFile(
      'dark_wallpaper',
      theme.darkConfig.wallpaperPath,
    );
    manifest['resources']['lightReaderWallpaperPath'] = await addThemeFile(
      'light_reader_wallpaper',
      theme.lightConfig.readerWallpaperPath,
    );
    manifest['resources']['darkReaderWallpaperPath'] = await addThemeFile(
      'dark_reader_wallpaper',
      theme.darkConfig.readerWallpaperPath,
    );

    final coverService = CoverGalleryService(
      preferences: await _preferencesFuture,
    );
    final lightCoverGalleryId = theme.coverGalleryIdFor(
      AppAdvancedThemeMode.light,
    );
    final darkCoverGalleryId = theme.coverGalleryIdFor(
      AppAdvancedThemeMode.dark,
    );
    if (lightCoverGalleryId != null &&
        darkCoverGalleryId != null &&
        lightCoverGalleryId == darkCoverGalleryId) {
      final coverGallery = await coverService.loadGallery(lightCoverGalleryId);
      final coverManifest = await _appendImageGalleryToArchive(
        archive,
        folder: 'cover_gallery',
        imagePaths: coverGallery?.imagePaths ?? const <String>[],
        name: coverGallery?.name,
      );
      if (coverManifest != null) {
        manifest['coverGallery'] = coverManifest;
      }
    } else {
      final lightCoverGallery =
          lightCoverGalleryId == null
              ? null
              : await coverService.loadGallery(lightCoverGalleryId);
      final darkCoverGallery =
          darkCoverGalleryId == null
              ? null
              : await coverService.loadGallery(darkCoverGalleryId);
      final lightCoverManifest = await _appendImageGalleryToArchive(
        archive,
        folder: 'cover_gallery_light',
        imagePaths: lightCoverGallery?.imagePaths ?? const <String>[],
        name: lightCoverGallery?.name,
      );
      if (lightCoverManifest != null) {
        manifest['lightCoverGallery'] = lightCoverManifest;
      }
      final darkCoverManifest = await _appendImageGalleryToArchive(
        archive,
        folder: 'cover_gallery_dark',
        imagePaths: darkCoverGallery?.imagePaths ?? const <String>[],
        name: darkCoverGallery?.name,
      );
      if (darkCoverManifest != null) {
        manifest['darkCoverGallery'] = darkCoverManifest;
      }
    }

    final launchService = LaunchImageGalleryService(
      preferences: await _preferencesFuture,
    );
    final launchGallery = await launchService.loadGallery(
      theme.launchImageGalleryId ?? '',
    );
    final launchManifest = await _appendImageGalleryToArchive(
      archive,
      folder: 'launch_gallery',
      imagePaths: launchGallery?.imagePaths ?? const <String>[],
      name: launchGallery?.name,
    );
    if (launchManifest != null) {
      manifest['launchImageGallery'] = launchManifest;
    }

    final bottomNavGallery = await _findBottomNavGallery(
      theme.bottomNavGalleryId,
    );
    final bottomNavManifest = await _appendBottomNavGalleryToArchive(
      archive,
      bottomNavGallery,
    );
    if (bottomNavManifest != null) {
      manifest['bottomNavGallery'] = bottomNavManifest;
    }

    final fontManifest = await _appendThemeFontsToArchive(archive, theme);
    if (fontManifest != null) {
      manifest['fonts'] = fontManifest;
    }

    final manifestBytes = utf8.encode(
      const JsonEncoder.withIndent('  ').convert(manifest),
    );
    archive.addFile(
      ArchiveFile('manifest.json', manifestBytes.length, manifestBytes),
    );
    return ZipEncoder().encode(archive);
  }

  Future<AppAdvancedTheme> importThemeBundleZipBytes(List<int> bytes) async {
    final fingerprint = _computeImportFingerprint(bytes);
    await _ensureImportFingerprintAvailable(fingerprint);
    final archive = _decodeZipArchiveBytes(bytes);
    final manifestFile = archive.findFile('manifest.json');
    if (manifestFile == null) {
      throw const FormatException('主题压缩包缺少 manifest.json。');
    }
    final manifestRaw = utf8.decode(manifestFile.content as List<int>);
    final decoded = jsonDecode(manifestRaw);
    if (decoded is! Map) {
      throw const FormatException('主题压缩包配置无效。');
    }
    final manifest = decoded.map(
      (key, value) => MapEntry(key.toString(), value),
    );
    final type = manifest['type']?.toString().trim() ?? '';
    if (type != _bundleExportType) {
      throw const FormatException('不支持的主题压缩包类型。');
    }
    final version = manifest['version'];
    final normalizedVersion =
        version is num ? version.toInt() : int.tryParse('$version');
    if (normalizedVersion != _bundleExportVersion) {
      throw const FormatException('不支持的主题压缩包版本。');
    }

    final rawTheme = manifest['theme'];
    if (rawTheme is! Map) {
      throw const FormatException('主题压缩包缺少主题配置。');
    }
    final importedTheme = AppAdvancedTheme.fromJson(
      rawTheme.map((key, value) => MapEntry(key.toString(), value)),
    );
    final themeId = createThemeId();
    final now = DateTime.now().toUtc();
    final themeDirectory = await _themeDirectory(themeId);
    String? coverGalleryId;
    String? lightCoverGalleryId;
    String? darkCoverGalleryId;
    String? launchImageGalleryId;
    String? bottomNavGalleryId;
    final importedFontFamilyKeys = <String>[];
    final sharedBackgroundPaths = <String>[];
    final sharedReaderBackgroundPaths = <String>[];

    try {
      if (!await themeDirectory.exists()) {
        await themeDirectory.create(recursive: true);
      }

      final resourceMap =
          manifest['resources'] is Map
              ? (manifest['resources'] as Map).map(
                (key, value) => MapEntry(key.toString(), value?.toString()),
              )
              : const <String, String?>{};

      final lightWallpaperPath = await _extractArchiveFileToThemeDirectory(
        archive,
        themeDirectory,
        resourceMap['lightWallpaperPath'],
        targetNamePrefix: 'wallpaper_light',
      );
      final darkWallpaperPath = await _extractArchiveFileToThemeDirectory(
        archive,
        themeDirectory,
        resourceMap['darkWallpaperPath'],
        targetNamePrefix: 'wallpaper_dark',
      );
      final lightReaderWallpaperPath =
          await _extractArchiveFileToThemeDirectory(
            archive,
            themeDirectory,
            resourceMap['lightReaderWallpaperPath'],
            targetNamePrefix: 'reader_wallpaper_light',
          );
      final darkReaderWallpaperPath = await _extractArchiveFileToThemeDirectory(
        archive,
        themeDirectory,
        resourceMap['darkReaderWallpaperPath'],
        targetNamePrefix: 'reader_wallpaper_dark',
      );

      final importedLightWallpaperPath =
          lightWallpaperPath == null
              ? null
              : await _importAppearanceBackgroundFromFile(
                lightWallpaperPath,
                fileName: p.basename(lightWallpaperPath),
              );
      if (importedLightWallpaperPath != null) {
        sharedBackgroundPaths.add(importedLightWallpaperPath);
      }
      final importedDarkWallpaperPath =
          darkWallpaperPath == null
              ? null
              : await _importAppearanceBackgroundFromFile(
                darkWallpaperPath,
                fileName: p.basename(darkWallpaperPath),
              );
      if (importedDarkWallpaperPath != null) {
        sharedBackgroundPaths.add(importedDarkWallpaperPath);
      }
      final importedLightReaderWallpaperPath =
          lightReaderWallpaperPath == null
              ? null
              : await ReaderBackgroundService().importBackground(
                bytes: await File(lightReaderWallpaperPath).readAsBytes(),
                fileName: p.basename(lightReaderWallpaperPath),
              );
      if (importedLightReaderWallpaperPath != null) {
        sharedReaderBackgroundPaths.add(importedLightReaderWallpaperPath);
      }
      final importedDarkReaderWallpaperPath =
          darkReaderWallpaperPath == null
              ? null
              : await ReaderBackgroundService().importBackground(
                bytes: await File(darkReaderWallpaperPath).readAsBytes(),
                fileName: p.basename(darkReaderWallpaperPath),
              );
      if (importedDarkReaderWallpaperPath != null) {
        sharedReaderBackgroundPaths.add(importedDarkReaderWallpaperPath);
      }

      coverGalleryId = await _importImageGalleryFromBundle(
        archive,
        manifest['coverGallery'],
        isLaunchGallery: false,
      );
      if (coverGalleryId != null) {
        lightCoverGalleryId = coverGalleryId;
        darkCoverGalleryId = coverGalleryId;
      } else {
        lightCoverGalleryId = await _importImageGalleryFromBundle(
          archive,
          manifest['lightCoverGallery'],
          isLaunchGallery: false,
        );
        darkCoverGalleryId = await _importImageGalleryFromBundle(
          archive,
          manifest['darkCoverGallery'],
          isLaunchGallery: false,
        );
      }
      launchImageGalleryId = await _importImageGalleryFromBundle(
        archive,
        manifest['launchImageGallery'],
        isLaunchGallery: true,
      );
      bottomNavGalleryId = await _importBottomNavGalleryFromBundle(
        archive,
        manifest['bottomNavGallery'],
      );
      final importedFonts = await _importThemeFontsFromBundle(
        archive,
        themeDirectory,
        manifest['fonts'],
      );
      importedFontFamilyKeys.addAll(importedFonts.importedFamilyKeys);

      final theme = importedTheme.copyWith(
        id: themeId,
        name: importedTheme.name,
        createdAt: now,
        updatedAt: now,
        lightConfig: importedTheme.lightConfig.copyWith(
          wallpaperPath: importedLightWallpaperPath,
          clearWallpaperPath: importedLightWallpaperPath == null,
          readerWallpaperPath: importedLightReaderWallpaperPath,
          clearReaderWallpaperPath: importedLightReaderWallpaperPath == null,
        ),
        darkConfig: importedTheme.darkConfig.copyWith(
          wallpaperPath: importedDarkWallpaperPath,
          clearWallpaperPath: importedDarkWallpaperPath == null,
          readerWallpaperPath: importedDarkReaderWallpaperPath,
          clearReaderWallpaperPath: importedDarkReaderWallpaperPath == null,
        ),
        coverGalleryId:
            lightCoverGalleryId != null &&
                    darkCoverGalleryId != null &&
                    lightCoverGalleryId == darkCoverGalleryId
                ? lightCoverGalleryId
                : null,
        clearCoverGalleryId:
            !(lightCoverGalleryId != null &&
                darkCoverGalleryId != null &&
                lightCoverGalleryId == darkCoverGalleryId),
        lightCoverGalleryId: lightCoverGalleryId,
        clearLightCoverGalleryId: lightCoverGalleryId == null,
        darkCoverGalleryId: darkCoverGalleryId,
        clearDarkCoverGalleryId: darkCoverGalleryId == null,
        launchImageGalleryId: launchImageGalleryId,
        clearLaunchImageGalleryId: launchImageGalleryId == null,
        bottomNavGalleryId: bottomNavGalleryId,
        clearBottomNavGalleryId: bottomNavGalleryId == null,
        appInterfaceFontFamilyKey:
            importedFonts.hasManifest
                ? importedFonts.appInterfaceFontFamilyKey
                : importedTheme.appInterfaceFontFamilyKey,
        clearAppInterfaceFontFamilyKey:
            importedFonts.hasManifest &&
            importedFonts.appInterfaceFontFamilyKey == null,
        readerFontFamilyKey:
            importedFonts.hasManifest
                ? importedFonts.readerFontFamilyKey
                : importedTheme.readerFontFamilyKey,
        clearReaderFontFamilyKey:
            importedFonts.hasManifest &&
            importedFonts.readerFontFamilyKey == null,
        importFingerprint: fingerprint,
      );
      return saveTheme(theme);
    } catch (_) {
      await _cleanupImportedThemeBundleArtifacts(
        themeDirectory: themeDirectory,
        coverGalleryIds: <String?>[
          coverGalleryId,
          lightCoverGalleryId,
          darkCoverGalleryId,
        ],
        launchImageGalleryId: launchImageGalleryId,
        bottomNavGalleryId: bottomNavGalleryId,
        importedFontFamilyKeys: importedFontFamilyKeys,
        sharedBackgroundPaths: sharedBackgroundPaths,
        sharedReaderBackgroundPaths: sharedReaderBackgroundPaths,
      );
      rethrow;
    }
  }

  Future<AppAdvancedTheme> importRedThemePackageBytes(List<int> bytes) async {
    final fingerprint = _computeImportFingerprint(bytes);
    await _ensureImportFingerprintAvailable(fingerprint);
    final archive = _decodeRedThemeArchiveBytes(bytes);
    final themeFile = archive.findFile('theme.json');
    if (themeFile == null) {
      throw const FormatException('Red 主题包缺少 theme.json。');
    }
    final decoded = jsonDecode(
      utf8.decode(_archiveFileBytes(themeFile), allowMalformed: true),
    );
    if (decoded is! Map) {
      throw const FormatException('Red 主题包配置无效。');
    }
    final manifest = decoded.map(
      (key, value) => MapEntry(key.toString(), value),
    );
    final rawName = manifest['name']?.toString().trim() ?? '';
    final lightSection = _readRequiredMap(manifest, 'light');
    final darkSection = _readRequiredMap(manifest, 'dark');
    final themeId = createThemeId();
    final now = DateTime.now().toUtc();
    final themeDirectory = await _themeDirectory(themeId);
    String? coverGalleryId;
    String? lightCoverGalleryId;
    String? darkCoverGalleryId;
    String? bottomNavGalleryId;
    final sharedBackgroundPaths = <String>[];
    final sharedReaderBackgroundPaths = <String>[];

    try {
      if (!await themeDirectory.exists()) {
        await themeDirectory.create(recursive: true);
      }

      final lightWallpaperPath =
          await _extractOptionalArchiveFileToThemeDirectory(
            archive,
            themeDirectory,
            'light/theme_bg.img',
            targetNamePrefix: 'wallpaper_light_red',
          );
      final darkWallpaperPath =
          await _extractOptionalArchiveFileToThemeDirectory(
            archive,
            themeDirectory,
            'dark/theme_bg.img',
            targetNamePrefix: 'wallpaper_dark_red',
          );

      final importedLightWallpaperPath =
          lightWallpaperPath == null
              ? null
              : await _importAppearanceBackgroundFromFile(
                lightWallpaperPath,
                fileName: p.basename(lightWallpaperPath),
              );
      if (importedLightWallpaperPath != null) {
        sharedBackgroundPaths.add(importedLightWallpaperPath);
      }
      final importedDarkWallpaperPath =
          darkWallpaperPath == null
              ? null
              : await _importAppearanceBackgroundFromFile(
                darkWallpaperPath,
                fileName: p.basename(darkWallpaperPath),
              );
      if (importedDarkWallpaperPath != null) {
        sharedBackgroundPaths.add(importedDarkWallpaperPath);
      }

      final lightReaderSchema = await _importRedReaderSchema(
        archive,
        themeDirectory,
        schemaId: lightSection['readerColorSchemaId']?.toString(),
        targetNamePrefix: 'reader_wallpaper_light_red',
      );
      final darkReaderSchema = await _importRedReaderSchema(
        archive,
        themeDirectory,
        schemaId: darkSection['readerColorSchemaId']?.toString(),
        targetNamePrefix: 'reader_wallpaper_dark_red',
      );

      final importedLightReaderBackgroundPath =
          lightReaderSchema?.backgroundPath == null
              ? null
              : await ReaderBackgroundService().importBackground(
                bytes:
                    await File(
                      lightReaderSchema!.backgroundPath!,
                    ).readAsBytes(),
                fileName: p.basename(lightReaderSchema.backgroundPath!),
              );
      if (importedLightReaderBackgroundPath != null) {
        sharedReaderBackgroundPaths.add(importedLightReaderBackgroundPath);
      }
      final importedDarkReaderBackgroundPath =
          darkReaderSchema?.backgroundPath == null
              ? null
              : await ReaderBackgroundService().importBackground(
                bytes:
                    await File(darkReaderSchema!.backgroundPath!).readAsBytes(),
                fileName: p.basename(darkReaderSchema.backgroundPath!),
              );
      if (importedDarkReaderBackgroundPath != null) {
        sharedReaderBackgroundPaths.add(importedDarkReaderBackgroundPath);
      }
      final resolvedLightReaderSchema =
          lightReaderSchema == null
              ? null
              : _RedReaderSchemaImport(
                backgroundPath: importedLightReaderBackgroundPath,
                opacity: lightReaderSchema.opacity,
                blurSigma: lightReaderSchema.blurSigma,
                fit: lightReaderSchema.fit,
                overlayOpacity: lightReaderSchema.overlayOpacity,
              );
      final resolvedDarkReaderSchema =
          darkReaderSchema == null
              ? null
              : _RedReaderSchemaImport(
                backgroundPath: importedDarkReaderBackgroundPath,
                opacity: darkReaderSchema.opacity,
                blurSigma: darkReaderSchema.blurSigma,
                fit: darkReaderSchema.fit,
                overlayOpacity: darkReaderSchema.overlayOpacity,
              );

      final lightRawCoverGalleryId =
          lightSection['coverGalleryId']?.toString().trim() ?? '';
      final darkRawCoverGalleryId =
          darkSection['coverGalleryId']?.toString().trim() ?? '';
      lightCoverGalleryId = await _importRedCoverGallery(
        archive,
        galleryIds: <String>{lightRawCoverGalleryId},
        fallbackName: rawName.isEmpty ? 'Red 日间封面' : '$rawName 日间封面',
      );
      if (lightRawCoverGalleryId.isNotEmpty &&
          lightRawCoverGalleryId == darkRawCoverGalleryId) {
        darkCoverGalleryId = lightCoverGalleryId;
      } else {
        darkCoverGalleryId = await _importRedCoverGallery(
          archive,
          galleryIds: <String>{darkRawCoverGalleryId},
          fallbackName: rawName.isEmpty ? 'Red 夜间封面' : '$rawName 夜间封面',
        );
      }
      if (lightCoverGalleryId != null &&
          darkCoverGalleryId != null &&
          lightCoverGalleryId == darkCoverGalleryId) {
        coverGalleryId = lightCoverGalleryId;
      }
      bottomNavGalleryId = await _importRedBottomNavGallery(
        archive,
        lightPackId: lightSection['navbarPackId']?.toString(),
        darkPackId: darkSection['navbarPackId']?.toString(),
        fallbackName: rawName.isEmpty ? 'Red 主题底栏' : '$rawName 底栏',
      );

      final theme = AppAdvancedTheme(
        id: themeId,
        name: rawName.isEmpty ? '导入 Red 主题' : rawName,
        createdAt: now,
        updatedAt: now,
        lightConfig: _buildModeConfigFromRedSection(
          lightSection,
          wallpaperPath: importedLightWallpaperPath,
          readerSchema: resolvedLightReaderSchema,
        ),
        darkConfig: _buildModeConfigFromRedSection(
          darkSection,
          wallpaperPath: importedDarkWallpaperPath,
          readerSchema: resolvedDarkReaderSchema,
        ),
        coverGalleryId: coverGalleryId,
        lightCoverGalleryId: lightCoverGalleryId,
        darkCoverGalleryId: darkCoverGalleryId,
        bottomNavGalleryId: bottomNavGalleryId,
        importFingerprint: fingerprint,
      );
      return saveTheme(theme);
    } catch (_) {
      await _cleanupImportedThemeBundleArtifacts(
        themeDirectory: themeDirectory,
        coverGalleryIds: <String?>[
          coverGalleryId,
          lightCoverGalleryId,
          darkCoverGalleryId,
        ],
        bottomNavGalleryId: bottomNavGalleryId,
        sharedBackgroundPaths: sharedBackgroundPaths,
        sharedReaderBackgroundPaths: sharedReaderBackgroundPaths,
      );
      rethrow;
    }
  }

  Future<AppAdvancedTheme> importRgShareThemePackageBytes(
    List<int> bytes,
  ) async {
    final fingerprint = _computeImportFingerprint(bytes);
    await _ensureImportFingerprintAvailable(fingerprint);
    final archive = _decodeZipArchiveBytes(bytes);
    final themeFile = archive.findFile('theme.json');
    if (themeFile == null) {
      throw const FormatException('RGShare 主题包缺少 theme.json。');
    }
    final decoded = jsonDecode(
      utf8.decode(_archiveFileBytes(themeFile), allowMalformed: true),
    );
    if (decoded is! Map) {
      throw const FormatException('RGShare 主题包配置无效。');
    }
    final manifest = decoded.map(
      (key, value) => MapEntry(key.toString(), value),
    );
    final rawName = manifest['1']?.toString().trim() ?? '';
    final themeId = createThemeId();
    final now = DateTime.now().toUtc();
    final themeDirectory = await _themeDirectory(themeId);
    final sharedBackgroundPaths = <String>[];

    try {
      if (!await themeDirectory.exists()) {
        await themeDirectory.create(recursive: true);
      }

      final imageMap = _readOptionalMap(manifest['4']);
      final lightWallpaperAsset = _resolveRgShareWallpaperFilename(
        imageMap,
        isDark: false,
      );
      final darkWallpaperAsset = _resolveRgShareWallpaperFilename(
        imageMap,
        isDark: true,
      );

      final lightWallpaperPath =
          await _extractOptionalArchiveFileToThemeDirectory(
            archive,
            themeDirectory,
            lightWallpaperAsset == null ? null : 'images/$lightWallpaperAsset',
            targetNamePrefix: 'wallpaper_light_rgshare',
          );
      final darkWallpaperPath =
          await _extractOptionalArchiveFileToThemeDirectory(
            archive,
            themeDirectory,
            darkWallpaperAsset == null ? null : 'images/$darkWallpaperAsset',
            targetNamePrefix: 'wallpaper_dark_rgshare',
          );

      final importedLightWallpaperPath =
          lightWallpaperPath == null
              ? null
              : await _importAppearanceBackgroundFromFile(
                lightWallpaperPath,
                fileName: p.basename(lightWallpaperPath),
              );
      if (importedLightWallpaperPath != null) {
        sharedBackgroundPaths.add(importedLightWallpaperPath);
      }
      final importedDarkWallpaperPath =
          darkWallpaperPath == null
              ? null
              : await _importAppearanceBackgroundFromFile(
                darkWallpaperPath,
                fileName: p.basename(darkWallpaperPath),
              );
      if (importedDarkWallpaperPath != null) {
        sharedBackgroundPaths.add(importedDarkWallpaperPath);
      }

      final colors = _readOptionalMap(manifest['2']);
      final theme = AppAdvancedTheme(
        id: themeId,
        name: rawName.isEmpty ? '导入 RGShare 主题' : rawName,
        createdAt: now,
        updatedAt: now,
        lightConfig: _buildModeConfigFromRgShare(
          colors,
          wallpaperPath: importedLightWallpaperPath,
          isDark: false,
        ),
        darkConfig: _buildModeConfigFromRgShare(
          colors,
          wallpaperPath: importedDarkWallpaperPath,
          isDark: true,
        ),
        importFingerprint: fingerprint,
      );
      return saveTheme(theme);
    } catch (_) {
      await _cleanupImportedThemeBundleArtifacts(
        themeDirectory: themeDirectory,
        sharedBackgroundPaths: sharedBackgroundPaths,
      );
      rethrow;
    }
  }

  Future<String> saveWallpaper({
    required String themeId,
    required AppAdvancedThemeMode mode,
    required List<int> bytes,
    required String fileName,
  }) async {
    final extension = _normalizeFileExtension(fileName);
    final directory = await _themeDirectory(themeId);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    final target = File(
      p.join(directory.path, 'wallpaper_${mode.name}.$extension'),
    );
    await evictFileImagePath(target.path);
    await target.writeAsBytes(bytes, flush: true);
    await evictFileImagePath(target.path);
    return target.path;
  }

  Future<void> deleteWallpaper(String path) async {
    final normalized = path.trim();
    if (normalized.isEmpty) {
      return;
    }
    await evictFileImagePath(normalized);
    await _assetStore.deletePath(normalized);
  }

  Future<Directory> _themeDirectory(String themeId) async {
    final documents = await getApplicationDocumentsDirectory();
    return Directory(p.join(documents.path, 'advanced_themes', themeId));
  }

  Future<String?> _duplicateWallpaper({
    required String? sourcePath,
    required bool readerAsset,
  }) async {
    final normalized =
        await _assetStore.resolvePersistedPath(sourcePath) ??
        sourcePath?.trim() ??
        '';
    if (normalized.isEmpty) {
      return null;
    }
    final sourceFile = File(normalized);
    if (!await sourceFile.exists()) {
      return null;
    }
    if (readerAsset) {
      return ReaderBackgroundService().importBackground(
        bytes: await sourceFile.readAsBytes(),
        fileName: p.basename(sourceFile.path),
      );
    }
    return _importAppearanceBackgroundFromFile(
      sourceFile.path,
      fileName: p.basename(sourceFile.path),
    );
  }

  String _normalizeFileExtension(String fileName) {
    final extension = p.extension(fileName).replaceFirst('.', '').trim();
    if (extension.isEmpty) {
      return 'png';
    }
    return extension.toLowerCase();
  }

  String _computeImportFingerprint(List<int> bytes) {
    return crypto.sha256.convert(bytes).toString();
  }

  Future<void> _ensureImportFingerprintAvailable(String fingerprint) async {
    if (fingerprint.trim().isEmpty) {
      return;
    }
    final themes = await loadThemes();
    for (final theme in themes) {
      final existing = theme.importFingerprint?.trim() ?? '';
      if (existing.isEmpty) {
        continue;
      }
      if (existing == fingerprint) {
        throw FormatException('已导入重复主题「${theme.name}」');
      }
    }
  }

  AppAdvancedThemeColors _readExportedColors(
    Map<String, dynamic> payload,
    String key,
  ) {
    final rawColors = payload[key];
    if (rawColors is! Map) {
      throw FormatException('Missing or invalid field: $key');
    }
    return AppAdvancedThemeColors.fromJson(
      rawColors.map(
        (nestedKey, nestedValue) => MapEntry(nestedKey.toString(), nestedValue),
      ),
    );
  }

  Map<String, dynamic> _encodeThemeColorModeConfig(
    AppAdvancedThemeModeConfig config,
  ) {
    return <String, dynamic>{
      'colors': config.colors.toJson(),
      'wallpaperOpacity': config.wallpaperOpacity,
      'wallpaperBlurSigma': config.wallpaperBlurSigma,
      'wallpaperFit': config.wallpaperFit.name,
      'wallpaperOverlayOpacity': config.wallpaperOverlayOpacity,
      'readerWallpaperOpacity': config.readerWallpaperOpacity,
      'readerWallpaperBlurSigma': config.readerWallpaperBlurSigma,
      'readerWallpaperFit': config.readerWallpaperFit.name,
      'readerWallpaperOverlayOpacity': config.readerWallpaperOverlayOpacity,
    };
  }

  AppAdvancedThemeModeConfig _readExportedModeConfig(
    Map<String, dynamic> payload,
    String key,
  ) {
    final rawConfig = payload[key];
    if (rawConfig is! Map) {
      throw FormatException('Missing or invalid field: $key');
    }
    final normalizedConfig = rawConfig.map(
      (nestedKey, nestedValue) => MapEntry(nestedKey.toString(), nestedValue),
    );
    return AppAdvancedThemeModeConfig(
      colors: _readExportedColors(normalizedConfig, 'colors'),
      wallpaperOpacity:
          _readExportedDouble(normalizedConfig, 'wallpaperOpacity') ?? 1,
      wallpaperBlurSigma:
          _readExportedDouble(normalizedConfig, 'wallpaperBlurSigma') ?? 0,
      wallpaperFit:
          _readExportedWallpaperFit(normalizedConfig, 'wallpaperFit') ??
          AppAdvancedThemeWallpaperFit.cover,
      wallpaperOverlayOpacity:
          _readExportedDouble(normalizedConfig, 'wallpaperOverlayOpacity') ??
          0.32,
      readerWallpaperOpacity:
          _readExportedDouble(normalizedConfig, 'readerWallpaperOpacity') ?? 1,
      readerWallpaperBlurSigma:
          _readExportedDouble(normalizedConfig, 'readerWallpaperBlurSigma') ??
          0,
      readerWallpaperFit:
          _readExportedWallpaperFit(normalizedConfig, 'readerWallpaperFit') ??
          AppAdvancedThemeWallpaperFit.cover,
      readerWallpaperOverlayOpacity:
          _readExportedDouble(
            normalizedConfig,
            'readerWallpaperOverlayOpacity',
          ) ??
          0,
    );
  }

  double? _readExportedDouble(Map<String, dynamic> payload, String key) {
    final value = payload[key];
    if (value == null) {
      return null;
    }
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value.toString().trim());
  }

  AppAdvancedThemeWallpaperFit? _readExportedWallpaperFit(
    Map<String, dynamic> payload,
    String key,
  ) {
    final raw = payload[key]?.toString().trim();
    return switch (raw) {
      'fill' => AppAdvancedThemeWallpaperFit.fill,
      'cover' => AppAdvancedThemeWallpaperFit.cover,
      _ => null,
    };
  }

  Archive _decodeZipArchiveBytes(List<int> bytes) {
    return ZipDecoder().decodeBytes(bytes, verify: true);
  }

  Archive _decodeRedThemeArchiveBytes(List<int> bytes) {
    if (bytes.length < 8) {
      throw const FormatException('Red 主题包内容无效。');
    }
    if (_hasRedPrefix(bytes)) {
      return _decodeZipArchiveBytes(bytes.sublist(4));
    }
    if (_looksLikeZip(bytes)) {
      return _decodeZipArchiveBytes(bytes);
    }
    throw const FormatException('不支持的 Red 主题包格式。');
  }

  bool _hasRedPrefix(List<int> bytes) {
    return bytes.length >= 8 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x45 &&
        bytes[2] == 0x44 &&
        _looksLikeZip(bytes.sublist(4));
  }

  bool _looksLikeZip(List<int> bytes) {
    return bytes.length >= 4 &&
        bytes[0] == 0x50 &&
        bytes[1] == 0x4B &&
        bytes[2] == 0x03 &&
        bytes[3] == 0x04;
  }

  Map<String, dynamic> _readRequiredMap(
    Map<String, dynamic> payload,
    String key,
  ) {
    final raw = payload[key];
    if (raw is! Map) {
      throw FormatException('Missing or invalid field: $key');
    }
    return raw.map((nestedKey, nestedValue) {
      return MapEntry(nestedKey.toString(), nestedValue);
    });
  }

  Map<String, dynamic> _readOptionalMap(Object? raw) {
    if (raw is! Map) {
      return const <String, dynamic>{};
    }
    return raw.map(
      (nestedKey, nestedValue) => MapEntry(nestedKey.toString(), nestedValue),
    );
  }

  AppAdvancedThemeModeConfig _buildModeConfigFromRedSection(
    Map<String, dynamic> payload, {
    required String? wallpaperPath,
    required _RedReaderSchemaImport? readerSchema,
  }) {
    final backgroundColor = _parseHexColorValue(
      payload['backgroundColor']?.toString(),
    );
    final foregroundColor = _parseHexColorValue(
      payload['foregroundColor']?.toString(),
    );
    final mutedForegroundColor = _parseHexColorValue(
      payload['mutedForegroundColor']?.toString(),
    );
    final cardColor = _parseHexColorValue(payload['cardColor']?.toString());
    final cardForegroundColor = _parseHexColorValue(
      payload['cardForegroundColor']?.toString(),
    );
    final mutedColor = _parseHexColorValue(payload['mutedColor']?.toString());
    final borderColor = _parseHexColorValue(payload['borderColor']?.toString());
    final primaryColor = _parseHexColorValue(
      payload['primaryColor']?.toString() ?? payload['accentColor']?.toString(),
    );
    final accentColor = _parseHexColorValue(payload['accentColor']?.toString());
    final searchFieldBackgroundColor = _parseHexColorValue(
      payload['searchFieldBackgroundColor']?.toString(),
    );

    return AppAdvancedThemeModeConfig(
      colors: AppAdvancedThemeColors(
        primaryColorValue: primaryColor ?? accentColor,
        secondaryColorValue: accentColor ?? primaryColor,
        noticeAccentColorValue: accentColor ?? primaryColor,
        noticeSurfaceColorValue: mutedColor,
        primaryContainerColorValue: mutedColor,
        backgroundColorValue: backgroundColor,
        surfaceColorValue: mutedColor ?? cardColor,
        searchFieldBackgroundColorValue:
            searchFieldBackgroundColor ?? mutedColor ?? cardColor,
        elevatedSurfaceColorValue: cardColor ?? mutedColor,
        cardColorValue: cardColor,
        cardTextColorValue: cardForegroundColor ?? foregroundColor,
        cardBorderColorValue: borderColor,
        iconBackgroundColorValue: mutedColor,
        textPrimaryColorValue: foregroundColor,
        textSecondaryColorValue: mutedForegroundColor,
        buttonTextColorValue: foregroundColor,
        outlineColorValue: borderColor,
        shadowColorValue: null,
        wallpaperOverlayColorValue: backgroundColor,
      ),
      wallpaperPath: wallpaperPath,
      wallpaperOpacity: wallpaperPath == null ? 1 : 1,
      wallpaperBlurSigma: 0,
      wallpaperFit: AppAdvancedThemeWallpaperFit.fill,
      wallpaperOverlayOpacity: wallpaperPath == null ? 0.32 : 0,
      readerWallpaperPath: readerSchema?.backgroundPath,
      readerWallpaperOpacity: readerSchema?.opacity ?? 1,
      readerWallpaperBlurSigma: readerSchema?.blurSigma ?? 0,
      readerWallpaperFit:
          readerSchema?.fit ?? AppAdvancedThemeWallpaperFit.fill,
      readerWallpaperOverlayOpacity: readerSchema?.overlayOpacity ?? 0,
    );
  }

  AppAdvancedThemeModeConfig _buildModeConfigFromRgShare(
    Map<String, dynamic> colors, {
    required String? wallpaperPath,
    required bool isDark,
  }) {
    int? read(String key) => _parseHexColorValue(colors[key]?.toString());

    final primaryColor = read(isDark ? '28' : '27') ?? read('5');
    final backgroundColor = read(isDark ? '14' : '13');
    final surfaceColor = read(isDark ? '18' : '17') ?? backgroundColor;
    final textPrimaryColor = read(isDark ? '25' : '12');
    final textSecondaryColor = read(isDark ? '22' : '24');
    final outlineColor = read(isDark ? '24' : '23');
    final cardColor = read(isDark ? '18' : '17') ?? surfaceColor;
    final cardTextColor = read(isDark ? '25' : '12') ?? textPrimaryColor;
    final searchFieldBackgroundColor = read(isDark ? '18' : '17') ?? cardColor;

    return AppAdvancedThemeModeConfig(
      colors: AppAdvancedThemeColors(
        primaryColorValue: primaryColor,
        secondaryColorValue: primaryColor,
        noticeAccentColorValue: primaryColor,
        noticeSurfaceColorValue: surfaceColor,
        primaryContainerColorValue: surfaceColor,
        backgroundColorValue: backgroundColor,
        surfaceColorValue: surfaceColor,
        searchFieldBackgroundColorValue: searchFieldBackgroundColor,
        elevatedSurfaceColorValue: cardColor,
        cardColorValue: cardColor,
        cardTextColorValue: cardTextColor,
        cardBorderColorValue: outlineColor,
        iconBackgroundColorValue: surfaceColor,
        textPrimaryColorValue: textPrimaryColor,
        textSecondaryColorValue: textSecondaryColor,
        buttonTextColorValue: read(isDark ? '26' : '25') ?? cardTextColor,
        outlineColorValue: outlineColor,
        wallpaperOverlayColorValue: backgroundColor,
      ),
      wallpaperPath: wallpaperPath,
      wallpaperFit: AppAdvancedThemeWallpaperFit.fill,
      wallpaperOverlayOpacity: wallpaperPath == null ? 0.32 : 0,
    );
  }

  String? _resolveRgShareWallpaperFilename(
    Map<String, dynamic> imageMap, {
    required bool isDark,
  }) {
    final expectedSuffix = isDark ? '_dark' : '_light';
    for (final entry in imageMap.entries) {
      final value = entry.value?.toString().trim() ?? '';
      if (value.isNotEmpty &&
          value.toLowerCase().contains(expectedSuffix) &&
          value.toLowerCase().endsWith('.jpg')) {
        return value;
      }
    }
    final candidates = imageMap.values
        .map((value) => value?.toString().trim() ?? '')
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    if (candidates.isEmpty) {
      return null;
    }
    if (candidates.length == 1) {
      return candidates.first;
    }
    return isDark ? candidates.last : candidates.first;
  }

  int? _parseHexColorValue(String? raw) {
    final normalized = raw?.trim().toUpperCase() ?? '';
    if (normalized.isEmpty) {
      return null;
    }
    final body =
        normalized.startsWith('#') ? normalized.substring(1) : normalized;
    if (body.length == 6) {
      return int.tryParse('FF$body', radix: 16);
    }
    if (body.length == 8) {
      return int.tryParse(body, radix: 16);
    }
    return null;
  }

  Future<Map<String, dynamic>?> _appendImageGalleryToArchive(
    Archive archive, {
    required String folder,
    required List<String> imagePaths,
    required String? name,
  }) async {
    final normalizedName = name?.trim() ?? '';
    final existingPaths = <String>[];
    for (final path in imagePaths) {
      final file = File(path);
      if (await file.exists()) {
        existingPaths.add(file.path);
      }
    }
    if (normalizedName.isEmpty || existingPaths.isEmpty) {
      return null;
    }

    final bundlePaths = <String>[];
    for (var index = 0; index < existingPaths.length; index++) {
      final file = File(existingPaths[index]);
      final ext = p.extension(file.path);
      final bundlePath = '$folder/image_$index${ext.isEmpty ? '.png' : ext}';
      archive.addFile(
        ArchiveFile(bundlePath, await file.length(), await file.readAsBytes()),
      );
      bundlePaths.add(bundlePath);
    }
    return <String, dynamic>{'name': normalizedName, 'images': bundlePaths};
  }

  Future<Map<String, dynamic>?> _appendThemeFontsToArchive(
    Archive archive,
    AppAdvancedTheme theme,
  ) async {
    final boundFamilyKeys = <String>{
      ...[theme.appInterfaceFontFamilyKey, theme.readerFontFamilyKey]
          .whereType<String>()
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty),
    };
    if (boundFamilyKeys.isEmpty) {
      return null;
    }

    final fontService = ReaderFontRegistryService();
    final fonts = await fontService.listRegisteredFonts();
    final fontByFamilyKey = <String, ReaderCustomFontEntry>{
      for (final entry in fonts) entry.fontFamilyKey: entry,
    };
    final entriesManifest = <String, Map<String, dynamic>>{};

    for (final familyKey in boundFamilyKeys) {
      final entry = fontByFamilyKey[familyKey];
      if (entry == null) {
        continue;
      }
      final file = File(entry.filePath);
      if (!await file.exists()) {
        continue;
      }
      final extension = p.extension(file.path);
      final bundlePath =
          'theme_fonts/$familyKey${extension.isEmpty ? '.ttf' : extension}';
      archive.addFile(
        ArchiveFile(bundlePath, await file.length(), await file.readAsBytes()),
      );
      entriesManifest[familyKey] = <String, dynamic>{
        'displayName': entry.displayName,
        'bundlePath': bundlePath,
      };
    }

    if (entriesManifest.isEmpty) {
      return null;
    }

    final bindings = <String, String>{};
    final appKey = theme.appInterfaceFontFamilyKey?.trim() ?? '';
    if (appKey.isNotEmpty && entriesManifest.containsKey(appKey)) {
      bindings['appInterfaceFontFamilyKey'] = appKey;
    }
    final readerKey = theme.readerFontFamilyKey?.trim() ?? '';
    if (readerKey.isNotEmpty && entriesManifest.containsKey(readerKey)) {
      bindings['readerFontFamilyKey'] = readerKey;
    }
    if (bindings.isEmpty) {
      return null;
    }

    return <String, dynamic>{'entries': entriesManifest, 'bindings': bindings};
  }

  Future<BottomNavIconGallery?> _findBottomNavGallery(String? galleryId) async {
    final normalized = galleryId?.trim() ?? '';
    if (normalized.isEmpty) {
      return null;
    }
    final service = BottomNavIconGalleryService(
      preferences: await _preferencesFuture,
    );
    final galleries = await service.loadGalleries();
    for (final gallery in galleries) {
      if (gallery.id == normalized) {
        return gallery;
      }
    }
    return null;
  }

  Future<Map<String, dynamic>?> _appendBottomNavGalleryToArchive(
    Archive archive,
    BottomNavIconGallery? gallery,
  ) async {
    if (gallery == null) {
      return null;
    }
    if (gallery.isBuiltIn) {
      return <String, dynamic>{'builtInId': gallery.id, 'name': gallery.name};
    }

    final items = <String, dynamic>{};
    for (final entry in gallery.items.entries) {
      final tabMap = <String, dynamic>{};
      for (final slot in BottomNavIconVariantSlot.values) {
        final asset = entry.value.assetForSlot(slot);
        if (asset == null) {
          continue;
        }
        if (asset.isAsset) {
          tabMap[slot.name] = <String, dynamic>{
            'path': asset.path,
            'format': asset.format.name,
            'isAsset': true,
          };
          continue;
        }
        final file = File(asset.path);
        if (!await file.exists()) {
          continue;
        }
        final ext = p.extension(file.path);
        final bundlePath =
            'bottom_nav/${entry.key.name}_${slot.name}${ext.isEmpty ? '.png' : ext}';
        archive.addFile(
          ArchiveFile(
            bundlePath,
            await file.length(),
            await file.readAsBytes(),
          ),
        );
        tabMap[slot.name] = <String, dynamic>{
          'bundlePath': bundlePath,
          'format': asset.format.name,
          'isAsset': false,
        };
      }
      items[entry.key.name] = tabMap;
    }

    return <String, dynamic>{'name': gallery.name, 'items': items};
  }

  Future<String?> _extractArchiveFileToThemeDirectory(
    Archive archive,
    Directory themeDirectory,
    String? bundlePath, {
    required String targetNamePrefix,
  }) async {
    final normalized = bundlePath?.trim() ?? '';
    if (normalized.isEmpty) {
      return null;
    }
    final file = archive.findFile(normalized);
    if (file == null) {
      throw FormatException('主题压缩包资源缺失：$normalized');
    }
    final ext = p.extension(normalized);
    final targetPath = p.join(
      themeDirectory.path,
      '$targetNamePrefix${ext.isEmpty ? '.png' : ext}',
    );
    await File(targetPath).writeAsBytes(_archiveFileBytes(file), flush: true);
    return targetPath;
  }

  Future<String?> _extractOptionalArchiveFileToThemeDirectory(
    Archive archive,
    Directory themeDirectory,
    String? bundlePath, {
    required String targetNamePrefix,
  }) async {
    final normalized = bundlePath?.trim() ?? '';
    if (normalized.isEmpty) {
      return null;
    }
    final file = archive.findFile(normalized);
    if (file == null) {
      return null;
    }
    final ext = p.extension(normalized);
    final targetPath = p.join(
      themeDirectory.path,
      '$targetNamePrefix${ext.isEmpty ? '.png' : ext}',
    );
    await File(targetPath).writeAsBytes(_archiveFileBytes(file), flush: true);
    return targetPath;
  }

  Future<String?> _importImageGalleryFromBundle(
    Archive archive,
    Object? rawManifest, {
    required bool isLaunchGallery,
  }) async {
    if (rawManifest is! Map) {
      return null;
    }
    final manifest = rawManifest.map(
      (key, value) => MapEntry(key.toString(), value),
    );
    final name = manifest['name']?.toString().trim() ?? '';
    final images = manifest['images'];
    if (name.isEmpty || images is! List || images.isEmpty) {
      return null;
    }

    final bundlePaths = <String>[];
    for (final rawPath in images) {
      final bundlePath = rawPath.toString().trim();
      if (bundlePath.isEmpty) {
        continue;
      }
      final file = archive.findFile(bundlePath);
      if (file == null) {
        throw FormatException('主题压缩包资源缺失：$bundlePath');
      }
      bundlePaths.add(bundlePath);
    }
    if (bundlePaths.isEmpty) {
      return null;
    }

    if (isLaunchGallery) {
      final service = LaunchImageGalleryService(
        preferences: await _preferencesFuture,
      );
      final gallery = await service.createGallery(name: name);
      try {
        for (final bundlePath in bundlePaths) {
          final file = archive.findFile(bundlePath)!;
          await service.importImage(
            galleryId: gallery.id,
            bytes: _archiveFileBytes(file),
            fileName: p.basename(bundlePath),
          );
        }
        final savedGallery = await service.loadGallery(gallery.id);
        if (savedGallery == null || savedGallery.imagePaths.isEmpty) {
          await service.deleteGallery(gallery.id);
          return null;
        }
        return gallery.id;
      } catch (_) {
        await _safeDeleteLaunchGallery(gallery.id);
        rethrow;
      }
    }

    final service = CoverGalleryService(preferences: await _preferencesFuture);
    final gallery = await service.createGallery(name: name);
    try {
      for (final bundlePath in bundlePaths) {
        final file = archive.findFile(bundlePath)!;
        await service.importImage(
          galleryId: gallery.id,
          bytes: _archiveFileBytes(file),
          fileName: p.basename(bundlePath),
        );
      }
      final savedGallery = await service.loadGallery(gallery.id);
      if (savedGallery == null || savedGallery.imagePaths.isEmpty) {
        await service.deleteGallery(gallery.id);
        return null;
      }
      return gallery.id;
    } catch (_) {
      await _safeDeleteCoverGallery(gallery.id);
      rethrow;
    }
  }

  Future<_ImportedThemeFonts> _importThemeFontsFromBundle(
    Archive archive,
    Directory themeDirectory,
    Object? rawManifest,
  ) async {
    if (rawManifest is! Map) {
      return const _ImportedThemeFonts();
    }
    final manifest = rawManifest.map(
      (key, value) => MapEntry(key.toString(), value),
    );
    final rawEntries = manifest['entries'];
    final rawBindings = manifest['bindings'];
    if (rawEntries is! Map || rawBindings is! Map) {
      return const _ImportedThemeFonts(hasManifest: true);
    }

    final fontService = ReaderFontRegistryService();
    final remappedFamilyKeys = <String, String>{};
    final importedFamilyKeys = <String>[];

    for (final rawEntry in rawEntries.entries) {
      final oldFamilyKey = rawEntry.key.toString().trim();
      if (oldFamilyKey.isEmpty || rawEntry.value is! Map) {
        continue;
      }
      final entryMap = (rawEntry.value as Map).map(
        (key, value) => MapEntry(key.toString(), value),
      );
      final bundlePath = entryMap['bundlePath']?.toString().trim() ?? '';
      if (bundlePath.isEmpty) {
        continue;
      }
      final extractedPath = await _extractArchiveFileToThemeDirectory(
        archive,
        themeDirectory,
        bundlePath,
        targetNamePrefix: 'font_$oldFamilyKey',
      );
      if (extractedPath == null) {
        continue;
      }
      final importedEntry = await fontService.importFontFile(
        filePath: extractedPath,
        displayName: entryMap['displayName']?.toString(),
      );
      remappedFamilyKeys[oldFamilyKey] = importedEntry.fontFamilyKey;
      importedFamilyKeys.add(importedEntry.fontFamilyKey);
    }

    final bindings = rawBindings.map(
      (key, value) => MapEntry(key.toString(), value?.toString().trim() ?? ''),
    );
    final appOldFamilyKey = bindings['appInterfaceFontFamilyKey'] ?? '';
    final readerOldFamilyKey = bindings['readerFontFamilyKey'] ?? '';

    return _ImportedThemeFonts(
      hasManifest: true,
      appInterfaceFontFamilyKey: remappedFamilyKeys[appOldFamilyKey],
      readerFontFamilyKey: remappedFamilyKeys[readerOldFamilyKey],
      importedFamilyKeys: importedFamilyKeys,
    );
  }

  Future<String?> _importBottomNavGalleryFromBundle(
    Archive archive,
    Object? rawManifest,
  ) async {
    if (rawManifest is! Map) {
      return null;
    }
    final manifest = rawManifest.map(
      (key, value) => MapEntry(key.toString(), value),
    );
    final builtInId = manifest['builtInId']?.toString().trim() ?? '';
    if (builtInId.isNotEmpty) {
      return builtInId;
    }
    final name = manifest['name']?.toString().trim() ?? '';
    final items = manifest['items'];
    if (name.isEmpty || items is! Map) {
      return null;
    }

    final importAssignments = <_BottomNavBundleImportAssignment>[];
    for (final tabEntry in items.entries) {
      final tab = _bottomNavTabFromName(tabEntry.key.toString());
      if (tab == null || tabEntry.value is! Map) {
        continue;
      }
      final slotMap = (tabEntry.value as Map).map(
        (key, value) => MapEntry(key.toString(), value),
      );
      for (final slotEntry in slotMap.entries) {
        final slot = _bottomNavSlotFromName(slotEntry.key);
        if (slot == null || slotEntry.value is! Map) {
          continue;
        }
        final assetMap = (slotEntry.value as Map).map(
          (key, value) => MapEntry(key.toString(), value),
        );
        final isAsset = assetMap['isAsset'] == true;
        final format = _bottomNavFormatFromName(assetMap['format']?.toString());
        if (format == null) {
          continue;
        }
        if (isAsset) {
          final path = assetMap['path']?.toString().trim() ?? '';
          if (path.isEmpty) {
            continue;
          }
          importAssignments.add(
            _BottomNavBundleImportAssignment.asset(
              tab: tab,
              slot: slot,
              assetRef: BottomNavIconAssetRef(
                path: path,
                format: format,
                isAsset: true,
              ),
            ),
          );
          continue;
        }
        final bundlePath = assetMap['bundlePath']?.toString().trim() ?? '';
        if (bundlePath.isEmpty) {
          continue;
        }
        final archiveFile = archive.findFile(bundlePath);
        if (archiveFile == null) {
          throw FormatException('主题压缩包资源缺失：$bundlePath');
        }
        importAssignments.add(
          _BottomNavBundleImportAssignment.bundle(
            tab: tab,
            slot: slot,
            format: format,
            bundlePath: bundlePath,
          ),
        );
      }
    }
    if (importAssignments.isEmpty) {
      return null;
    }

    final service = BottomNavIconGalleryService(
      preferences: await _preferencesFuture,
    );
    var gallery = await service.createGallery(name: name);
    var nextItems = Map<BottomNavIconGalleryTab, BottomNavIconSet>.from(
      gallery.items,
    );
    final tempDirectory = await Directory.systemTemp.createTemp(
      'advanced_theme_bundle_import_',
    );
    try {
      for (final assignment in importAssignments) {
        var iconSet = nextItems[assignment.tab] ?? const BottomNavIconSet();
        if (assignment.assetRef != null) {
          iconSet = iconSet.copyWithSlot(
            assignment.slot,
            asset: assignment.assetRef,
          );
          nextItems[assignment.tab] = iconSet;
          continue;
        }
        final archiveFile = archive.findFile(assignment.bundlePath!);
        if (archiveFile == null) {
          throw FormatException('主题压缩包资源缺失：${assignment.bundlePath}');
        }
        final tempPath = p.join(
          tempDirectory.path,
          p.basename(assignment.bundlePath!),
        );
        await File(
          tempPath,
        ).writeAsBytes(_archiveFileBytes(archiveFile), flush: true);
        final importedAsset = await service.importIconAsset(
          galleryId: gallery.id,
          tab: assignment.tab,
          slot: assignment.slot,
          sourcePath: tempPath,
          format: assignment.format!,
        );
        iconSet = iconSet.copyWithSlot(assignment.slot, asset: importedAsset);
        nextItems[assignment.tab] = iconSet;
      }
      gallery = await service.saveGallery(gallery.copyWith(items: nextItems));
      return gallery.id;
    } catch (_) {
      await _safeDeleteBottomNavGallery(gallery.id);
      rethrow;
    } finally {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    }
  }

  Future<_RedReaderSchemaImport?> _importRedReaderSchema(
    Archive archive,
    Directory themeDirectory, {
    required String? schemaId,
    required String targetNamePrefix,
  }) async {
    final normalizedId = schemaId?.trim() ?? '';
    if (normalizedId.isEmpty) {
      return null;
    }
    final schemaPath = 'reader_schema/$normalizedId/schema.json';
    final schemaFile = archive.findFile(schemaPath);
    if (schemaFile == null) {
      throw FormatException('Red 主题包缺少阅读器配置：$schemaPath');
    }
    final decoded = jsonDecode(
      utf8.decode(_archiveFileBytes(schemaFile), allowMalformed: true),
    );
    if (decoded is! Map) {
      throw FormatException('Red 阅读器配置无效：$schemaPath');
    }
    final manifest = decoded.map(
      (key, value) => MapEntry(key.toString(), value),
    );
    final backgroundPath = await _extractOptionalArchiveFileToThemeDirectory(
      archive,
      themeDirectory,
      'reader_schema/$normalizedId/bg.img',
      targetNamePrefix: targetNamePrefix,
    );
    final backgroundFit =
        switch ((manifest['backgroundImageFit']?.toString().trim() ?? '')
            .toLowerCase()) {
          'fill' => AppAdvancedThemeWallpaperFit.fill,
          'cover' => AppAdvancedThemeWallpaperFit.cover,
          _ => AppAdvancedThemeWallpaperFit.fill,
        };
    final blurSigma =
        _readExportedDouble(manifest, 'backgroundImageBlur') ??
        _readBackgroundBlurFromLayoutConfig(
          manifest['layoutConfig']?.toString(),
        ) ??
        0;
    return _RedReaderSchemaImport(
      backgroundPath: backgroundPath,
      opacity: _readExportedDouble(manifest, 'backgroundImageOpacity') ?? 1,
      blurSigma: blurSigma,
      fit: backgroundFit,
      overlayOpacity: 0,
    );
  }

  double? _readBackgroundBlurFromLayoutConfig(String? rawLayoutConfig) {
    final normalized = rawLayoutConfig?.trim() ?? '';
    if (normalized.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(normalized);
      if (decoded is! Map) {
        return null;
      }
      final payload = decoded.map(
        (key, value) => MapEntry(key.toString(), value),
      );
      return _readExportedDouble(payload, 'backgroundImageBlur');
    } catch (_) {
      return null;
    }
  }

  Future<String?> _importRedCoverGallery(
    Archive archive, {
    required Set<String> galleryIds,
    required String fallbackName,
  }) async {
    final normalizedIds = galleryIds
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty);
    final ids = normalizedIds.toSet();
    if (ids.isEmpty) {
      return null;
    }

    final images = <_RedArchiveImageEntry>[];
    String galleryName = fallbackName;
    for (final id in ids) {
      final metaPath = 'cover_gallery/$id/meta.json';
      final metaFile = archive.findFile(metaPath);
      if (metaFile == null) {
        throw FormatException('Red 主题包缺少封面图库配置：$metaPath');
      }
      final metaDecoded = jsonDecode(
        utf8.decode(_archiveFileBytes(metaFile), allowMalformed: true),
      );
      if (metaDecoded is Map) {
        final normalizedMeta = metaDecoded.map(
          (key, value) => MapEntry(key.toString(), value),
        );
        final name = normalizedMeta['name']?.toString().trim() ?? '';
        if (name.isNotEmpty) {
          galleryName = name;
        }
      }
      final prefix = 'cover_gallery/$id/';
      final groupImages = archive.files
        .where(
          (file) =>
              file.name.startsWith(prefix) &&
              !file.name.endsWith('/meta.json') &&
              !file.name.endsWith('/'),
        )
        .map((file) => _RedArchiveImageEntry(file.name))
        .toList(growable: false)..sort((a, b) => a.path.compareTo(b.path));
      if (groupImages.isEmpty) {
        throw FormatException('Red 主题包封面图库为空：$id');
      }
      images.addAll(groupImages);
    }

    final service = CoverGalleryService(preferences: await _preferencesFuture);
    final gallery = await service.createGallery(name: galleryName);
    try {
      for (final image in images) {
        final file = archive.findFile(image.path);
        if (file == null) {
          throw FormatException('Red 主题包资源缺失：${image.path}');
        }
        await service.importImage(
          galleryId: gallery.id,
          bytes: _archiveFileBytes(file),
          fileName: p.basename(image.path),
        );
      }
      return gallery.id;
    } catch (_) {
      await _safeDeleteCoverGallery(gallery.id);
      rethrow;
    }
  }

  Future<String?> _importRedBottomNavGallery(
    Archive archive, {
    required String? lightPackId,
    required String? darkPackId,
    required String fallbackName,
  }) async {
    final assignments = <_BottomNavBundleImportAssignment>[
      ..._collectRedBottomNavAssignments(
        archive,
        packId: lightPackId,
        isDark: false,
      ),
      ..._collectRedBottomNavAssignments(
        archive,
        packId: darkPackId,
        isDark: true,
      ),
    ];
    if (assignments.isEmpty) {
      return null;
    }

    final service = BottomNavIconGalleryService(
      preferences: await _preferencesFuture,
    );
    var gallery = await service.createGallery(name: fallbackName);
    var nextItems = Map<BottomNavIconGalleryTab, BottomNavIconSet>.from(
      gallery.items,
    );
    final tempDirectory = await Directory.systemTemp.createTemp(
      'red_theme_nav_import_',
    );
    try {
      for (final assignment in assignments) {
        var iconSet = nextItems[assignment.tab] ?? const BottomNavIconSet();
        final archiveFile = archive.findFile(assignment.bundlePath!);
        if (archiveFile == null) {
          throw FormatException('Red 主题包资源缺失：${assignment.bundlePath}');
        }
        final tempPath = p.join(
          tempDirectory.path,
          p.basename(assignment.bundlePath!),
        );
        await File(
          tempPath,
        ).writeAsBytes(_archiveFileBytes(archiveFile), flush: true);
        final importedAsset = await service.importIconAsset(
          galleryId: gallery.id,
          tab: assignment.tab,
          slot: assignment.slot,
          sourcePath: tempPath,
          format: assignment.format!,
        );
        iconSet = iconSet.copyWithSlot(assignment.slot, asset: importedAsset);
        nextItems[assignment.tab] = iconSet;
      }
      gallery = await service.saveGallery(gallery.copyWith(items: nextItems));
      return gallery.id;
    } catch (_) {
      await _safeDeleteBottomNavGallery(gallery.id);
      rethrow;
    } finally {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    }
  }

  List<_BottomNavBundleImportAssignment> _collectRedBottomNavAssignments(
    Archive archive, {
    required String? packId,
    required bool isDark,
  }) {
    final normalizedId = packId?.trim() ?? '';
    if (normalizedId.isEmpty) {
      return const <_BottomNavBundleImportAssignment>[];
    }
    final metaPath = 'navbar_pack/$normalizedId/meta.json';
    final metaFile = archive.findFile(metaPath);
    if (metaFile == null) {
      throw FormatException('Red 主题包缺少底栏图标包配置：$metaPath');
    }

    final filenameMap =
        <String, (BottomNavIconGalleryTab, BottomNavIconVariantSlot)>{
          'featured_normal.png': (
            BottomNavIconGalleryTab.home,
            isDark
                ? BottomNavIconVariantSlot.darkUnselected
                : BottomNavIconVariantSlot.lightUnselected,
          ),
          'featured_selected.png': (
            BottomNavIconGalleryTab.home,
            isDark
                ? BottomNavIconVariantSlot.darkSelected
                : BottomNavIconVariantSlot.lightSelected,
          ),
          'bookshelf_normal.png': (
            BottomNavIconGalleryTab.bookshelf,
            isDark
                ? BottomNavIconVariantSlot.darkUnselected
                : BottomNavIconVariantSlot.lightUnselected,
          ),
          'bookshelf_selected.png': (
            BottomNavIconGalleryTab.bookshelf,
            isDark
                ? BottomNavIconVariantSlot.darkSelected
                : BottomNavIconVariantSlot.lightSelected,
          ),
          // Legacy bundles often use `home_*` for the first tab icon.
          'home_normal.png': (
            BottomNavIconGalleryTab.home,
            isDark
                ? BottomNavIconVariantSlot.darkUnselected
                : BottomNavIconVariantSlot.lightUnselected,
          ),
          'home_selected.png': (
            BottomNavIconGalleryTab.home,
            isDark
                ? BottomNavIconVariantSlot.darkSelected
                : BottomNavIconVariantSlot.lightSelected,
          ),
          // Some bundles still use `discover_*` to describe the explore tab.
          'discover_normal.png': (
            BottomNavIconGalleryTab.discover,
            isDark
                ? BottomNavIconVariantSlot.darkUnselected
                : BottomNavIconVariantSlot.lightUnselected,
          ),
          'discover_selected.png': (
            BottomNavIconGalleryTab.discover,
            isDark
                ? BottomNavIconVariantSlot.darkSelected
                : BottomNavIconVariantSlot.lightSelected,
          ),
          'statistics_normal.png': (
            BottomNavIconGalleryTab.stats,
            isDark
                ? BottomNavIconVariantSlot.darkUnselected
                : BottomNavIconVariantSlot.lightUnselected,
          ),
          'statistics_selected.png': (
            BottomNavIconGalleryTab.stats,
            isDark
                ? BottomNavIconVariantSlot.darkSelected
                : BottomNavIconVariantSlot.lightSelected,
          ),
          'settings_normal.png': (
            BottomNavIconGalleryTab.mine,
            isDark
                ? BottomNavIconVariantSlot.darkUnselected
                : BottomNavIconVariantSlot.lightUnselected,
          ),
          'settings_selected.png': (
            BottomNavIconGalleryTab.mine,
            isDark
                ? BottomNavIconVariantSlot.darkSelected
                : BottomNavIconVariantSlot.lightSelected,
          ),
        };

    final assignments = <_BottomNavBundleImportAssignment>[];
    for (final entry in filenameMap.entries) {
      final bundlePath = 'navbar_pack/$normalizedId/${entry.key}';
      if (archive.findFile(bundlePath) == null) {
        continue;
      }
      assignments.add(
        _BottomNavBundleImportAssignment.bundle(
          tab: entry.value.$1,
          slot: entry.value.$2,
          format: BottomNavIconAssetFormat.png,
          bundlePath: bundlePath,
        ),
      );
    }
    return assignments;
  }

  BottomNavIconGalleryTab? _bottomNavTabFromName(String raw) {
    return switch (raw.trim()) {
      'home' => BottomNavIconGalleryTab.home,
      'bookshelf' => BottomNavIconGalleryTab.bookshelf,
      'discover' => BottomNavIconGalleryTab.discover,
      'stats' => BottomNavIconGalleryTab.stats,
      'mine' => BottomNavIconGalleryTab.mine,
      _ => null,
    };
  }

  BottomNavIconVariantSlot? _bottomNavSlotFromName(String raw) {
    return switch (raw.trim()) {
      'lightUnselected' => BottomNavIconVariantSlot.lightUnselected,
      'lightSelected' => BottomNavIconVariantSlot.lightSelected,
      'darkUnselected' => BottomNavIconVariantSlot.darkUnselected,
      'darkSelected' => BottomNavIconVariantSlot.darkSelected,
      _ => null,
    };
  }

  BottomNavIconAssetFormat? _bottomNavFormatFromName(String? raw) {
    return switch ((raw ?? '').trim()) {
      'svg' => BottomNavIconAssetFormat.svg,
      'png' => BottomNavIconAssetFormat.png,
      _ => null,
    };
  }

  List<int> _archiveFileBytes(ArchiveFile file) {
    return List<int>.from(file.content);
  }

  Set<String> _coverGalleryIdsForTheme(AppAdvancedTheme theme) {
    return <String>{
      ...[
            theme.coverGalleryId,
            theme.coverGalleryIdFor(AppAdvancedThemeMode.light),
            theme.coverGalleryIdFor(AppAdvancedThemeMode.dark),
          ]
          .whereType<String>()
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty),
    };
  }

  bool _isAppearanceBackgroundReferenced(
    List<AppAdvancedTheme> themes,
    String targetPath,
  ) {
    final normalizedTarget = targetPath.trim();
    if (normalizedTarget.isEmpty) {
      return false;
    }
    for (final theme in themes) {
      final paths = <String?>[
        theme.lightConfig.wallpaperPath,
        theme.darkConfig.wallpaperPath,
      ];
      for (final path in paths) {
        if ((path?.trim() ?? '') == normalizedTarget) {
          return true;
        }
      }
    }
    return false;
  }

  bool _isReaderBackgroundReferenced(
    List<AppAdvancedTheme> themes,
    String targetPath,
  ) {
    final normalizedTarget = targetPath.trim();
    if (normalizedTarget.isEmpty) {
      return false;
    }
    for (final theme in themes) {
      final paths = <String?>[
        theme.lightConfig.readerWallpaperPath,
        theme.darkConfig.readerWallpaperPath,
      ];
      for (final path in paths) {
        if ((path?.trim() ?? '') == normalizedTarget) {
          return true;
        }
      }
    }
    return false;
  }

  bool _isCoverGalleryReferenced(
    List<AppAdvancedTheme> themes,
    String galleryId,
  ) {
    final normalizedId = galleryId.trim();
    if (normalizedId.isEmpty) {
      return false;
    }
    for (final theme in themes) {
      if (_coverGalleryIdsForTheme(theme).contains(normalizedId)) {
        return true;
      }
    }
    return false;
  }

  bool _isLaunchGalleryReferenced(
    List<AppAdvancedTheme> themes,
    String galleryId,
  ) {
    final normalizedId = galleryId.trim();
    if (normalizedId.isEmpty) {
      return false;
    }
    for (final theme in themes) {
      if ((theme.launchImageGalleryId?.trim() ?? '') == normalizedId) {
        return true;
      }
    }
    return false;
  }

  bool _isBottomNavGalleryReferenced(
    List<AppAdvancedTheme> themes,
    String galleryId,
  ) {
    final normalizedId = galleryId.trim();
    if (normalizedId.isEmpty) {
      return false;
    }
    for (final theme in themes) {
      if ((theme.bottomNavGalleryId?.trim() ?? '') == normalizedId) {
        return true;
      }
    }
    return false;
  }

  Future<void> _cleanupImportedThemeBundleArtifacts({
    required Directory themeDirectory,
    List<String?> coverGalleryIds = const <String?>[],
    String? launchImageGalleryId,
    String? bottomNavGalleryId,
    List<String> importedFontFamilyKeys = const <String>[],
    List<String> sharedBackgroundPaths = const <String>[],
    List<String> sharedReaderBackgroundPaths = const <String>[],
  }) async {
    for (final path in sharedBackgroundPaths) {
      await _safeDeleteAppearanceBackground(path);
    }
    for (final path in sharedReaderBackgroundPaths) {
      await _safeDeleteReaderBackground(path);
    }
    for (final galleryId
        in coverGalleryIds.map((item) => item?.trim() ?? '').toSet()) {
      if (galleryId.isEmpty) {
        continue;
      }
      await _safeDeleteCoverGallery(galleryId);
    }
    await _safeDeleteLaunchGallery(launchImageGalleryId);
    await _safeDeleteBottomNavGallery(bottomNavGalleryId);
    await _safeDeleteImportedFonts(importedFontFamilyKeys);
    if (await themeDirectory.exists()) {
      await themeDirectory.delete(recursive: true);
    }
  }

  Future<void> _safeDeleteCoverGallery(String? galleryId) async {
    final normalized = galleryId?.trim() ?? '';
    if (normalized.isEmpty) {
      return;
    }
    try {
      await CoverGalleryService(
        preferences: await _preferencesFuture,
      ).deleteGallery(normalized);
    } catch (_) {
      // Ignore rollback failures.
    }
  }

  Future<void> _safeDeleteLaunchGallery(String? galleryId) async {
    final normalized = galleryId?.trim() ?? '';
    if (normalized.isEmpty) {
      return;
    }
    try {
      await LaunchImageGalleryService(
        preferences: await _preferencesFuture,
      ).deleteGallery(normalized);
    } catch (_) {
      // Ignore rollback failures.
    }
  }

  Future<void> _safeDeleteBottomNavGallery(String? galleryId) async {
    final normalized = galleryId?.trim() ?? '';
    if (normalized.isEmpty) {
      return;
    }
    try {
      await BottomNavIconGalleryService(
        preferences: await _preferencesFuture,
      ).deleteGallery(normalized);
    } catch (_) {
      // Ignore rollback failures.
    }
  }

  Future<void> _safeDeleteImportedFonts(List<String> familyKeys) async {
    if (familyKeys.isEmpty) {
      return;
    }
    final service = ReaderFontRegistryService();
    for (final familyKey in familyKeys) {
      final normalized = familyKey.trim();
      if (normalized.isEmpty) {
        continue;
      }
      try {
        await service.removeFont(normalized);
      } catch (_) {
        // Ignore rollback failures.
      }
    }
  }

  Future<String> _importAppearanceBackgroundFromFile(
    String sourcePath, {
    required String fileName,
  }) async {
    final sourceFile = File(sourcePath);
    final bytes = await sourceFile.readAsBytes();
    final extension = _normalizeSharedImageExtension(bytes, fileName);
    final asset = await _assetStore.persistBytes(
      type: ManagedAssetType.appBackground,
      scope: ManagedAssetScope.themeBinding,
      bytes: bytes,
      fileName: 'theme_bg.$extension',
      targetNamePrefix: 'theme_bg',
    );
    final targetPath = asset.resolvedPath!;
    await evictFileImagePath(targetPath);
    return targetPath;
  }

  Future<void> _safeDeleteAppearanceBackground(String path) async {
    final normalized = path.trim();
    if (normalized.isEmpty) {
      return;
    }
    try {
      await evictFileImagePath(normalized);
      await _assetStore.deletePath(normalized);
    } catch (_) {
      // Ignore rollback failures.
    }
  }

  Future<void> _safeDeleteReaderBackground(String path) async {
    final normalized = path.trim();
    if (normalized.isEmpty) {
      return;
    }
    try {
      await ReaderBackgroundService().deleteBackground(normalized);
    } catch (_) {
      // Ignore rollback failures.
    }
  }

  String _normalizeSharedImageExtension(List<int> bytes, String fileName) {
    final detected = _detectImageExtension(bytes);
    if (detected != null) {
      return detected;
    }
    final normalized = _normalizeFileExtension(fileName);
    return switch (normalized) {
      'img' => 'png',
      _ => normalized,
    };
  }

  String? _detectImageExtension(List<int> bytes) {
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'webp';
    }
    if (bytes.length >= 4 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'png';
    }
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return 'jpg';
    }
    if (bytes.length >= 6 &&
        bytes[0] == 0x47 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x38 &&
        (bytes[4] == 0x37 || bytes[4] == 0x39) &&
        bytes[5] == 0x61) {
      return 'gif';
    }
    return null;
  }
}

class _BottomNavBundleImportAssignment {
  const _BottomNavBundleImportAssignment.asset({
    required this.tab,
    required this.slot,
    required BottomNavIconAssetRef this.assetRef,
  }) : bundlePath = null,
       format = null;

  const _BottomNavBundleImportAssignment.bundle({
    required this.tab,
    required this.slot,
    required this.bundlePath,
    required this.format,
  }) : assetRef = null;

  final BottomNavIconGalleryTab tab;
  final BottomNavIconVariantSlot slot;
  final BottomNavIconAssetRef? assetRef;
  final String? bundlePath;
  final BottomNavIconAssetFormat? format;
}

class _ImportedThemeFonts {
  const _ImportedThemeFonts({
    this.hasManifest = false,
    this.appInterfaceFontFamilyKey,
    this.readerFontFamilyKey,
    this.importedFamilyKeys = const <String>[],
  });

  final bool hasManifest;
  final String? appInterfaceFontFamilyKey;
  final String? readerFontFamilyKey;
  final List<String> importedFamilyKeys;
}

class _RedReaderSchemaImport {
  const _RedReaderSchemaImport({
    required this.backgroundPath,
    required this.opacity,
    required this.blurSigma,
    required this.fit,
    required this.overlayOpacity,
  });

  final String? backgroundPath;
  final double opacity;
  final double blurSigma;
  final AppAdvancedThemeWallpaperFit fit;
  final double overlayOpacity;
}

class _RedArchiveImageEntry {
  const _RedArchiveImageEntry(this.path);

  final String path;
}

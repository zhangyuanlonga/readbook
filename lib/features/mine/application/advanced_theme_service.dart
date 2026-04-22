import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../app/navigation/bottom_nav_icon_gallery_service.dart';
import '../../../app/images/file_image_cache.dart';
import '../../../domain/entities/app_advanced_theme.dart';
import '../../../domain/entities/bottom_nav_icon_gallery.dart';
import 'cover_gallery_service.dart';
import 'launch_image_gallery_service.dart';

class AdvancedThemeService {
  static const String _activeThemeIdKey = 'app.advancedThemes.activeId';
  static const String _colorExportType = 'advanced_theme_colors';
  static const int _colorExportVersion = 1;
  static const String _bundleExportType = 'advanced_theme_bundle';
  static const int _bundleExportVersion = 1;

  AdvancedThemeService({SharedPreferences? preferences})
    : _preferencesFuture =
          preferences == null
              ? SharedPreferences.getInstance()
              : Future.value(preferences);

  final Future<SharedPreferences> _preferencesFuture;

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
      themes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return themes;
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
    await prefs.setString(
      _themesKey,
      jsonEncode(themes.map((item) => item.toJson()).toList(growable: false)),
    );
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

  Future<void> deleteTheme(String themeId) async {
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
    if (removedTheme != null) {
      final targetTheme = removedTheme!;
      final paths = <String>{
        ...[
              targetTheme.lightConfig.wallpaperPath,
              targetTheme.darkConfig.wallpaperPath,
            ]
            .whereType<String>()
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty),
      };
      for (final path in paths) {
        await deleteWallpaper(path);
      }
    }
    final directory = await _themeDirectory(themeId);
    if (await directory.exists()) {
      await directory.delete(recursive: true);
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
      targetThemeId: cloneId,
      mode: AppAdvancedThemeMode.light,
      sourcePath: source.lightConfig.wallpaperPath,
    );
    final darkWallpaperPath = await _duplicateWallpaper(
      targetThemeId: cloneId,
      mode: AppAdvancedThemeMode.dark,
      sourcePath: source.darkConfig.wallpaperPath,
    );
    final clone = source.copyWith(
      id: cloneId,
      name: cloneName,
      createdAt: now,
      updatedAt: now,
      lightConfig: source.lightConfig.copyWith(
        wallpaperPath: lightWallpaperPath,
        clearWallpaperPath: lightWallpaperPath == null,
        readerWallpaperPath: source.lightConfig.readerWallpaperPath,
      ),
      darkConfig: source.darkConfig.copyWith(
        wallpaperPath: darkWallpaperPath,
        clearWallpaperPath: darkWallpaperPath == null,
        readerWallpaperPath: source.darkConfig.readerWallpaperPath,
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
      'lightColors': theme.lightConfig.colors.toJson(),
      'darkColors': theme.darkConfig.colors.toJson(),
    });
  }

  Future<AppAdvancedTheme> importThemeColorJson(String rawJson) async {
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
    if (normalizedVersion != _colorExportVersion) {
      throw const FormatException('Unsupported theme JSON version.');
    }

    final rawName = payload['name']?.toString().trim() ?? '';
    final now = DateTime.now().toUtc();
    final lightColors = _readExportedColors(payload, 'lightColors');
    final darkColors = _readExportedColors(payload, 'darkColors');

    final importedTheme = AppAdvancedTheme(
      id: createThemeId(),
      name: rawName.isEmpty ? '导入主题' : rawName,
      createdAt: now,
      updatedAt: now,
      lightConfig: AppAdvancedThemeModeConfig(colors: lightColors),
      darkConfig: AppAdvancedThemeModeConfig(colors: darkColors),
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
    final coverGallery = await coverService.loadGallery(
      theme.coverGalleryId ?? '',
    );
    final coverManifest = await _appendImageGalleryToArchive(
      archive,
      folder: 'cover_gallery',
      imagePaths: coverGallery?.imagePaths ?? const <String>[],
      name: coverGallery?.name,
    );
    if (coverManifest != null) {
      manifest['coverGallery'] = coverManifest;
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

    final manifestBytes = utf8.encode(
      const JsonEncoder.withIndent('  ').convert(manifest),
    );
    archive.addFile(
      ArchiveFile('manifest.json', manifestBytes.length, manifestBytes),
    );
    return ZipEncoder().encode(archive);
  }

  Future<AppAdvancedTheme> importThemeBundleZipBytes(List<int> bytes) async {
    final archive = ZipDecoder().decodeBytes(bytes, verify: true);
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
    final lightReaderWallpaperPath = await _extractArchiveFileToThemeDirectory(
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

    final coverGalleryId = await _importImageGalleryFromBundle(
      archive,
      manifest['coverGallery'],
      isLaunchGallery: false,
    );
    final launchImageGalleryId = await _importImageGalleryFromBundle(
      archive,
      manifest['launchImageGallery'],
      isLaunchGallery: true,
    );
    final bottomNavGalleryId = await _importBottomNavGalleryFromBundle(
      archive,
      manifest['bottomNavGallery'],
    );

    final theme = importedTheme.copyWith(
      id: themeId,
      name: importedTheme.name,
      createdAt: now,
      updatedAt: now,
      lightConfig: importedTheme.lightConfig.copyWith(
        wallpaperPath: lightWallpaperPath,
        clearWallpaperPath: lightWallpaperPath == null,
        readerWallpaperPath: lightReaderWallpaperPath,
        clearReaderWallpaperPath: lightReaderWallpaperPath == null,
      ),
      darkConfig: importedTheme.darkConfig.copyWith(
        wallpaperPath: darkWallpaperPath,
        clearWallpaperPath: darkWallpaperPath == null,
        readerWallpaperPath: darkReaderWallpaperPath,
        clearReaderWallpaperPath: darkReaderWallpaperPath == null,
      ),
      coverGalleryId: coverGalleryId,
      clearCoverGalleryId: coverGalleryId == null,
      launchImageGalleryId: launchImageGalleryId,
      clearLaunchImageGalleryId: launchImageGalleryId == null,
      bottomNavGalleryId: bottomNavGalleryId,
      clearBottomNavGalleryId: bottomNavGalleryId == null,
    );
    return saveTheme(theme);
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
    final file = File(normalized);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<Directory> _themeDirectory(String themeId) async {
    final documents = await getApplicationDocumentsDirectory();
    return Directory(p.join(documents.path, 'advanced_themes', themeId));
  }

  Future<String?> _duplicateWallpaper({
    required String targetThemeId,
    required AppAdvancedThemeMode mode,
    required String? sourcePath,
  }) async {
    final normalized = sourcePath?.trim() ?? '';
    if (normalized.isEmpty) {
      return null;
    }
    final sourceFile = File(normalized);
    if (!await sourceFile.exists()) {
      return null;
    }
    final targetDirectory = await _themeDirectory(targetThemeId);
    if (!await targetDirectory.exists()) {
      await targetDirectory.create(recursive: true);
    }
    final sourceExtension = p.extension(sourceFile.path);
    final targetPath = p.join(
      targetDirectory.path,
      'wallpaper_${mode.name}${sourceExtension.isEmpty ? '.png' : sourceExtension}',
    );
    await sourceFile.copy(targetPath);
    return targetPath;
  }

  String _normalizeFileExtension(String fileName) {
    final extension = p.extension(fileName).replaceFirst('.', '').trim();
    if (extension.isEmpty) {
      return 'png';
    }
    return extension.toLowerCase();
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

    if (isLaunchGallery) {
      final service = LaunchImageGalleryService(
        preferences: await _preferencesFuture,
      );
      final gallery = await service.createGallery(name: name);
      for (final rawPath in images) {
        final bundlePath = rawPath.toString().trim();
        final file = archive.findFile(bundlePath);
        if (file == null) {
          continue;
        }
        await service.importImage(
          galleryId: gallery.id,
          bytes: _archiveFileBytes(file),
          fileName: p.basename(bundlePath),
        );
      }
      return gallery.id;
    }

    final service = CoverGalleryService(preferences: await _preferencesFuture);
    final gallery = await service.createGallery(name: name);
    for (final rawPath in images) {
      final bundlePath = rawPath.toString().trim();
      final file = archive.findFile(bundlePath);
      if (file == null) {
        continue;
      }
      await service.importImage(
        galleryId: gallery.id,
        bytes: _archiveFileBytes(file),
        fileName: p.basename(bundlePath),
      );
    }
    return gallery.id;
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
      for (final tabEntry in items.entries) {
        final tab = _bottomNavTabFromName(tabEntry.key.toString());
        if (tab == null || tabEntry.value is! Map) {
          continue;
        }
        var iconSet = nextItems[tab] ?? const BottomNavIconSet();
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
          final format = _bottomNavFormatFromName(
            assetMap['format']?.toString(),
          );
          if (format == null) {
            continue;
          }
          if (isAsset) {
            final path = assetMap['path']?.toString().trim() ?? '';
            if (path.isEmpty) {
              continue;
            }
            iconSet = iconSet.copyWithSlot(
              slot,
              asset: BottomNavIconAssetRef(
                path: path,
                format: format,
                isAsset: true,
              ),
            );
            continue;
          }
          final bundlePath = assetMap['bundlePath']?.toString().trim() ?? '';
          final archiveFile = archive.findFile(bundlePath);
          if (archiveFile == null) {
            continue;
          }
          final tempPath = p.join(tempDirectory.path, p.basename(bundlePath));
          await File(
            tempPath,
          ).writeAsBytes(_archiveFileBytes(archiveFile), flush: true);
          final importedAsset = await service.importIconAsset(
            galleryId: gallery.id,
            tab: tab,
            slot: slot,
            sourcePath: tempPath,
            format: format,
          );
          iconSet = iconSet.copyWithSlot(slot, asset: importedAsset);
        }
        nextItems[tab] = iconSet;
      }
      gallery = await service.saveGallery(gallery.copyWith(items: nextItems));
      return gallery.id;
    } finally {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    }
  }

  BottomNavIconGalleryTab? _bottomNavTabFromName(String raw) {
    return switch (raw.trim()) {
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
}

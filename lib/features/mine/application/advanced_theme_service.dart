import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../domain/entities/app_advanced_theme.dart';

class AdvancedThemeService {
  static const String _activeThemeIdKey = 'app.advancedThemes.activeId';

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
      ),
      darkConfig: source.darkConfig.copyWith(
        wallpaperPath: darkWallpaperPath,
        clearWallpaperPath: darkWallpaperPath == null,
      ),
    );
    return saveTheme(clone);
  }

  String createThemeId() {
    return 'advanced_theme_${_uuid.v4()}';
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
    await target.writeAsBytes(bytes, flush: true);
    return target.path;
  }

  Future<void> deleteWallpaper(String path) async {
    final normalized = path.trim();
    if (normalized.isEmpty) {
      return;
    }
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
}

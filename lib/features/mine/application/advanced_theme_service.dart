import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
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
import 'active_theme_appearance_snapshot.dart';
import 'advanced_theme_resource_reference_service.dart';
import 'cover_gallery_service.dart';
import 'launch_image_gallery_service.dart';
import '../../reader/application/reader_font_registry_service.dart';
import 'reader_background_service.dart';

/// 高级主题导入任务的业务阶段。
///
/// 该状态只描述 application 层正在处理的文件策略阶段，页面层可以把它映射成
/// 列表项图标、进度文案或任务中心状态。不要把页面动画、弹窗状态塞进这里，
/// 避免服务层反向依赖 presentation。
enum AdvancedThemeImportProgressStage { reading, parsing, importing }

/// 批量主题导入结果。
///
/// `successCount` 统计实际写入主题库的主题数量，`failureCount` 统计批量包中
/// 单个条目失败的数量。只要至少成功导入一个主题，批量导入就允许返回结果；
/// 如果全部失败，服务会抛出 `FormatException`，让调用方按导入失败处理。
class AdvancedThemeBatchImportSummary {
  const AdvancedThemeBatchImportSummary({
    required this.successCount,
    required this.failureCount,
    this.lastError,
  });

  final int successCount;
  final int failureCount;
  final String? lastError;

  bool get hasSuccess => successCount > 0;
}

typedef AdvancedThemeBatchImportProgressCallback =
    void Function(AdvancedThemeImportProgressStage stage, String message);

typedef AdvancedThemeBatchExportProgressCallback =
    void Function(String message);

enum _AdvancedThemeImportPackageKind { official, red, rgshare }

class AdvancedThemeService {
  static const String _activeThemeIdKey = 'app.advancedThemes.activeId';
  static const String _activeThemeAppearanceSnapshotKey =
      'app.advancedThemes.activeAppearanceSnapshot';
  static const String _colorExportType = 'advanced_theme_colors';
  static const int _legacyColorExportVersion = 1;
  static const int _colorExportVersion = 2;
  static const String _bundleExportType = 'advanced_theme_bundle';
  static const int _bundleExportVersion = 1;
  static const String _batchBundleType = 'advanced_theme_batch_bundle';
  static const int _batchBundleVersion = 1;

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
  String? _cachedThemesRaw;
  List<AppAdvancedTheme>? _cachedThemes;
  List<AdvancedThemeSummary>? _cachedThemeSummaries;
  String? _cachedHydratedThemeSummariesRaw;
  List<AdvancedThemeSummary>? _cachedHydratedThemeSummaries;
  final Map<String, String?> _previewWallpaperPathCache = <String, String?>{};

  static const Uuid _uuid = Uuid();
  static const String _themesKey = 'app.advancedThemes';
  static const String _themeIndexFileName = 'index.json';

  static String? readActiveThemeId(SharedPreferences prefs) {
    final raw = prefs.getString(_activeThemeIdKey)?.trim();
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return raw;
  }

  static ActiveThemeAppearanceSnapshot? readActiveThemeAppearanceSnapshot(
    SharedPreferences prefs,
  ) {
    final raw = prefs.getString(_activeThemeAppearanceSnapshotKey)?.trim();
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      return ActiveThemeAppearanceSnapshot.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<List<AppAdvancedTheme>> loadThemes() async {
    final raw = await _loadPersistedThemesRaw();
    if (raw == null || raw.trim().isEmpty) {
      _cachedThemesRaw = null;
      _cachedThemes = const <AppAdvancedTheme>[];
      _cachedThemeSummaries = const <AdvancedThemeSummary>[];
      _cachedHydratedThemeSummariesRaw = null;
      _cachedHydratedThemeSummaries = const <AdvancedThemeSummary>[];
      _previewWallpaperPathCache.clear();
      return const <AppAdvancedTheme>[];
    }
    if (_cachedThemesRaw == raw && _cachedThemes != null) {
      return _cachedThemes!;
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
      _cachedThemesRaw = changed ? null : raw;
      _cachedThemes = List<AppAdvancedTheme>.unmodifiable(normalizedThemes);
      _cachedThemeSummaries = null;
      _cachedHydratedThemeSummariesRaw = null;
      _cachedHydratedThemeSummaries = null;
      _previewWallpaperPathCache.clear();
      return normalizedThemes;
    } catch (_) {
      return const <AppAdvancedTheme>[];
    }
  }

  Future<List<AdvancedThemeSummary>> loadThemeSummaries() async {
    final raw = await _loadPersistedThemesRaw();
    if (raw == null || raw.trim().isEmpty) {
      _cachedThemesRaw = null;
      _cachedThemeSummaries = const <AdvancedThemeSummary>[];
      _cachedHydratedThemeSummariesRaw = null;
      _cachedHydratedThemeSummaries = const <AdvancedThemeSummary>[];
      _previewWallpaperPathCache.clear();
      return const <AdvancedThemeSummary>[];
    }
    if (_cachedThemesRaw == raw && _cachedThemeSummaries != null) {
      return _cachedThemeSummaries!;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <AdvancedThemeSummary>[];
      }
      final summaries = decoded
          .whereType<Map>()
          .map(
            (item) => AdvancedThemeSummary.fromTheme(
              AppAdvancedTheme.fromJson(
                item.map((key, value) => MapEntry(key.toString(), value)),
              ),
            ),
          )
          .toList(growable: false);
      summaries.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      _cachedThemesRaw = raw;
      _cachedThemeSummaries = List<AdvancedThemeSummary>.unmodifiable(
        summaries,
      );
      _cachedHydratedThemeSummariesRaw = null;
      _cachedHydratedThemeSummaries = null;
      return summaries;
    } catch (_) {
      return const <AdvancedThemeSummary>[];
    }
  }

  Future<void> saveThemes(List<AppAdvancedTheme> themes) async {
    final prefs = await _preferencesFuture;
    if (themes.isEmpty) {
      await _deleteThemeIndexFile();
      await prefs.remove(_themesKey);
      _cachedThemesRaw = null;
      _cachedThemes = const <AppAdvancedTheme>[];
      _cachedThemeSummaries = const <AdvancedThemeSummary>[];
      _cachedHydratedThemeSummariesRaw = null;
      _cachedHydratedThemeSummaries = const <AdvancedThemeSummary>[];
      _previewWallpaperPathCache.clear();
      return;
    }
    final persistedThemes = <Map<String, dynamic>>[];
    for (final theme in themes) {
      persistedThemes.add(
        (await _normalizeThemeForPersistence(theme)).toJson(),
      );
    }
    final encoded = jsonEncode(persistedThemes);
    await _writeThemeIndexFile(encoded);
    await prefs.remove(_themesKey);
    final cachedThemes = List<AppAdvancedTheme>.from(themes)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    _cachedThemesRaw = encoded;
    _cachedThemes = List<AppAdvancedTheme>.unmodifiable(cachedThemes);
    _cachedThemeSummaries = null;
    _cachedHydratedThemeSummariesRaw = null;
    _cachedHydratedThemeSummaries = null;
    _previewWallpaperPathCache.clear();
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
      await saveActiveThemeAppearanceSnapshot(null);
      await LaunchImageGalleryService(
        preferences: prefs,
        assetStore: _assetStore,
      ).syncStartupSnapshotFromCurrentConfig();
      return;
    }
    await prefs.setString(_activeThemeIdKey, normalized);
    final theme = await loadThemeById(normalized);
    await saveActiveThemeAppearanceSnapshot(
      theme == null ? null : ActiveThemeAppearanceSnapshot.fromTheme(theme),
    );
    await LaunchImageGalleryService(
      preferences: prefs,
      assetStore: _assetStore,
    ).syncStartupSnapshotFromCurrentConfig();
  }

  Future<AppAdvancedTheme?> loadActiveTheme() async {
    final activeId = await loadActiveThemeId();
    if (activeId == null) {
      return null;
    }
    return loadThemeById(activeId);
  }

  Future<AppAdvancedTheme?> loadThemeById(String themeId) async {
    final normalizedThemeId = themeId.trim();
    if (normalizedThemeId.isEmpty) {
      return null;
    }
    final themes = await loadThemes();
    for (final theme in themes) {
      if (theme.id == normalizedThemeId) {
        return theme;
      }
    }
    return null;
  }

  Future<ActiveThemeAppearanceSnapshot?>
  loadActiveThemeAppearanceSnapshot() async {
    final prefs = await _preferencesFuture;
    return readActiveThemeAppearanceSnapshot(prefs);
  }

  Future<void> saveActiveThemeAppearanceSnapshot(
    ActiveThemeAppearanceSnapshot? snapshot,
  ) async {
    final prefs = await _preferencesFuture;
    if (snapshot == null) {
      await prefs.remove(_activeThemeAppearanceSnapshotKey);
      return;
    }
    await prefs.setString(
      _activeThemeAppearanceSnapshotKey,
      jsonEncode(snapshot.toJson()),
    );
  }

  Future<List<AdvancedThemeSummary>> hydrateThemeSummaryPreviewPaths(
    List<AdvancedThemeSummary> summaries,
  ) async {
    if (summaries.isEmpty) {
      return const <AdvancedThemeSummary>[];
    }
    final raw = await _loadPersistedThemesRaw();
    if (raw == null || raw.trim().isEmpty) {
      return summaries;
    }
    if (_cachedHydratedThemeSummariesRaw == raw &&
        _cachedHydratedThemeSummaries != null) {
      return _cachedHydratedThemeSummaries!;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return summaries;
      }
      final previewPathCache = <String, String?>{..._previewWallpaperPathCache};
      final hydratedById = <String, AdvancedThemeSummary>{};
      for (final item in decoded.whereType<Map>()) {
        final theme = AppAdvancedTheme.fromJson(
          item.map((key, value) => MapEntry(key.toString(), value)),
        );
        hydratedById[theme.id] = await _buildThemeSummary(
          theme,
          previewPathCache: previewPathCache,
        );
      }
      _previewWallpaperPathCache
        ..clear()
        ..addAll(previewPathCache);
      final hydrated = summaries
          .map((summary) => hydratedById[summary.id] ?? summary)
          .toList(growable: false);
      _cachedHydratedThemeSummariesRaw = raw;
      _cachedHydratedThemeSummaries = List<AdvancedThemeSummary>.unmodifiable(
        hydrated,
      );
      return hydrated;
    } catch (_) {
      return summaries;
    }
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
    final activeThemeId = await loadActiveThemeId();
    if (activeThemeId == normalized.id) {
      await saveActiveThemeAppearanceSnapshot(
        ActiveThemeAppearanceSnapshot.fromTheme(normalized),
      );
      await LaunchImageGalleryService(
        preferences: await _preferencesFuture,
        assetStore: _assetStore,
      ).syncStartupSnapshotFromCurrentConfig();
    }
    return normalized;
  }

  Future<void> deleteTheme(
    String themeId, {
    bool deleteAssociatedResources = true,
    AdvancedThemeDeleteOptions? deleteOptions,
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
    final resolvedDeleteOptions =
        deleteOptions ??
        (deleteAssociatedResources
            ? const AdvancedThemeDeleteOptions()
            : const AdvancedThemeDeleteOptions.none());
    if (removedTheme != null &&
        resolvedDeleteOptions.deleteAnyAssociatedResources) {
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
      final fontFamilyKeys = <String>{
        ...[
              targetTheme.appInterfaceFontFamilyKey,
              targetTheme.readerFontFamilyKey,
            ]
            .whereType<String>()
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty),
      };

      if (resolvedDeleteOptions.deleteAppearanceWallpapers) {
        for (final path in appearancePaths) {
          if (!_isAppearanceBackgroundReferenced(updated, path)) {
            await deleteWallpaper(path);
          }
        }
      }
      if (resolvedDeleteOptions.deleteReaderWallpapers) {
        for (final path in readerPaths) {
          if (!_isReaderBackgroundReferenced(updated, path)) {
            await deleteReaderWallpaper(path);
          }
        }
      }
      if (resolvedDeleteOptions.deleteCoverGalleries) {
        for (final galleryId in coverGalleryIds) {
          if (!_isCoverGalleryReferenced(updated, galleryId)) {
            await _safeDeleteCoverGallery(galleryId);
          }
        }
      }
      if (resolvedDeleteOptions.deleteLaunchImageGallery &&
          launchGalleryId != null &&
          launchGalleryId.isNotEmpty &&
          !_isLaunchGalleryReferenced(updated, launchGalleryId)) {
        await _safeDeleteLaunchGallery(launchGalleryId);
      }
      if (resolvedDeleteOptions.deleteBottomNavGallery &&
          bottomNavGalleryId != null &&
          bottomNavGalleryId.isNotEmpty &&
          !_isBottomNavGalleryReferenced(updated, bottomNavGalleryId)) {
        await _safeDeleteBottomNavGallery(bottomNavGalleryId);
      }
      if (resolvedDeleteOptions.deleteFonts) {
        final removableFontKeys = await AdvancedThemeResourceReferenceService(
          preferences: await _preferencesFuture,
        ).filterRemovableFontFamilyKeys(
          fontFamilyKeys: fontFamilyKeys,
          remainingThemes: updated,
        );
        await _safeDeleteImportedFonts(removableFontKeys);
      }
      if (resolvedDeleteOptions.deleteAppearanceWallpapers) {
        final directory = await _themeDirectory(themeId);
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
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

  /// 生成单个主题 ZIP 导出的稳定文件名。
  ///
  /// 文件名规则集中在服务层，保证桌面保存、移动端分享和后续批量包内嵌文件
  /// 使用同一套非法字符替换策略，避免页面各自拼接导致跨平台文件名差异。
  String themeBundleExportFileName(AppAdvancedTheme theme) {
    return '${_normalizedExportFileName(theme.name)}.zip';
  }

  /// 生成批量主题 ZIP 导出的稳定文件名。
  ///
  /// `now` 仅供测试固定时间使用；生产调用默认使用当前时间。
  String themeBatchBundleExportFileName({DateTime? now}) {
    return 'advanced_themes_batch_${_formattedTimestampForFileName(now ?? DateTime.now())}.zip';
  }

  /// 将单个主题包写入指定文件。
  ///
  /// 调用方负责选择目标位置或分享策略；服务层只负责主题包编码和文件写入，
  /// 保证 ZIP 内容与 `importThemeBundleZipFile` 的兼容语义一致。
  Future<File> writeThemeBundleZipFile({
    required AppAdvancedTheme theme,
    required File outputFile,
  }) async {
    final bytes = await encodeThemeBundleZip(theme);
    await outputFile.writeAsBytes(bytes, flush: true);
    return outputFile;
  }

  /// 将单个主题包写入临时目录，供移动端分享等一次性分发流程使用。
  ///
  /// 临时目录只作为可删除中转，不承载用户资产；真正的主题资源导入仍由
  /// `importThemeBundleZipFile` / `importThemeBundleZipBytes` 落入托管资源目录。
  Future<File> writeThemeBundleZipToTemporaryFile(
    AppAdvancedTheme theme,
  ) async {
    final tempDir = await getTemporaryDirectory();
    final file = File(p.join(tempDir.path, themeBundleExportFileName(theme)));
    return writeThemeBundleZipFile(theme: theme, outputFile: file);
  }

  /// 判断一个 ZIP 是否为高级主题批量包。
  ///
  /// 该判断会读取 ZIP manifest，但不会导入主题、不会写用户资产。页面层只需要
  /// 拿到布尔结果决定任务文案；批量包协议细节统一保留在 application 层。
  bool isBatchThemeBundleFile({
    required String path,
    String? mimeType,
    List<int>? bytes,
  }) {
    if (!_isZipThemeFile(path: path, mimeType: mimeType, bytes: bytes)) {
      return false;
    }
    try {
      Archive archive;
      if (bytes == null) {
        final input = InputFileStream(path);
        try {
          archive = ZipDecoder().decodeStream(input, verify: false);
        } finally {
          input.close();
        }
      } else {
        archive = ZipDecoder().decodeBytes(bytes, verify: false);
      }
      final manifestFile = archive.findFile('manifest.json');
      if (manifestFile == null) {
        return false;
      }
      final decoded = jsonDecode(
        utf8.decode(_archiveFileBytes(manifestFile), allowMalformed: true),
      );
      if (decoded is! Map) {
        return false;
      }
      final manifest = decoded.map(
        (key, value) => MapEntry(key.toString(), value),
      );
      return manifest['type']?.toString().trim() == _batchBundleType;
    } catch (_) {
      return false;
    }
  }

  /// 导入单个主题文件，自动识别官方 ZIP、旧 JSON、Red 和 RGShare 包。
  ///
  /// 这个入口用于批量导入队列和外部文件导入，避免页面层重复嗅探文件头、
  /// 判断扩展名或读取 ZIP manifest。旧 payload、重复导入指纹和用户资产写入
  /// 仍复用现有各格式导入方法，保证行为等价。
  Future<AppAdvancedTheme> importThemeFile({
    required String path,
    String? mimeType,
  }) async {
    final packageKind = await _detectImportPackageKind(
      path: path,
      mimeType: mimeType,
    );
    if (packageKind == _AdvancedThemeImportPackageKind.official &&
        _isZipThemeFile(path: path, mimeType: mimeType)) {
      return importThemeBundleZipFile(path);
    }
    final bytes = await File(path).readAsBytes();
    return importThemeBytes(path: path, bytes: bytes, mimeType: mimeType);
  }

  /// 导入内存中的主题文件内容，自动识别官方 ZIP、旧 JSON、Red 和 RGShare 包。
  Future<AppAdvancedTheme> importThemeBytes({
    required String path,
    required List<int> bytes,
    String? mimeType,
  }) async {
    final packageKind = await _detectImportPackageKind(
      path: path,
      mimeType: mimeType,
      bytes: bytes,
    );
    return switch (packageKind) {
      _AdvancedThemeImportPackageKind.red => importRedThemePackageBytes(bytes),
      _AdvancedThemeImportPackageKind.rgshare => importRgShareThemePackageBytes(
        bytes,
      ),
      _AdvancedThemeImportPackageKind.official =>
        _isZipThemeFile(path: path, mimeType: mimeType, bytes: bytes)
            ? importThemeBundleZipBytes(bytes)
            : importThemeColorJson(utf8.decode(bytes, allowMalformed: true)),
    };
  }

  /// 导入一个队列文件；如果文件是批量包，会拆包后逐个导入内部主题 ZIP。
  ///
  /// 批量包拆包工作区只使用临时目录，并在 finally 中递归清理。这里不把批量包
  /// 解出的 ZIP 当作用户资产保存，避免系统临时目录和真实主题资源目录混淆。
  Future<AdvancedThemeBatchImportSummary> importThemeBatchFile({
    required String path,
    String? mimeType,
    AdvancedThemeBatchImportProgressCallback? onProgress,
  }) async {
    onProgress?.call(AdvancedThemeImportProgressStage.reading, '正在准备导入...');
    await _yieldToEventLoop();
    if (isBatchThemeBundleFile(path: path, mimeType: mimeType)) {
      onProgress?.call(AdvancedThemeImportProgressStage.parsing, '正在解析批量主题包');
      await _yieldToEventLoop();
      return _importThemeBatchBundleFile(path, onProgress: onProgress);
    }
    onProgress?.call(AdvancedThemeImportProgressStage.importing, '正在导入主题资源');
    await _yieldToEventLoop();
    await importThemeFile(path: path, mimeType: mimeType);
    return const AdvancedThemeBatchImportSummary(
      successCount: 1,
      failureCount: 0,
    );
  }

  /// 将多个主题摘要打包成批量主题包并写入指定文件。
  ///
  /// 批量包内部仍由 `encodeThemeBundleZip` 生成单个官方主题包，manifest 只记录
  /// 批量索引和内部 ZIP 路径。这样可以复用单主题导入兼容逻辑，也方便后续把
  /// 批量任务迁到队列或 isolate 时保持协议稳定。
  Future<File> writeThemeBatchBundleFile({
    required List<AdvancedThemeSummary> summaries,
    required File outputFile,
    AdvancedThemeBatchExportProgressCallback? onProgress,
  }) async {
    final manifestThemes = <Map<String, Object?>>[];
    final tempDir = await getTemporaryDirectory();
    final workingDirectory = Directory(
      p.join(
        tempDir.path,
        'advanced_theme_batch_work_${DateTime.now().microsecondsSinceEpoch}',
      ),
    );
    var index = 0;

    if (!await workingDirectory.exists()) {
      await workingDirectory.create(recursive: true);
    }

    final encoder = ZipFileEncoder();
    var encoderCreated = false;
    try {
      encoder.create(outputFile.path, level: ZipFileEncoder.gzip);
      encoderCreated = true;
      for (final summary in summaries) {
        final theme = await loadThemeById(summary.id);
        if (theme == null) {
          continue;
        }
        // 批量导出保持严格串行，避免一次构建多个主题 ZIP 导致内存峰值放大。
        index += 1;
        onProgress?.call('正在打包 ${theme.name} ($index/${summaries.length})');
        final normalizedName = _normalizedExportFileName(theme.name);
        final innerZipName =
            '${index.toString().padLeft(3, '0')}_$normalizedName.zip';
        final tempThemeFile = File(p.join(workingDirectory.path, innerZipName));
        final bundleBytes = await encodeThemeBundleZip(theme);
        await tempThemeFile.writeAsBytes(bundleBytes, flush: true);
        final bundlePath = 'themes/$innerZipName';
        await encoder.addFile(tempThemeFile, bundlePath);
        manifestThemes.add(<String, Object?>{
          'id': theme.id,
          'name': theme.name,
          'file': bundlePath,
        });
        if (await tempThemeFile.exists()) {
          await tempThemeFile.delete();
        }
        await _yieldToEventLoop();
      }

      if (manifestThemes.isEmpty) {
        throw const FormatException('没有可打包的主题内容。');
      }

      onProgress?.call('正在写入批量导出清单...');
      final manifestBytes = utf8.encode(
        const JsonEncoder.withIndent('  ').convert(<String, Object?>{
          'type': _batchBundleType,
          'version': _batchBundleVersion,
          'generatedAt': DateTime.now().toIso8601String(),
          'themes': manifestThemes,
        }),
      );
      encoder.addArchiveFile(
        ArchiveFile('manifest.json', manifestBytes.length, manifestBytes),
      );
      return outputFile;
    } finally {
      if (encoderCreated) {
        await encoder.close();
      }
      if (await workingDirectory.exists()) {
        await workingDirectory.delete(recursive: true);
      }
    }
  }

  /// 将多个主题摘要打包到临时目录，供移动端分享等一次性分发流程使用。
  Future<File> writeThemeBatchBundleToTemporaryFile({
    required List<AdvancedThemeSummary> summaries,
    AdvancedThemeBatchExportProgressCallback? onProgress,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final file = File(p.join(tempDir.path, themeBatchBundleExportFileName()));
    return writeThemeBatchBundleFile(
      summaries: summaries,
      outputFile: file,
      onProgress: onProgress,
    );
  }

  Future<AdvancedThemeBatchImportSummary> _importThemeBatchBundleFile(
    String path, {
    AdvancedThemeBatchImportProgressCallback? onProgress,
  }) async {
    final input = InputFileStream(path);
    late final Archive archive;
    try {
      archive = ZipDecoder().decodeStream(input, verify: false);
    } finally {
      input.close();
    }
    final manifestFile = archive.findFile('manifest.json');
    if (manifestFile == null) {
      throw const FormatException('批量主题包缺少 manifest.json。');
    }
    final decoded = jsonDecode(
      utf8.decode(_archiveFileBytes(manifestFile), allowMalformed: true),
    );
    if (decoded is! Map) {
      throw const FormatException('批量主题包配置无效。');
    }
    final manifest = decoded.map(
      (key, value) => MapEntry(key.toString(), value),
    );
    final type = manifest['type']?.toString().trim() ?? '';
    if (type != _batchBundleType) {
      throw const FormatException('不支持的批量主题包类型。');
    }
    final version = manifest['version'];
    final normalizedVersion =
        version is num ? version.toInt() : int.tryParse('$version');
    if (normalizedVersion != _batchBundleVersion) {
      throw const FormatException('不支持的批量主题包版本。');
    }

    final entries = manifest['themes'];
    if (entries is! List || entries.isEmpty) {
      throw const FormatException('批量主题包中没有可导入的主题。');
    }

    var successCount = 0;
    var failureCount = 0;
    String? lastError;
    final tempDir = await getTemporaryDirectory();
    final workingDirectory = Directory(
      p.join(
        tempDir.path,
        'advanced_theme_batch_import_${DateTime.now().microsecondsSinceEpoch}',
      ),
    );
    if (!await workingDirectory.exists()) {
      await workingDirectory.create(recursive: true);
    }
    final importableEntries = entries.whereType<Map>().toList(growable: false);
    try {
      for (var index = 0; index < importableEntries.length; index += 1) {
        final item = importableEntries[index];
        final entry = item.map((key, value) => MapEntry(key.toString(), value));
        final bundlePath = entry['file']?.toString().trim() ?? '';
        if (bundlePath.isEmpty) {
          failureCount += 1;
          lastError = '批量主题包条目缺少文件路径。';
          continue;
        }
        final themeName = entry['name']?.toString().trim() ?? '';
        onProgress?.call(
          AdvancedThemeImportProgressStage.importing,
          themeName.isEmpty
              ? '正在导入主题 ${index + 1}/${importableEntries.length}'
              : '正在导入 $themeName ${index + 1}/${importableEntries.length}',
        );
        await _yieldToEventLoop();
        final archiveFile = archive.findFile(bundlePath);
        if (archiveFile == null) {
          failureCount += 1;
          lastError = '批量主题包缺少主题文件：$bundlePath';
          continue;
        }
        final tempThemeFile = File(
          p.join(
            workingDirectory.path,
            '${index.toString().padLeft(3, '0')}.zip',
          ),
        );
        try {
          final output = OutputFileStream(tempThemeFile.path);
          try {
            archiveFile.writeContent(output);
          } finally {
            output.close();
          }
          await importThemeFile(
            path: tempThemeFile.path,
            mimeType: 'application/zip',
          );
          successCount += 1;
        } catch (error) {
          failureCount += 1;
          lastError = _formatBatchImportItemError(error);
        } finally {
          if (await tempThemeFile.exists()) {
            await tempThemeFile.delete();
          }
        }
      }
    } finally {
      if (await workingDirectory.exists()) {
        await workingDirectory.delete(recursive: true);
      }
    }

    if (successCount == 0) {
      throw FormatException(lastError ?? '批量主题包中没有成功导入的主题。');
    }
    return AdvancedThemeBatchImportSummary(
      successCount: successCount,
      failureCount: failureCount,
      lastError: lastError,
    );
  }

  Future<_AdvancedThemeImportPackageKind> _detectImportPackageKind({
    required String path,
    String? mimeType,
    List<int>? bytes,
  }) async {
    final normalizedMime = mimeType?.trim().toLowerCase() ?? '';
    final normalizedExtension = p.extension(path).trim().toLowerCase();
    if (normalizedExtension == '.rgshare') {
      return _AdvancedThemeImportPackageKind.rgshare;
    }
    if (normalizedMime.contains('octet-stream') &&
        normalizedExtension == '.red') {
      return _AdvancedThemeImportPackageKind.red;
    }
    if (normalizedExtension == '.red') {
      return _AdvancedThemeImportPackageKind.red;
    }
    final resolvedBytes = bytes ?? await File(path).readAsBytes();
    final sniffedKind = _detectImportPackageKindFromBytes(resolvedBytes);
    if (sniffedKind != null) {
      return sniffedKind;
    }
    return _AdvancedThemeImportPackageKind.official;
  }

  _AdvancedThemeImportPackageKind? _detectImportPackageKindFromBytes(
    List<int> bytes,
  ) {
    if (_hasRedHeader(bytes)) {
      return _AdvancedThemeImportPackageKind.red;
    }
    if (!_looksLikeZip(bytes)) {
      return null;
    }

    try {
      final archive = ZipDecoder().decodeBytes(bytes, verify: false);
      if (archive.findFile('manifest.json') != null) {
        return _AdvancedThemeImportPackageKind.official;
      }
      final themeFile = archive.findFile('theme.json');
      if (themeFile == null) {
        return _AdvancedThemeImportPackageKind.official;
      }
      final decoded = jsonDecode(
        utf8.decode(_archiveFileBytes(themeFile), allowMalformed: true),
      );
      if (decoded is! Map) {
        return _AdvancedThemeImportPackageKind.official;
      }
      final payload = decoded.map(
        (key, value) => MapEntry(key.toString(), value),
      );
      if (_looksLikeRgShareTheme(payload)) {
        return _AdvancedThemeImportPackageKind.rgshare;
      }
      if (_looksLikeRedTheme(payload)) {
        return _AdvancedThemeImportPackageKind.red;
      }
    } catch (_) {
      return null;
    }
    return _AdvancedThemeImportPackageKind.official;
  }

  bool _looksLikeRgShareTheme(Map<String, dynamic> payload) {
    return payload.containsKey('1') &&
        payload.containsKey('2') &&
        payload.containsKey('4');
  }

  bool _looksLikeRedTheme(Map<String, dynamic> payload) {
    return payload['light'] is Map && payload['dark'] is Map;
  }

  bool _hasRedHeader(List<int> bytes) {
    return bytes.length >= 4 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x45 &&
        bytes[2] == 0x44;
  }

  bool _isZipThemeFile({
    required String path,
    String? mimeType,
    List<int>? bytes,
  }) {
    final normalizedMime = mimeType?.trim().toLowerCase() ?? '';
    if (normalizedMime.contains('zip')) {
      return true;
    }
    if (p.extension(path).trim().toLowerCase() == '.zip') {
      return true;
    }
    return bytes != null && _looksLikeZip(bytes);
  }

  String _normalizedExportFileName(String name) {
    final normalized = name.trim().replaceAll(RegExp(r'[\\/:*?"<>|]+'), '_');
    return normalized.isEmpty ? 'advanced_theme' : normalized;
  }

  String _formattedTimestampForFileName(DateTime value) {
    String twoDigits(int input) => input.toString().padLeft(2, '0');
    return '${value.year}${twoDigits(value.month)}${twoDigits(value.day)}_${twoDigits(value.hour)}${twoDigits(value.minute)}${twoDigits(value.second)}';
  }

  Future<void> _yieldToEventLoop() {
    return Future<void>.delayed(const Duration(milliseconds: 16));
  }

  String _formatBatchImportItemError(Object error) {
    if (error is FormatException && error.message.trim().isNotEmpty) {
      return error.message.trim();
    }
    final normalized = error.toString().trim();
    if (normalized.startsWith('Exception: ')) {
      return normalized.substring('Exception: '.length).trim();
    }
    if (normalized.startsWith('Error: ')) {
      return normalized.substring('Error: '.length).trim();
    }
    return normalized.isEmpty ? '主题导入失败。' : normalized;
  }

  Future<AppAdvancedTheme> importThemeColorJson(String rawJson) async {
    final fingerprint = _computeImportFingerprint(utf8.encode(rawJson));
    await _ensureImportFingerprintAvailable(fingerprint);
    final decoded = jsonDecode(rawJson);
    if (decoded is! Map) {
      throw const FormatException('旧 JSON 主题配置无效。');
    }
    final payload = decoded.map(
      (key, value) => MapEntry(key.toString(), value),
    );
    final type = payload['type']?.toString().trim() ?? '';
    if (type != _colorExportType) {
      throw const FormatException('不支持的旧 JSON 主题类型。');
    }
    final version = payload['version'];
    final normalizedVersion =
        version is num ? version.toInt() : int.tryParse('$version');
    if (normalizedVersion != _legacyColorExportVersion &&
        normalizedVersion != _colorExportVersion) {
      throw const FormatException('不支持的旧 JSON 主题版本。');
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
      name: rawName.isEmpty ? '导入旧主题' : rawName,
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
    return _importThemeBundleArchive(archive, importFingerprint: fingerprint);
  }

  Future<AppAdvancedTheme> importThemeBundleZipFile(String path) async {
    final file = File(path);
    final fingerprint = await _computeImportFingerprintForFile(file);
    await _ensureImportFingerprintAvailable(fingerprint);
    final archive = _decodeZipArchiveFile(file.path);
    return _importThemeBundleArchive(archive, importFingerprint: fingerprint);
  }

  Future<AppAdvancedTheme> _importThemeBundleArchive(
    Archive archive, {
    required String importFingerprint,
  }) async {
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
      if (launchImageGalleryId == null &&
          importedTheme.launchImageGalleryId?.trim() ==
              defaultLaunchImageGalleryId) {
        launchImageGalleryId = defaultLaunchImageGalleryId;
      }
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
        importFingerprint: importFingerprint,
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
    String? coverGalleryId;
    String? lightCoverGalleryId;
    String? darkCoverGalleryId;
    String? bottomNavGalleryId;
    String? readerFontFamilyKey;
    final importedFontFamilyKeys = <String>[];
    final sharedBackgroundPaths = <String>[];
    final sharedReaderBackgroundPaths = <String>[];

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

      final meta = await _readOptionalArchiveJsonFile(archive, 'meta.json');
      coverGalleryId = await _importRgShareCoverGallery(
        archive,
        meta['cover'],
        fallbackName: rawName.isEmpty ? 'RGShare 封面图集' : rawName,
      );
      if (coverGalleryId != null) {
        lightCoverGalleryId = coverGalleryId;
        darkCoverGalleryId = coverGalleryId;
      }
      bottomNavGalleryId = await _importRgShareBottomNavGallery(
        archive,
        meta['tabBarProfile'],
        fallbackName: rawName.isEmpty ? 'RGShare 底栏' : '$rawName 底栏',
      );
      final readerThemeImport = await _importRgShareReaderTheme(
        archive,
        themeDirectory,
        meta['readerTheme'],
      );
      readerFontFamilyKey = readerThemeImport.readerFontFamilyKey;
      importedFontFamilyKeys.addAll(readerThemeImport.importedFontFamilyKeys);
      if (readerThemeImport.backgroundPath != null) {
        sharedReaderBackgroundPaths.add(readerThemeImport.backgroundPath!);
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
        ).copyWith(
          readerWallpaperPath: readerThemeImport.backgroundPath,
          clearReaderWallpaperPath: readerThemeImport.backgroundPath == null,
        ),
        darkConfig: _buildModeConfigFromRgShare(
          colors,
          wallpaperPath: importedDarkWallpaperPath,
          isDark: true,
        ).copyWith(
          readerWallpaperPath: readerThemeImport.backgroundPath,
          clearReaderWallpaperPath: readerThemeImport.backgroundPath == null,
        ),
        coverGalleryId: coverGalleryId,
        lightCoverGalleryId: lightCoverGalleryId,
        darkCoverGalleryId: darkCoverGalleryId,
        bottomNavGalleryId: bottomNavGalleryId,
        readerFontFamilyKey: readerFontFamilyKey,
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
        importedFontFamilyKeys: importedFontFamilyKeys,
        sharedBackgroundPaths: sharedBackgroundPaths,
        sharedReaderBackgroundPaths: sharedReaderBackgroundPaths,
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

  Future<String> saveReaderWallpaper({
    required String themeId,
    required AppAdvancedThemeMode mode,
    required List<int> bytes,
    required String fileName,
  }) async {
    final extension = _normalizeSharedImageExtension(bytes, fileName);
    final asset = await _assetStore.persistBytes(
      type: ManagedAssetType.readerBackground,
      scope: ManagedAssetScope.themeBinding,
      bytes: bytes,
      fileName: 'theme_reader_bg_${mode.name}.$extension',
      collectionId: themeId,
      targetNamePrefix: 'theme_reader_bg_${mode.name}',
    );
    final targetPath = asset.resolvedPath!;
    await evictFileImagePath(targetPath);
    return targetPath;
  }

  Future<void> deleteWallpaper(String path) async {
    final normalized = path.trim();
    if (normalized.isEmpty) {
      return;
    }
    await evictFileImagePath(normalized);
    await _assetStore.deletePath(normalized);
  }

  Future<void> deleteReaderWallpaper(String path) async {
    final normalized = path.trim();
    if (normalized.isEmpty) {
      return;
    }
    await ReaderBackgroundService(
      assetStore: _assetStore,
    ).deleteBackground(normalized);
  }

  Future<bool> isThemeOwnedReaderWallpaper({
    required String themeId,
    required String path,
  }) async {
    final normalizedThemeId = themeId.trim();
    final normalizedPath = path.trim();
    if (normalizedThemeId.isEmpty || normalizedPath.isEmpty) {
      return false;
    }
    final resolved =
        await _assetStore.resolvePersistedPath(normalizedPath) ??
        normalizedPath;
    final directory = await _assetStore.resolveDirectory(
      ManagedAssetType.readerBackground,
      collectionId: normalizedThemeId,
    );
    final normalizedDirectory = p.normalize(directory.path);
    final normalizedResolved = p.normalize(resolved);
    return normalizedResolved == normalizedDirectory ||
        p.isWithin(normalizedDirectory, normalizedResolved);
  }

  Future<Directory> _themeDirectory(String themeId) async {
    final documents = await getApplicationDocumentsDirectory();
    return Directory(p.join(documents.path, 'advanced_themes', themeId));
  }

  Future<File> _themeIndexFile() async {
    final documents = await getApplicationDocumentsDirectory();
    final root = Directory(p.join(documents.path, 'advanced_themes'));
    if (!await root.exists()) {
      await root.create(recursive: true);
    }
    return File(p.join(root.path, _themeIndexFileName));
  }

  Future<String?> _loadPersistedThemesRaw() async {
    final indexFile = await _themeIndexFile();
    if (await indexFile.exists()) {
      final raw = await indexFile.readAsString();
      final normalized = raw.trim();
      return normalized.isEmpty ? null : raw;
    }

    final prefs = await _preferencesFuture;
    final legacyRaw = prefs.getString(_themesKey);
    if (legacyRaw == null || legacyRaw.trim().isEmpty) {
      return null;
    }

    await _writeThemeIndexFile(legacyRaw);
    await prefs.remove(_themesKey);
    return legacyRaw;
  }

  Future<void> _writeThemeIndexFile(String raw) async {
    final indexFile = await _themeIndexFile();
    await indexFile.writeAsString(raw, flush: true);
  }

  Future<void> _deleteThemeIndexFile() async {
    final indexFile = await _themeIndexFile();
    if (await indexFile.exists()) {
      await indexFile.delete();
    }
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

  Future<String> _computeImportFingerprintForFile(File file) async {
    final digest = await crypto.sha256.bind(file.openRead()).first;
    return digest.toString();
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
      componentStyle:
          normalizedConfig['componentStyle'] is Map
              ? AppAdvancedThemeComponentStyle.fromJson(
                (normalizedConfig['componentStyle'] as Map).map(
                  (nestedKey, nestedValue) =>
                      MapEntry(nestedKey.toString(), nestedValue),
                ),
              )
              : const AppAdvancedThemeComponentStyle(),
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

  Archive _decodeZipArchiveFile(String path) {
    final input = InputFileStream(path);
    try {
      return ZipDecoder().decodeStream(input, verify: true);
    } finally {
      input.close();
    }
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

  Future<Map<String, dynamic>> _readOptionalArchiveJsonFile(
    Archive archive,
    String path,
  ) async {
    final file = archive.findFile(path);
    if (file == null) {
      return const <String, dynamic>{};
    }
    try {
      final decoded = jsonDecode(
        utf8.decode(_archiveFileBytes(file), allowMalformed: true),
      );
      return _readOptionalMap(decoded);
    } catch (_) {
      return const <String, dynamic>{};
    }
  }

  Future<String?> _importRgShareCoverGallery(
    Archive archive,
    Object? rawMeta, {
    required String fallbackName,
  }) async {
    final meta = _readOptionalMap(rawMeta);
    final files = meta['files'];
    final galleryFiles =
        files is List
            ? files
                .map((item) => item.toString().trim())
                .where((item) => item.isNotEmpty)
                .toList(growable: false)
            : const <String>[];
    final name = meta['name']?.toString().trim();
    if (galleryFiles.isEmpty) {
      return null;
    }

    final service = CoverGalleryService(preferences: await _preferencesFuture);
    final gallery = await service.createGallery(
      name: name == null || name.isEmpty ? fallbackName : name,
    );
    try {
      for (final bundlePath in galleryFiles) {
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

  Future<_RgShareReaderThemeImport> _importRgShareReaderTheme(
    Archive archive,
    Directory themeDirectory,
    Object? rawMeta,
  ) async {
    final meta = _readOptionalMap(rawMeta);
    final filePath = meta['filePath']?.toString().trim() ?? '';
    final backgroundPath = meta['backgroundImagePath']?.toString().trim() ?? '';
    final fonts =
        meta['fonts'] is List
            ? (meta['fonts'] as List)
                .map((item) => _readOptionalMap(item))
                .where((item) => item.isNotEmpty)
                .toList(growable: false)
            : const <Map<String, dynamic>>[];
    if (filePath.isEmpty && backgroundPath.isEmpty && fonts.isEmpty) {
      return const _RgShareReaderThemeImport();
    }

    final themeJson = await _readOptionalArchiveJsonFile(archive, filePath);
    final remappedFontKeys = <String, String>{};
    final importedFontFamilyKeys = <String>[];
    final fontService = ReaderFontRegistryService();
    for (final font in fonts) {
      final oldId = font['id']?.toString().trim() ?? '';
      final fontFilePath = font['filePath']?.toString().trim() ?? '';
      if (oldId.isEmpty || fontFilePath.isEmpty) {
        continue;
      }
      final extractedFontPath =
          await _extractOptionalArchiveFileToThemeDirectory(
            archive,
            themeDirectory,
            fontFilePath,
            targetNamePrefix: 'rgshare_font_$oldId',
          );
      if (extractedFontPath == null) {
        continue;
      }
      try {
        final importedEntry = await fontService.importFontFile(
          filePath: extractedFontPath,
          displayName: font['name']?.toString(),
        );
        remappedFontKeys[oldId] = importedEntry.fontFamilyKey;
        importedFontFamilyKeys.add(importedEntry.fontFamilyKey);
      } catch (_) {
        // Ignore a single broken font and keep importing the theme.
      }
    }

    String? importedBackgroundPath;
    if (backgroundPath.isNotEmpty) {
      final extractedBackgroundPath =
          await _extractOptionalArchiveFileToThemeDirectory(
            archive,
            themeDirectory,
            backgroundPath,
            targetNamePrefix: 'reader_wallpaper_rgshare',
          );
      if (extractedBackgroundPath != null) {
        importedBackgroundPath = await ReaderBackgroundService()
            .importBackground(
              bytes: await File(extractedBackgroundPath).readAsBytes(),
              fileName: p.basename(extractedBackgroundPath),
            );
      }
    }
    final bodyFontId = themeJson['bodyFont']?.toString().trim() ?? '';
    return _RgShareReaderThemeImport(
      backgroundPath: importedBackgroundPath,
      readerFontFamilyKey:
          bodyFontId.isEmpty ? null : remappedFontKeys[bodyFontId],
      importedFontFamilyKeys: importedFontFamilyKeys,
    );
  }

  Future<String?> _importRgShareBottomNavGallery(
    Archive archive,
    Object? rawMeta, {
    required String fallbackName,
  }) async {
    final meta = _readOptionalMap(rawMeta);
    final profilePath = meta['filePath']?.toString().trim() ?? '';
    final profile = await _readOptionalArchiveJsonFile(archive, profilePath);
    final name = meta['name']?.toString().trim();
    final rawItems = profile['items'];
    if (rawItems is! List || rawItems.isEmpty) {
      return null;
    }

    final service = BottomNavIconGalleryService(
      preferences: await _preferencesFuture,
    );
    var gallery = await service.createGallery(
      name: name == null || name.isEmpty ? fallbackName : name,
    );
    var nextItems = Map<BottomNavIconGalleryTab, BottomNavIconSet>.from(
      gallery.items,
    );
    final tempDirectory = await Directory.systemTemp.createTemp(
      'rgshare_nav_import_',
    );
    try {
      for (final rawItem in rawItems) {
        final item = _readOptionalMap(rawItem);
        final tabs = _rgShareTabsFromProfileName(
          item['tab']?.toString().trim() ?? '',
        );
        if (tabs.isEmpty) {
          continue;
        }
        final iconSource = _readOptionalMap(item['iconSource']);
        final value = iconSource['value']?.toString().trim() ?? '';
        if ((iconSource['type']?.toString().trim() ?? '') != 'customImage' ||
            value.isEmpty) {
          continue;
        }
        final bundlePath = 'resources/tabbar/$value';
        final archiveFile = archive.findFile(bundlePath);
        if (archiveFile == null) {
          continue;
        }
        final extension = p.extension(value).replaceFirst('.', '').trim();
        final format = _bottomNavFormatFromName(extension);
        if (format == null) {
          continue;
        }
        final tempPath = p.join(tempDirectory.path, p.basename(bundlePath));
        await File(
          tempPath,
        ).writeAsBytes(_archiveFileBytes(archiveFile), flush: true);

        for (final tab in tabs) {
          final importedAsset = await service.importIconAsset(
            galleryId: gallery.id,
            tab: tab,
            slot: BottomNavIconVariantSlot.lightUnselected,
            sourcePath: tempPath,
            format: format,
          );
          final currentSet = nextItems[tab] ?? const BottomNavIconSet();
          nextItems[tab] = currentSet.copyWith(
            lightUnselected: importedAsset,
            lightSelected: importedAsset,
            darkUnselected: importedAsset,
            darkSelected: importedAsset,
          );
        }
      }
      gallery = await service.saveGallery(gallery.copyWith(items: nextItems));
      final hasAnyIcon = gallery.items.values.any(
        (set) =>
            set.lightUnselected != null ||
            set.lightSelected != null ||
            set.darkUnselected != null ||
            set.darkSelected != null,
      );
      if (!hasAnyIcon) {
        await service.deleteGallery(gallery.id);
        return null;
      }
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

  List<BottomNavIconGalleryTab> _rgShareTabsFromProfileName(String raw) {
    return switch (raw.trim().toLowerCase()) {
      'shelf' => const <BottomNavIconGalleryTab>[
        BottomNavIconGalleryTab.bookshelf,
      ],
      'library' => const <BottomNavIconGalleryTab>[
        BottomNavIconGalleryTab.bookshelf,
        BottomNavIconGalleryTab.discover,
      ],
      'statistic' => const <BottomNavIconGalleryTab>[
        BottomNavIconGalleryTab.stats,
      ],
      'mine' => const <BottomNavIconGalleryTab>[BottomNavIconGalleryTab.mine],
      // 旧 RG share 主题包仍可能用 home 命名首页槽位；导入时迁移为书架。
      'home' => const <BottomNavIconGalleryTab>[
        BottomNavIconGalleryTab.bookshelf,
      ],
      'discover' => const <BottomNavIconGalleryTab>[
        BottomNavIconGalleryTab.discover,
      ],
      _ => const <BottomNavIconGalleryTab>[],
    };
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

    final assignments = <_BottomNavBundleImportAssignment>[];
    final prefix = 'navbar_pack/$normalizedId/';
    for (final file in archive.files) {
      final bundlePath = file.name;
      if (!bundlePath.startsWith(prefix) ||
          bundlePath.endsWith('/') ||
          bundlePath.endsWith('/meta.json')) {
        continue;
      }
      final fileName = p.basename(bundlePath).toLowerCase();
      final resolved = _resolveRedBottomNavEntry(
        fileName: fileName,
        isDark: isDark,
      );
      if (resolved == null) {
        continue;
      }
      assignments.add(
        _BottomNavBundleImportAssignment.bundle(
          tab: resolved.$1,
          slot: resolved.$2,
          format: resolved.$3,
          bundlePath: bundlePath,
        ),
      );
    }
    return assignments;
  }

  (BottomNavIconGalleryTab, BottomNavIconVariantSlot, BottomNavIconAssetFormat)?
  _resolveRedBottomNavEntry({required String fileName, required bool isDark}) {
    final extension = p.extension(fileName).replaceFirst('.', '').trim();
    final format = _bottomNavFormatFromName(extension);
    if (format == null) {
      return null;
    }
    final baseName = p.basenameWithoutExtension(fileName).trim().toLowerCase();
    final parts = baseName.split('_');
    if (parts.length < 2) {
      return null;
    }
    final slotName = parts.last;
    final tabName = parts.sublist(0, parts.length - 1).join('_');
    final tab = switch (tabName) {
      // 旧红色主题包使用 featured/home 表示原首页槽位；首页删除后统一落到书架。
      'featured' || 'home' || 'bookshelf' => BottomNavIconGalleryTab.bookshelf,
      'discover' || 'notes' => BottomNavIconGalleryTab.discover,
      'statistics' => BottomNavIconGalleryTab.stats,
      'settings' || 'mine' => BottomNavIconGalleryTab.mine,
      _ => null,
    };
    if (tab == null) {
      return null;
    }
    final slot = switch (slotName) {
      'normal' || 'unselected' =>
        isDark
            ? BottomNavIconVariantSlot.darkUnselected
            : BottomNavIconVariantSlot.lightUnselected,
      'selected' || 'active' =>
        isDark
            ? BottomNavIconVariantSlot.darkSelected
            : BottomNavIconVariantSlot.lightSelected,
      _ => null,
    };
    if (slot == null) {
      return null;
    }
    return (tab, slot, format);
  }

  BottomNavIconGalleryTab? _bottomNavTabFromName(String raw) {
    return switch (raw.trim()) {
      // 导入旧 manifest 时只做兼容迁移，应用运行时不再提供 home 导航槽位。
      'home' => BottomNavIconGalleryTab.bookshelf,
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
      'gif' => BottomNavIconAssetFormat.gif,
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

  Future<AdvancedThemeSummary> _buildThemeSummary(
    AppAdvancedTheme theme, {
    required Map<String, String?> previewPathCache,
  }) async {
    return AdvancedThemeSummary(
      id: theme.id,
      name: theme.name,
      category: theme.category?.trim(),
      updatedAt: theme.updatedAt,
      lightMode: await _buildModeSummary(
        theme.lightConfig,
        previewPathCache: previewPathCache,
      ),
      darkMode: await _buildModeSummary(
        theme.darkConfig,
        previewPathCache: previewPathCache,
      ),
      hasCoverGalleryBinding: theme.hasCoverGalleryBinding,
      hasLaunchImageGallery:
          theme.launchImageGalleryId?.trim().isNotEmpty ?? false,
      hasBottomNavGallery: theme.bottomNavGalleryId?.trim().isNotEmpty ?? false,
      hasAppInterfaceFont:
          theme.appInterfaceFontFamilyKey?.trim().isNotEmpty ?? false,
      hasReaderFont: theme.readerFontFamilyKey?.trim().isNotEmpty ?? false,
    );
  }

  Future<AdvancedThemeModeSummary> _buildModeSummary(
    AppAdvancedThemeModeConfig config, {
    required Map<String, String?> previewPathCache,
  }) async {
    final colors = config.colors;
    return AdvancedThemeModeSummary(
      primaryColorValue: colors.primaryColorValue,
      backgroundColorValue: colors.backgroundColorValue,
      surfaceColorValue: colors.surfaceColorValue,
      cardColorValue: colors.cardColorValue,
      cardTextColorValue: colors.cardTextColorValue,
      textSecondaryColorValue: colors.textSecondaryColorValue,
      componentStyle: config.componentStyle,
      wallpaperPath: await _resolvePreviewWallpaperPath(
        config.wallpaperAsset,
        previewPathCache: previewPathCache,
      ),
      hasWallpaper: config.hasWallpaper,
      hasReaderWallpaper: config.hasReaderWallpaper,
      configuredColorCount: colors.configuredColorCount,
    );
  }

  Future<String?> _resolvePreviewWallpaperPath(
    ManagedAssetRef? ref, {
    required Map<String, String?> previewPathCache,
  }) async {
    if (ref == null) {
      return null;
    }
    final cacheKey = ref.bindingKey;
    if (previewPathCache.containsKey(cacheKey)) {
      return previewPathCache[cacheKey];
    }
    final normalizedRef = await _assetStore.normalizeRefForRuntime(ref);
    final resolvedPath = normalizedRef?.normalizedResolvedPath;
    if (resolvedPath == null || resolvedPath.isEmpty) {
      previewPathCache[cacheKey] = null;
      return null;
    }
    final file = File(resolvedPath);
    final previewPath = await file.exists() ? resolvedPath : null;
    previewPathCache[cacheKey] = previewPath;
    return previewPath;
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

class _RgShareReaderThemeImport {
  const _RgShareReaderThemeImport({
    this.backgroundPath,
    this.readerFontFamilyKey,
    this.importedFontFamilyKeys = const <String>[],
  });

  final String? backgroundPath;
  final String? readerFontFamilyKey;
  final List<String> importedFontFamilyKeys;
}

class AdvancedThemeDeleteOptions {
  const AdvancedThemeDeleteOptions({
    this.deleteAppearanceWallpapers = true,
    this.deleteReaderWallpapers = true,
    this.deleteCoverGalleries = true,
    this.deleteLaunchImageGallery = true,
    this.deleteBottomNavGallery = true,
    this.deleteFonts = false,
  });

  const AdvancedThemeDeleteOptions.none()
    : deleteAppearanceWallpapers = false,
      deleteReaderWallpapers = false,
      deleteCoverGalleries = false,
      deleteLaunchImageGallery = false,
      deleteBottomNavGallery = false,
      deleteFonts = false;

  final bool deleteAppearanceWallpapers;
  final bool deleteReaderWallpapers;
  final bool deleteCoverGalleries;
  final bool deleteLaunchImageGallery;
  final bool deleteBottomNavGallery;
  final bool deleteFonts;

  bool get deleteAnyAssociatedResources {
    return deleteAppearanceWallpapers ||
        deleteReaderWallpapers ||
        deleteCoverGalleries ||
        deleteLaunchImageGallery ||
        deleteBottomNavGallery ||
        deleteFonts;
  }
}

class AdvancedThemeModeSummary {
  const AdvancedThemeModeSummary({
    required this.primaryColorValue,
    required this.backgroundColorValue,
    required this.surfaceColorValue,
    required this.cardColorValue,
    required this.cardTextColorValue,
    required this.textSecondaryColorValue,
    required this.componentStyle,
    required this.wallpaperPath,
    required this.hasWallpaper,
    required this.hasReaderWallpaper,
    required this.configuredColorCount,
  });

  factory AdvancedThemeModeSummary.fromConfig(
    AppAdvancedThemeModeConfig config,
  ) {
    final colors = config.colors;
    return AdvancedThemeModeSummary(
      primaryColorValue: colors.primaryColorValue,
      backgroundColorValue: colors.backgroundColorValue,
      surfaceColorValue: colors.surfaceColorValue,
      cardColorValue: colors.cardColorValue,
      cardTextColorValue: colors.cardTextColorValue,
      textSecondaryColorValue: colors.textSecondaryColorValue,
      componentStyle: config.componentStyle,
      wallpaperPath: config.wallpaperPath,
      hasWallpaper: config.hasWallpaper,
      hasReaderWallpaper: config.hasReaderWallpaper,
      configuredColorCount: colors.configuredColorCount,
    );
  }

  final int? primaryColorValue;
  final int? backgroundColorValue;
  final int? surfaceColorValue;
  final int? cardColorValue;
  final int? cardTextColorValue;
  final int? textSecondaryColorValue;
  final AppAdvancedThemeComponentStyle componentStyle;
  final String? wallpaperPath;
  final bool hasWallpaper;
  final bool hasReaderWallpaper;
  final int configuredColorCount;

  AdvancedThemeModeSummary copyWith({
    String? wallpaperPath,
    bool clearWallpaperPath = false,
  }) {
    return AdvancedThemeModeSummary(
      primaryColorValue: primaryColorValue,
      backgroundColorValue: backgroundColorValue,
      surfaceColorValue: surfaceColorValue,
      cardColorValue: cardColorValue,
      cardTextColorValue: cardTextColorValue,
      textSecondaryColorValue: textSecondaryColorValue,
      componentStyle: componentStyle,
      wallpaperPath:
          clearWallpaperPath ? null : (wallpaperPath ?? this.wallpaperPath),
      hasWallpaper: hasWallpaper,
      hasReaderWallpaper: hasReaderWallpaper,
      configuredColorCount: configuredColorCount,
    );
  }
}

class AdvancedThemeSummary {
  const AdvancedThemeSummary({
    required this.id,
    required this.name,
    required this.updatedAt,
    required this.lightMode,
    required this.darkMode,
    this.category,
    this.hasCoverGalleryBinding = false,
    this.hasLaunchImageGallery = false,
    this.hasBottomNavGallery = false,
    this.hasAppInterfaceFont = false,
    this.hasReaderFont = false,
  });

  factory AdvancedThemeSummary.fromTheme(AppAdvancedTheme theme) {
    return AdvancedThemeSummary(
      id: theme.id,
      name: theme.name,
      category: theme.category?.trim(),
      updatedAt: theme.updatedAt,
      lightMode: AdvancedThemeModeSummary.fromConfig(
        theme.lightConfig,
      ).copyWith(clearWallpaperPath: true),
      darkMode: AdvancedThemeModeSummary.fromConfig(
        theme.darkConfig,
      ).copyWith(clearWallpaperPath: true),
      hasCoverGalleryBinding: theme.hasCoverGalleryBinding,
      hasLaunchImageGallery:
          theme.launchImageGalleryId?.trim().isNotEmpty ?? false,
      hasBottomNavGallery: theme.bottomNavGalleryId?.trim().isNotEmpty ?? false,
      hasAppInterfaceFont:
          theme.appInterfaceFontFamilyKey?.trim().isNotEmpty ?? false,
      hasReaderFont: theme.readerFontFamilyKey?.trim().isNotEmpty ?? false,
    );
  }

  final String id;
  final String name;
  final String? category;
  final DateTime updatedAt;
  final AdvancedThemeModeSummary lightMode;
  final AdvancedThemeModeSummary darkMode;
  final bool hasCoverGalleryBinding;
  final bool hasLaunchImageGallery;
  final bool hasBottomNavGallery;
  final bool hasAppInterfaceFont;
  final bool hasReaderFont;

  bool get hasBothModesConfigured {
    return lightMode.configuredColorCount > 0 &&
        darkMode.configuredColorCount > 0;
  }

  AdvancedThemeSummary copyWith({
    AdvancedThemeModeSummary? lightMode,
    AdvancedThemeModeSummary? darkMode,
  }) {
    return AdvancedThemeSummary(
      id: id,
      name: name,
      category: category,
      updatedAt: updatedAt,
      lightMode: lightMode ?? this.lightMode,
      darkMode: darkMode ?? this.darkMode,
      hasCoverGalleryBinding: hasCoverGalleryBinding,
      hasLaunchImageGallery: hasLaunchImageGallery,
      hasBottomNavGallery: hasBottomNavGallery,
      hasAppInterfaceFont: hasAppInterfaceFont,
      hasReaderFont: hasReaderFont,
    );
  }
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

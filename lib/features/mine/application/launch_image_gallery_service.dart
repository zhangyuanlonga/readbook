import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../app/images/file_image_cache.dart';
import '../../../core/storage/managed_asset_store.dart';
import '../../../domain/entities/launch_image_gallery.dart';
import '../../../domain/entities/managed_asset.dart';

const String defaultLaunchImageGalleryId = 'system_default';

final LaunchImageGallery defaultLaunchImageGallery = LaunchImageGallery(
  id: defaultLaunchImageGalleryId,
  name: '系统默认',
  createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  imagePaths: const <String>['assets/branding/selune_launch_scene.png'],
  isBuiltIn: true,
  isEditable: false,
  isDeletable: false,
);

class LaunchImageGalleryService {
  LaunchImageGalleryService({
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
  static const String _galleriesKey = 'launchImageGallery.galleries';
  static const String _activeGalleryIdKey = 'launchImageGallery.activeId';
  static const String _startupEnabledKey = 'launchImageGallery.startupEnabled';

  Future<List<LaunchImageGallery>> loadGalleries() async {
    final customGalleries = await _loadCustomGalleries();
    return <LaunchImageGallery>[defaultLaunchImageGallery, ...customGalleries];
  }

  Future<List<LaunchImageGallery>> _loadCustomGalleries() async {
    final prefs = await _preferencesFuture;
    final raw = prefs.getString(_galleriesKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <LaunchImageGallery>[];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <LaunchImageGallery>[];
      }
      final galleries = decoded
          .whereType<Map>()
          .map(
            (item) => LaunchImageGallery.fromJson(
              item.map((key, value) => MapEntry(key.toString(), value)),
            ),
          )
          .toList(growable: false);
      galleries.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      var changed = false;
      final normalizedGalleries = <LaunchImageGallery>[];
      for (final gallery in galleries) {
        final normalizedPaths = <String>[];
        for (final path in gallery.imagePaths) {
          final persisted =
              await _assetStore.relativizePersistedPath(path) ?? path;
          final resolved =
              await _assetStore.resolvePersistedPath(persisted) ?? path;
          normalizedPaths.add(resolved);
          if (persisted != path || resolved != path) {
            changed = true;
          }
        }
        normalizedGalleries.add(
          gallery.copyWith(
            imagePaths: normalizedPaths,
            isBuiltIn: false,
            isEditable: true,
            isDeletable: true,
          ),
        );
      }
      if (changed) {
        await saveGalleries(normalizedGalleries);
      }
      return normalizedGalleries;
    } catch (_) {
      return const <LaunchImageGallery>[];
    }
  }

  Future<void> saveGalleries(List<LaunchImageGallery> galleries) async {
    final prefs = await _preferencesFuture;
    final customGalleries = galleries
        .where((gallery) => !gallery.isBuiltIn)
        .toList(growable: false);
    if (customGalleries.isEmpty) {
      await prefs.remove(_galleriesKey);
      return;
    }
    await prefs.setString(
      _galleriesKey,
      jsonEncode(
        await Future.wait(
          customGalleries.map((item) async {
            final persistedPaths = <String>[];
            for (final path in item.imagePaths) {
              persistedPaths.add(
                await _assetStore.relativizePersistedPath(path) ?? path,
              );
            }
            return item
                .copyWith(
                  imagePaths: persistedPaths,
                  isBuiltIn: false,
                  isEditable: true,
                  isDeletable: true,
                )
                .toJson();
          }),
        ),
      ),
    );
  }

  Future<String?> loadActiveGalleryId() async {
    final prefs = await _preferencesFuture;
    final raw = prefs.getString(_activeGalleryIdKey)?.trim();
    if (raw == null || raw.isEmpty) {
      return defaultLaunchImageGalleryId;
    }
    return raw;
  }

  Future<void> saveActiveGalleryId(String? galleryId) async {
    final prefs = await _preferencesFuture;
    final normalized = galleryId?.trim();
    if (normalized == null || normalized.isEmpty) {
      await prefs.remove(_activeGalleryIdKey);
      return;
    }
    await prefs.setString(_activeGalleryIdKey, normalized);
  }

  Future<bool> loadStartupEnabled() async {
    final prefs = await _preferencesFuture;
    return prefs.getBool(_startupEnabledKey) ?? true;
  }

  Future<void> saveStartupEnabled(bool enabled) async {
    final prefs = await _preferencesFuture;
    await prefs.setBool(_startupEnabledKey, enabled);
  }

  Future<LaunchImageGallery?> loadActiveGallery() async {
    final activeId = await loadActiveGalleryId();
    if (activeId == null) {
      return null;
    }
    return loadGallery(activeId);
  }

  Future<String?> loadActiveLaunchImagePath() async {
    if (!await loadStartupEnabled()) {
      return null;
    }
    final gallery = await loadActiveGallery();
    return resolveGalleryPreviewPath(gallery);
  }

  Future<String?> loadLaunchImagePathForGallery(String? galleryId) async {
    if (!await loadStartupEnabled()) {
      return null;
    }
    final normalized = galleryId?.trim() ?? '';
    if (normalized.isEmpty) {
      return null;
    }
    final gallery = await loadGallery(normalized);
    return resolveGalleryPreviewPath(gallery);
  }

  Future<LaunchImageGallery> createGallery({String name = '未命名图集'}) async {
    final normalizedName = name.trim().isEmpty ? '未命名图集' : name.trim();
    final now = DateTime.now().toUtc();
    final gallery = LaunchImageGallery(
      id: 'launch_image_gallery_${_uuid.v4()}',
      name: normalizedName,
      createdAt: now,
      updatedAt: now,
      imagePaths: const <String>[],
    );
    final galleries = await loadGalleries();
    await saveGalleries(<LaunchImageGallery>[gallery, ...galleries]);
    return gallery;
  }

  Future<LaunchImageGallery?> loadGallery(String galleryId) async {
    final galleries = await loadGalleries();
    for (final gallery in galleries) {
      if (gallery.id == galleryId) {
        return gallery;
      }
    }
    return null;
  }

  Future<LaunchImageGallery> saveGallery(LaunchImageGallery gallery) async {
    if (gallery.isBuiltIn) {
      return gallery;
    }
    final galleries = await loadGalleries();
    final updatedGallery = gallery.copyWith(updatedAt: DateTime.now().toUtc());
    final updated = <LaunchImageGallery>[
      for (final item in galleries)
        if (item.id == updatedGallery.id) updatedGallery else item,
      if (!galleries.any((item) => item.id == updatedGallery.id))
        updatedGallery,
    ];
    await saveGalleries(updated);
    return updatedGallery;
  }

  Future<void> renameGallery({
    required String galleryId,
    required String name,
  }) async {
    final normalized = name.trim();
    if (normalized.isEmpty) {
      throw const FormatException('Gallery name is required.');
    }
    final gallery = await loadGallery(galleryId);
    if (gallery == null) {
      throw const FormatException('Gallery not found.');
    }
    if (!gallery.isEditable) {
      throw const FormatException('Built-in gallery cannot be renamed.');
    }
    await saveGallery(gallery.copyWith(name: normalized));
  }

  Future<LaunchImageGallery> duplicateGallery({
    required String sourceGalleryId,
    required String name,
  }) async {
    final sourceGallery = await loadGallery(sourceGalleryId);
    if (sourceGallery == null) {
      throw const FormatException('Gallery not found.');
    }
    final normalizedName =
        name.trim().isEmpty ? '${sourceGallery.name} 副本' : name.trim();
    final now = DateTime.now().toUtc();
    final copied = LaunchImageGallery(
      id: 'launch_image_gallery_${_uuid.v4()}',
      name: normalizedName,
      createdAt: now,
      updatedAt: now,
      imagePaths: sourceGallery.imagePaths,
    );
    final galleries = await loadGalleries();
    await saveGalleries(<LaunchImageGallery>[copied, ...galleries]);
    return copied;
  }

  Future<void> deleteGallery(String galleryId) async {
    final targetGallery = await loadGallery(galleryId);
    if (targetGallery != null && !targetGallery.isDeletable) {
      return;
    }
    final galleries = await loadGalleries();
    final updated = galleries
        .where((gallery) => gallery.id != galleryId)
        .toList(growable: false);
    await saveGalleries(updated);

    final activeId = await loadActiveGalleryId();
    if (activeId == galleryId) {
      await saveActiveGalleryId(null);
    }

    final directory = await _galleryDirectory(galleryId);
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  Future<LaunchImageGallery> importImage({
    required String galleryId,
    required List<int> bytes,
    required String fileName,
  }) async {
    final gallery = await loadGallery(galleryId);
    if (gallery == null) {
      throw const FormatException('Gallery not found.');
    }
    if (!gallery.isEditable) {
      throw const FormatException('Built-in gallery cannot be edited.');
    }
    final extension = _normalizeFileExtension(fileName);
    final asset = await _assetStore.persistBytes(
      type: ManagedAssetType.launchImageGalleryImage,
      scope: ManagedAssetScope.launchImage,
      bytes: bytes,
      fileName: 'launch.$extension',
      collectionId: galleryId,
      targetNamePrefix: 'launch',
    );
    final targetPath = asset.resolvedPath!;
    await evictFileImagePath(targetPath);
    return saveGallery(
      gallery.copyWith(imagePaths: <String>[targetPath, ...gallery.imagePaths]),
    );
  }

  Future<LaunchImageGallery> deleteImages({
    required String galleryId,
    required List<String> paths,
  }) async {
    final gallery = await loadGallery(galleryId);
    if (gallery == null) {
      throw const FormatException('Gallery not found.');
    }
    if (!gallery.isEditable) {
      throw const FormatException('Built-in gallery cannot be edited.');
    }

    final normalizedTargets = <String>{};
    for (final rawPath in paths) {
      final resolved =
          await _assetStore.resolvePersistedPath(rawPath) ?? rawPath.trim();
      if (resolved.isNotEmpty) {
        normalizedTargets.add(resolved);
      }
    }

    for (final path in normalizedTargets) {
      await evictFileImagePath(path);
      await _assetStore.deletePath(path);
    }

    final updatedPaths = <String>[];
    for (final path in gallery.imagePaths) {
      final resolved = await _assetStore.resolvePersistedPath(path) ?? path;
      if (!normalizedTargets.contains(resolved)) {
        updatedPaths.add(path);
      }
    }

    return saveGallery(gallery.copyWith(imagePaths: updatedPaths));
  }

  Future<Directory> _galleryDirectory(String galleryId) async {
    return _assetStore.resolveDirectory(
      ManagedAssetType.launchImageGalleryImage,
      collectionId: galleryId,
    );
  }

  String? resolveGalleryPreviewPath(LaunchImageGallery? gallery) {
    if (gallery == null) {
      return null;
    }
    for (final rawPath in gallery.imagePaths) {
      final normalized = rawPath.trim();
      if (normalized.isEmpty) {
        continue;
      }
      final file = File(normalized);
      if (file.existsSync() || normalized.startsWith('assets/')) {
        return file.path;
      }
    }
    return null;
  }

  String _normalizeFileExtension(String fileName) {
    final extension = p.extension(fileName).replaceFirst('.', '').trim();
    if (extension.isEmpty) {
      return 'png';
    }
    return extension.toLowerCase();
  }
}

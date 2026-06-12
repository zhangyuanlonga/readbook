import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../app/images/file_image_cache.dart';
import '../../../core/storage/managed_asset_store.dart';
import '../../../domain/entities/cover_gallery.dart';
import '../../../domain/entities/managed_asset.dart';
import 'gallery_index_file_store.dart';
import 'gallery_index_models.dart';

class CoverGalleryService {
  CoverGalleryService({
    SharedPreferences? preferences,
    ManagedAssetStore? assetStore,
    GalleryIndexFileStore? indexFileStore,
  }) : _preferencesFuture =
           preferences == null
               ? SharedPreferences.getInstance()
               : Future.value(preferences),
       _assetStore = assetStore ?? ManagedAssetStore(),
       _indexFileStore =
           indexFileStore ??
           const GalleryIndexFileStore(
             directoryName: 'cover_galleries',
             legacyPreferencesKey: _galleriesKey,
           );

  final Future<SharedPreferences> _preferencesFuture;
  final ManagedAssetStore _assetStore;
  final GalleryIndexFileStore _indexFileStore;

  static const Uuid _uuid = Uuid();
  static const String _galleriesKey = 'coverGallery.galleries';

  Future<List<CoverGalleryIndexItem>> loadGalleryIndex() async {
    final galleries = await loadGalleries();
    return galleries
        .map((gallery) {
          final previewPaths = resolveGalleryPreviewPaths(gallery, limit: 1);
          return CoverGalleryIndexItem(
            id: gallery.id,
            name: gallery.name,
            updatedAt: gallery.updatedAt,
            imageCount: gallery.imagePaths.length,
            previewPath: previewPaths.isEmpty ? null : previewPaths.first,
          );
        })
        .toList(growable: false);
  }

  Future<List<CoverGallery>> loadGalleries() async {
    final raw = await _loadPersistedGalleriesRaw();
    if (raw == null || raw.trim().isEmpty) {
      return const <CoverGallery>[];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <CoverGallery>[];
      }
      final galleries = decoded
          .whereType<Map>()
          .map(
            (item) => CoverGallery.fromJson(
              item.map((key, value) => MapEntry(key.toString(), value)),
            ),
          )
          .toList(growable: false);
      galleries.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      var changed = false;
      final normalizedGalleries = <CoverGallery>[];
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
        normalizedGalleries.add(gallery.copyWith(imagePaths: normalizedPaths));
      }
      if (changed) {
        await saveGalleries(normalizedGalleries);
      }
      return normalizedGalleries;
    } catch (_) {
      return const <CoverGallery>[];
    }
  }

  Future<void> saveGalleries(List<CoverGallery> galleries) async {
    final prefs = await _preferencesFuture;
    if (galleries.isEmpty) {
      await _deleteIndexFile();
      await prefs.remove(_galleriesKey);
      return;
    }
    await _writeIndexFile(
      jsonEncode(
        await Future.wait(
          galleries.map((item) async {
            final persistedPaths = <String>[];
            for (final path in item.imagePaths) {
              persistedPaths.add(
                await _assetStore.relativizePersistedPath(path) ?? path,
              );
            }
            return item.copyWith(imagePaths: persistedPaths).toJson();
          }),
        ),
      ),
    );
    await prefs.remove(_galleriesKey);
  }

  Future<CoverGallery> createGallery({String name = '未命名图集'}) async {
    final normalizedName = name.trim().isEmpty ? '未命名图集' : name.trim();
    final now = DateTime.now().toUtc();
    final gallery = CoverGallery(
      id: 'cover_gallery_${_uuid.v4()}',
      name: normalizedName,
      createdAt: now,
      updatedAt: now,
      imagePaths: const <String>[],
    );
    final galleries = await loadGalleries();
    await saveGalleries(<CoverGallery>[gallery, ...galleries]);
    return gallery;
  }

  Future<CoverGallery?> loadGallery(String galleryId) async {
    final galleries = await loadGalleries();
    for (final gallery in galleries) {
      if (gallery.id == galleryId) {
        return gallery;
      }
    }
    return null;
  }

  Future<CoverGallery> saveGallery(CoverGallery gallery) async {
    final galleries = await loadGalleries();
    final updatedGallery = gallery.copyWith(updatedAt: DateTime.now().toUtc());
    final updated = <CoverGallery>[
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
    await saveGallery(gallery.copyWith(name: normalized));
  }

  Future<CoverGallery> duplicateGallery({
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
    final copied = CoverGallery(
      id: 'cover_gallery_${_uuid.v4()}',
      name: normalizedName,
      createdAt: now,
      updatedAt: now,
      imagePaths: sourceGallery.imagePaths,
    );
    final galleries = await loadGalleries();
    await saveGalleries(<CoverGallery>[copied, ...galleries]);
    return copied;
  }

  Future<void> deleteGallery(String galleryId) async {
    final galleries = await loadGalleries();
    final updated = galleries
        .where((gallery) => gallery.id != galleryId)
        .toList(growable: false);
    await saveGalleries(updated);
    final directory = await _galleryDirectory(galleryId);
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  Future<CoverGallery> importImage({
    required String galleryId,
    required List<int> bytes,
    required String fileName,
  }) async {
    final gallery = await loadGallery(galleryId);
    if (gallery == null) {
      throw const FormatException('Gallery not found.');
    }
    final extension = _normalizeFileExtension(fileName);
    final asset = await _assetStore.persistBytes(
      type: ManagedAssetType.coverGalleryImage,
      scope: ManagedAssetScope.themeBinding,
      bytes: bytes,
      fileName: 'cover.$extension',
      collectionId: galleryId,
      targetNamePrefix: 'cover',
    );
    final targetPath = asset.resolvedPath!;
    await evictFileImagePath(targetPath);
    return saveGallery(
      gallery.copyWith(imagePaths: <String>[...gallery.imagePaths, targetPath]),
    );
  }

  Future<CoverGallery> deleteImages({
    required String galleryId,
    required List<String> paths,
  }) async {
    final gallery = await loadGallery(galleryId);
    if (gallery == null) {
      throw const FormatException('Gallery not found.');
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
      ManagedAssetType.coverGalleryImage,
      collectionId: galleryId,
    );
  }

  String? resolveGalleryPreviewPath(CoverGallery? gallery) {
    return resolveGalleryPreviewPaths(gallery, limit: 1).firstOrNull;
  }

  List<String> resolveGalleryPreviewPaths(
    CoverGallery? gallery, {
    int limit = 4,
  }) {
    if (gallery == null) {
      return const <String>[];
    }
    final previews = <String>[];
    for (final rawPath in gallery.imagePaths) {
      final normalized = rawPath.trim();
      if (normalized.isEmpty) {
        continue;
      }
      final file = File(normalized);
      if (file.existsSync() || normalized.startsWith('assets/')) {
        previews.add(file.path);
        if (previews.length >= limit) {
          break;
        }
      }
    }
    return List<String>.unmodifiable(previews);
  }

  Future<String?> _loadPersistedGalleriesRaw() async {
    final prefs = await _preferencesFuture;
    return _indexFileStore.loadRaw(preferences: prefs);
  }

  Future<void> _writeIndexFile(String raw) async {
    await _indexFileStore.writeRaw(raw);
  }

  Future<void> _deleteIndexFile() async {
    await _indexFileStore.delete();
  }

  String _normalizeFileExtension(String fileName) {
    final extension = p.extension(fileName).replaceFirst('.', '').trim();
    if (extension.isEmpty) {
      return 'png';
    }
    return extension.toLowerCase();
  }
}

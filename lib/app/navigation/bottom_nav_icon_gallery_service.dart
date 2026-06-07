import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../images/file_image_cache.dart';
import '../../core/storage/managed_asset_store.dart';
import 'bottom_nav_icon_gallery_defaults.dart';
import '../../domain/entities/bottom_nav_icon_gallery.dart';
import '../../domain/entities/managed_asset.dart';
import '../../features/mine/application/gallery_index_models.dart';

class BottomNavIconGalleryService {
  static const Uuid _uuid = Uuid();

  BottomNavIconGalleryService({
    SharedPreferences? preferences,
    ManagedAssetStore? assetStore,
  }) : _preferencesFuture =
           preferences == null
               ? SharedPreferences.getInstance()
               : Future.value(preferences),
       _assetStore = assetStore ?? ManagedAssetStore();

  final Future<SharedPreferences> _preferencesFuture;
  final ManagedAssetStore _assetStore;

  static const String _galleriesKey = 'bottomNavIconGallery.galleries';
  static const String _activeGalleryIdKey = 'bottomNavIconGallery.activeId';

  Future<List<BottomNavIconGalleryIndexItem>> loadGalleryIndex() async {
    final galleries = await loadGalleries();
    return galleries
        .map(BottomNavIconGalleryIndexItem.fromGallery)
        .toList(growable: false);
  }

  Future<List<BottomNavIconGallery>> loadGalleries() async {
    final prefs = await _preferencesFuture;
    final raw = prefs.getString(_galleriesKey);
    if (raw == null || raw.trim().isEmpty) {
      return List<BottomNavIconGallery>.unmodifiable(
        builtInBottomNavIconGalleries,
      );
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return List<BottomNavIconGallery>.unmodifiable(
          builtInBottomNavIconGalleries,
        );
      }

      final customGalleries = decoded
          .whereType<Map>()
          .map(
            (item) => BottomNavIconGallery.fromJson(
              item.map((key, value) => MapEntry(key.toString(), value)),
            ),
          )
          .toList(growable: false);
      var changed = false;
      final normalizedCustomGalleries = <BottomNavIconGallery>[];
      for (final gallery in customGalleries) {
        final normalizedItems = <BottomNavIconGalleryTab, BottomNavIconSet>{};
        for (final entry in gallery.items.entries) {
          final normalizedSet = await _normalizeIconSet(entry.value);
          normalizedItems[entry.key] = normalizedSet;
          if (normalizedSet.lightUnselected?.path !=
                  entry.value.lightUnselected?.path ||
              normalizedSet.lightSelected?.path !=
                  entry.value.lightSelected?.path ||
              normalizedSet.darkUnselected?.path !=
                  entry.value.darkUnselected?.path ||
              normalizedSet.darkSelected?.path !=
                  entry.value.darkSelected?.path) {
            changed = true;
          }
        }
        normalizedCustomGalleries.add(gallery.copyWith(items: normalizedItems));
      }
      final result =
          List<BottomNavIconGallery>.unmodifiable(<BottomNavIconGallery>[
            ...builtInBottomNavIconGalleries,
            ...normalizedCustomGalleries.where(
              (gallery) =>
                  !builtInBottomNavIconGalleries.any(
                    (builtIn) => builtIn.id == gallery.id,
                  ),
            ),
          ]);
      if (changed) {
        await saveGalleries(result);
      }
      return result;
    } catch (_) {
      return List<BottomNavIconGallery>.unmodifiable(
        builtInBottomNavIconGalleries,
      );
    }
  }

  Future<void> saveGalleries(List<BottomNavIconGallery> galleries) async {
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
          customGalleries.map((item) async => _toPersistedGalleryJson(item)),
        ),
      ),
    );
  }

  Future<String?> loadActiveGalleryId() async {
    final prefs = await _preferencesFuture;
    final raw = prefs.getString(_activeGalleryIdKey)?.trim();
    if (raw == null || raw.isEmpty) {
      return null;
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

  Future<BottomNavIconGallery?> loadActiveGallery() async {
    final activeId = await loadActiveGalleryId();
    final galleries = await loadGalleries();
    if (activeId == null) {
      return galleries.firstWhere(
        (gallery) => gallery.id == defaultBottomNavIconGalleryId,
        orElse: () => defaultBottomNavIconGallery,
      );
    }
    for (final gallery in galleries) {
      if (gallery.id == activeId) {
        return gallery;
      }
    }
    return galleries.firstWhere(
      (gallery) => gallery.id == defaultBottomNavIconGalleryId,
      orElse: () => defaultBottomNavIconGallery,
    );
  }

  Future<BottomNavIconGallery> createGallery({required String name}) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw const FormatException('Gallery name is required.');
    }
    final now = DateTime.now().toUtc();
    final gallery = BottomNavIconGallery(
      id: 'gallery_${_uuid.v4()}',
      name: normalizedName,
      createdAt: now,
      updatedAt: now,
      isBuiltIn: false,
      isEditable: true,
      isDeletable: true,
      items: const {
        BottomNavIconGalleryTab.bookshelf: BottomNavIconSet(),
        BottomNavIconGalleryTab.discover: BottomNavIconSet(),
        BottomNavIconGalleryTab.stats: BottomNavIconSet(),
        BottomNavIconGalleryTab.mine: BottomNavIconSet(),
      },
    );

    final galleries = await loadGalleries();
    await saveGalleries(<BottomNavIconGallery>[...galleries, gallery]);
    return gallery;
  }

  Future<BottomNavIconGallery> duplicateGallery({
    required String sourceGalleryId,
    required String name,
  }) async {
    final galleries = await loadGalleries();
    final source = galleries.firstWhere(
      (gallery) => gallery.id == sourceGalleryId,
      orElse: () => throw const FormatException('Gallery not found.'),
    );
    final now = DateTime.now().toUtc();
    final clone = source.copyWith(
      id: 'gallery_${_uuid.v4()}',
      name: name.trim().isEmpty ? '${source.name} 副本' : name.trim(),
      createdAt: now,
      updatedAt: now,
      isBuiltIn: false,
      isEditable: true,
      isDeletable: true,
      items: Map<BottomNavIconGalleryTab, BottomNavIconSet>.from(source.items),
    );
    await saveGalleries(<BottomNavIconGallery>[...galleries, clone]);
    return clone;
  }

  Future<void> renameGallery({
    required String galleryId,
    required String name,
  }) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw const FormatException('Gallery name is required.');
    }
    final galleries = await loadGalleries();
    final updated = galleries
        .map((gallery) {
          if (gallery.id != galleryId) {
            return gallery;
          }
          if (!gallery.isEditable) {
            throw const FormatException('Built-in gallery is not editable.');
          }
          return gallery.copyWith(
            name: normalizedName,
            updatedAt: DateTime.now().toUtc(),
          );
        })
        .toList(growable: false);
    await saveGalleries(updated);
  }

  Future<void> deleteGallery(String galleryId) async {
    final galleries = await loadGalleries();
    final target = galleries.firstWhere(
      (gallery) => gallery.id == galleryId,
      orElse: () => throw const FormatException('Gallery not found.'),
    );
    if (!target.isDeletable) {
      throw const FormatException('Built-in gallery cannot be deleted.');
    }

    final updated = galleries
        .where((gallery) => gallery.id != galleryId)
        .toList(growable: false);
    await saveGalleries(updated);

    final activeId = await loadActiveGalleryId();
    if (activeId == galleryId) {
      await saveActiveGalleryId(defaultBottomNavIconGalleryId);
    }

    final directory = await _galleryDirectory(galleryId);
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  Future<BottomNavIconGallery> saveGallery(BottomNavIconGallery gallery) async {
    final galleries = await loadGalleries();
    final updatedGallery = gallery.copyWith(updatedAt: DateTime.now().toUtc());
    final updated = <BottomNavIconGallery>[
      for (final item in galleries)
        if (item.id == updatedGallery.id) updatedGallery else item,
      if (!galleries.any((item) => item.id == updatedGallery.id))
        updatedGallery,
    ];
    await saveGalleries(updated);
    return updatedGallery;
  }

  Future<BottomNavIconAssetRef> importIconAsset({
    required String galleryId,
    required BottomNavIconGalleryTab tab,
    required BottomNavIconVariantSlot slot,
    required String sourcePath,
    required BottomNavIconAssetFormat format,
  }) async {
    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      throw const FileSystemException('Selected icon file does not exist.');
    }

    final imported = await _assetStore.importFile(
      type: ManagedAssetType.bottomNavIcon,
      scope: ManagedAssetScope.bottomNav,
      sourcePath: sourceFile.path,
      collectionId: galleryId,
      assetId: '${tab.name}_${slot.name}',
      fileName: p.basename(sourceFile.path),
      targetNamePrefix: '${tab.name}_${slot.name}',
    );
    final destinationPath = imported.resolvedPath!;
    await evictFileImagePath(destinationPath);

    return BottomNavIconAssetRef(
      path: destinationPath,
      format: format,
      isAsset: false,
    );
  }

  Future<BottomNavIconAssetRef> importIconAssetBytes({
    required String galleryId,
    required BottomNavIconGalleryTab tab,
    required BottomNavIconVariantSlot slot,
    required List<int> bytes,
    required String fileName,
    required BottomNavIconAssetFormat format,
  }) async {
    final imported = await _assetStore.persistBytes(
      type: ManagedAssetType.bottomNavIcon,
      scope: ManagedAssetScope.bottomNav,
      bytes: bytes,
      collectionId: galleryId,
      assetId: '${tab.name}_${slot.name}',
      fileName: fileName,
      targetNamePrefix: '${tab.name}_${slot.name}',
    );
    final destinationPath = imported.resolvedPath!;
    await evictFileImagePath(destinationPath);

    return BottomNavIconAssetRef(
      path: destinationPath,
      format: format,
      isAsset: false,
    );
  }

  Future<void> deleteIconAsset(BottomNavIconAssetRef assetRef) async {
    if (assetRef.isAsset) {
      return;
    }
    await evictFileImagePath(assetRef.path);
    await _assetStore.deletePath(assetRef.path);
  }

  Future<Directory> _galleryDirectory(String galleryId) async {
    return _assetStore.resolveDirectory(
      ManagedAssetType.bottomNavIcon,
      collectionId: galleryId,
    );
  }

  Future<BottomNavIconSet> _normalizeIconSet(BottomNavIconSet set) async {
    return BottomNavIconSet(
      lightUnselected: await _normalizeAssetRef(set.lightUnselected),
      lightSelected: await _normalizeAssetRef(set.lightSelected),
      darkUnselected: await _normalizeAssetRef(set.darkUnselected),
      darkSelected: await _normalizeAssetRef(set.darkSelected),
    );
  }

  Future<BottomNavIconAssetRef?> _normalizeAssetRef(
    BottomNavIconAssetRef? assetRef,
  ) async {
    if (assetRef == null || assetRef.isAsset) {
      return assetRef;
    }
    final persisted =
        await _assetStore.relativizePersistedPath(assetRef.path) ??
        assetRef.path;
    final resolved =
        await _assetStore.resolvePersistedPath(persisted) ?? assetRef.path;
    if (persisted == assetRef.path && resolved == assetRef.path) {
      return assetRef;
    }
    return assetRef.copyWith(path: resolved);
  }

  Future<Map<String, dynamic>> _toPersistedGalleryJson(
    BottomNavIconGallery gallery,
  ) async {
    final items = <BottomNavIconGalleryTab, BottomNavIconSet>{};
    for (final entry in gallery.items.entries) {
      items[entry.key] = BottomNavIconSet(
        lightUnselected: await _toPersistedAssetRef(
          entry.value.lightUnselected,
        ),
        lightSelected: await _toPersistedAssetRef(entry.value.lightSelected),
        darkUnselected: await _toPersistedAssetRef(entry.value.darkUnselected),
        darkSelected: await _toPersistedAssetRef(entry.value.darkSelected),
      );
    }
    return gallery.copyWith(items: items).toJson();
  }

  Future<BottomNavIconAssetRef?> _toPersistedAssetRef(
    BottomNavIconAssetRef? assetRef,
  ) async {
    if (assetRef == null || assetRef.isAsset) {
      return assetRef;
    }
    final persisted =
        await _assetStore.relativizePersistedPath(assetRef.path) ??
        assetRef.path;
    return assetRef.copyWith(path: persisted);
  }
}

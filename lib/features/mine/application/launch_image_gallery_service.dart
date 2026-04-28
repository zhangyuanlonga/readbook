import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../app/images/file_image_cache.dart';
import '../../../core/storage/managed_file_path_resolver.dart';
import '../../../domain/entities/launch_image_gallery.dart';

class LaunchImageGalleryService {
  LaunchImageGalleryService({SharedPreferences? preferences})
    : _preferencesFuture =
          preferences == null
              ? SharedPreferences.getInstance()
              : Future.value(preferences);

  final Future<SharedPreferences> _preferencesFuture;

  static const Uuid _uuid = Uuid();
  static const String _galleriesKey = 'launchImageGallery.galleries';
  static const String _activeGalleryIdKey = 'launchImageGallery.activeId';

  Future<List<LaunchImageGallery>> loadGalleries() async {
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
      final resolver = ManagedFilePathResolver();
      var changed = false;
      final normalizedGalleries = <LaunchImageGallery>[];
      for (final gallery in galleries) {
        final normalizedPaths = <String>[];
        for (final path in gallery.imagePaths) {
          final normalized =
              await resolver.normalizePersistedFilePath(path) ?? path;
          normalizedPaths.add(normalized);
          if (normalized != path) {
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
      return const <LaunchImageGallery>[];
    }
  }

  Future<void> saveGalleries(List<LaunchImageGallery> galleries) async {
    final prefs = await _preferencesFuture;
    if (galleries.isEmpty) {
      await prefs.remove(_galleriesKey);
      return;
    }
    await prefs.setString(
      _galleriesKey,
      jsonEncode(
        galleries.map((item) => item.toJson()).toList(growable: false),
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

  Future<LaunchImageGallery?> loadActiveGallery() async {
    final activeId = await loadActiveGalleryId();
    if (activeId == null) {
      return null;
    }
    return loadGallery(activeId);
  }

  Future<String?> loadActiveLaunchImagePath() async {
    final gallery = await loadActiveGallery();
    return resolveGalleryPreviewPath(gallery);
  }

  Future<String?> loadLaunchImagePathForGallery(String? galleryId) async {
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
    await saveGallery(gallery.copyWith(name: normalized));
  }

  Future<void> deleteGallery(String galleryId) async {
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
    final extension = _normalizeFileExtension(fileName);
    final directory = await _galleryDirectory(galleryId);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    final targetPath = p.join(
      directory.path,
      'launch_${DateTime.now().millisecondsSinceEpoch}.$extension',
    );
    await File(targetPath).writeAsBytes(bytes, flush: true);
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

    final normalizedTargets =
        paths
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toSet();

    for (final path in normalizedTargets) {
      await evictFileImagePath(path);
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }

    final updatedPaths = gallery.imagePaths
        .where((path) => !normalizedTargets.contains(path))
        .toList(growable: false);

    return saveGallery(gallery.copyWith(imagePaths: updatedPaths));
  }

  Future<Directory> _galleryDirectory(String galleryId) async {
    final documents = await getApplicationDocumentsDirectory();
    return Directory(
      p.join(documents.path, 'launch_image_galleries', galleryId),
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
      if (file.existsSync()) {
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

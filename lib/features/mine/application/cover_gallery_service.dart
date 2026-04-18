import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../app/images/file_image_cache.dart';
import '../../../domain/entities/cover_gallery.dart';

class CoverGalleryService {
  CoverGalleryService({SharedPreferences? preferences})
    : _preferencesFuture =
          preferences == null
              ? SharedPreferences.getInstance()
              : Future.value(preferences);

  final Future<SharedPreferences> _preferencesFuture;

  static const Uuid _uuid = Uuid();
  static const String _galleriesKey = 'coverGallery.galleries';

  Future<List<CoverGallery>> loadGalleries() async {
    final prefs = await _preferencesFuture;
    final raw = prefs.getString(_galleriesKey);
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
      return galleries;
    } catch (_) {
      return const <CoverGallery>[];
    }
  }

  Future<void> saveGalleries(List<CoverGallery> galleries) async {
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
    final directory = await _galleryDirectory(galleryId);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    final targetPath = p.join(
      directory.path,
      'cover_${DateTime.now().millisecondsSinceEpoch}.$extension',
    );
    await File(targetPath).writeAsBytes(bytes, flush: true);
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
    return Directory(p.join(documents.path, 'cover_galleries', galleryId));
  }

  String _normalizeFileExtension(String fileName) {
    final extension = p.extension(fileName).replaceFirst('.', '').trim();
    if (extension.isEmpty) {
      return 'png';
    }
    return extension.toLowerCase();
  }
}

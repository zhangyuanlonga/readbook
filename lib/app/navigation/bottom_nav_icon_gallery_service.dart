import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'bottom_nav_icon_gallery_defaults.dart';
import '../../domain/entities/bottom_nav_icon_gallery.dart';

class BottomNavIconGalleryService {
  BottomNavIconGalleryService({SharedPreferences? preferences})
    : _preferencesFuture =
          preferences == null
              ? SharedPreferences.getInstance()
              : Future.value(preferences);

  final Future<SharedPreferences> _preferencesFuture;

  static const String _galleriesKey = 'bottomNavIconGallery.galleries';
  static const String _activeGalleryIdKey = 'bottomNavIconGallery.activeId';

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
      return List<BottomNavIconGallery>.unmodifiable(<BottomNavIconGallery>[
        ...builtInBottomNavIconGalleries,
        ...customGalleries.where(
          (gallery) =>
              !builtInBottomNavIconGalleries.any(
                (builtIn) => builtIn.id == gallery.id,
              ),
        ),
      ]);
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
        customGalleries.map((item) => item.toJson()).toList(growable: false),
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
}

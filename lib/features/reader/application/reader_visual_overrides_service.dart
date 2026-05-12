import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/storage/managed_asset_store.dart';
import '../../../domain/entities/reader_visual_overrides.dart';

class ReaderVisualOverridesService {
  ReaderVisualOverridesService({
    SharedPreferences? preferences,
    ManagedAssetStore? assetStore,
  }) : _preferencesFuture =
           preferences == null
               ? SharedPreferences.getInstance()
               : Future.value(preferences),
       _assetStore = assetStore ?? ManagedAssetStore();

  static const String _visualOverridesKey = 'reader.visualOverrides';

  final Future<SharedPreferences> _preferencesFuture;
  final ManagedAssetStore _assetStore;

  Future<ReaderVisualOverrides> loadOverrides() async {
    final prefs = await _preferencesFuture;
    final raw = prefs.getString(_visualOverridesKey);
    if (raw == null || raw.trim().isEmpty) {
      return ReaderVisualOverrides.empty;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return ReaderVisualOverrides.empty;
      }
      final parsed = ReaderVisualOverrides.fromJson(
        decoded.map((key, value) => MapEntry(key.toString(), value)),
      );
      return parsed.copyWith(
        backgroundImageBase64: await _assetStore.resolvePersistedPath(
          parsed.backgroundImageBase64,
        ),
        fontFamilyKey: parsed.fontFamilyKey,
        customFontPath: await _assetStore.resolvePersistedPath(
          parsed.customFontPath,
        ),
      );
    } catch (_) {
      return ReaderVisualOverrides.empty;
    }
  }

  Future<void> saveOverrides(ReaderVisualOverrides overrides) async {
    final prefs = await _preferencesFuture;
    if (overrides.isEmpty) {
      await prefs.remove(_visualOverridesKey);
      return;
    }
    final normalized = overrides.copyWith(
      backgroundImageBase64:
          await _assetStore.relativizePersistedPath(
            overrides.backgroundImageBase64,
          ) ??
          overrides.backgroundImageBase64,
      customFontPath:
          await _assetStore.relativizePersistedPath(overrides.customFontPath) ??
          overrides.customFontPath,
    );
    await prefs.setString(_visualOverridesKey, jsonEncode(normalized.toJson()));
  }
}

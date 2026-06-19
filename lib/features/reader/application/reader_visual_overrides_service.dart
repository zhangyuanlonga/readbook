import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/preferences/preference_repair_service.dart';
import '../../../core/storage/managed_asset_store.dart';
import '../../../domain/entities/reader_visual_overrides.dart';

class ReaderVisualOverridesStorageStats {
  const ReaderVisualOverridesStorageStats({
    required this.entries,
    required this.bytes,
    required this.version,
  });

  final int entries;
  final int bytes;
  final int version;
}

class ReaderVisualOverridesService implements PreferenceRepairService {
  ReaderVisualOverridesService({
    SharedPreferences? preferences,
    ManagedAssetStore? assetStore,
  }) : _preferencesFuture =
           preferences == null
               ? SharedPreferences.getInstance()
               : Future.value(preferences),
       _assetStore = assetStore ?? ManagedAssetStore();

  static const String _visualOverridesKey = 'reader.visualOverrides';
  static const int storageSchemaVersion = 1;

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

  Future<ReaderVisualOverridesStorageStats> loadStorageStats() async {
    final prefs = await _preferencesFuture;
    final raw = prefs.getString(_visualOverridesKey);
    final bytes = raw == null ? 0 : utf8.encode(raw).length;
    return ReaderVisualOverridesStorageStats(
      entries: raw == null || raw.trim().isEmpty ? 0 : 1,
      bytes: bytes,
      version: storageSchemaVersion,
    );
  }

  @override
  Future<List<String>> repairInvalidStoredData() async {
    final prefs = await _preferencesFuture;
    final raw = prefs.getString(_visualOverridesKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <String>[];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        await prefs.remove(_visualOverridesKey);
        return const <String>[_visualOverridesKey];
      }
      ReaderVisualOverrides.fromJson(
        decoded.map((key, value) => MapEntry(key.toString(), value)),
      );
      return const <String>[];
    } catch (_) {
      await prefs.remove(_visualOverridesKey);
      return const <String>[_visualOverridesKey];
    }
  }
}

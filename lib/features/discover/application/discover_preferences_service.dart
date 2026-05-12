import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'explore_service.dart';

class DiscoverPreferencesService {
  DiscoverPreferencesService({SharedPreferences? preferences})
    : _preferencesFuture =
          preferences == null
              ? SharedPreferences.getInstance()
              : Future.value(preferences);

  static const String _selectedSourceIdKey = 'discover.selectedSourceId';
  static const String _sourceSnapshotKey = 'discover.sourceSnapshot.v1';
  static const String _categorySnapshotPrefix =
      'discover.categorySnapshot.v1.';

  final Future<SharedPreferences> _preferencesFuture;

  Future<String?> loadSelectedSourceId() async {
    final prefs = await _preferencesFuture;
    final raw = prefs.getString(_selectedSourceIdKey);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    return raw.trim();
  }

  Future<void> saveSelectedSourceId(String? sourceId) async {
    final prefs = await _preferencesFuture;
    final normalized = sourceId?.trim() ?? '';
    if (normalized.isEmpty) {
      await prefs.remove(_selectedSourceIdKey);
      return;
    }
    await prefs.setString(_selectedSourceIdKey, normalized);
  }

  Future<List<DiscoverSource>> loadSourceSnapshot() async {
    final prefs = await _preferencesFuture;
    final raw = (prefs.getString(_sourceSnapshotKey) ?? '').trim();
    if (raw.isEmpty) {
      return const <DiscoverSource>[];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <DiscoverSource>[];
      }
      return decoded
          .whereType<Map>()
          .map(
            (item) => DiscoverSource(
              id: (item['id']?.toString() ?? '').trim(),
              name: (item['name']?.toString() ?? '').trim(),
              baseUrl: (item['baseUrl']?.toString() ?? '').trim(),
              group: _optionalString(item['group']),
              sourceType: _optionalInt(item['sourceType']) ?? 0,
            ),
          )
          .where((item) => item.id.isNotEmpty && item.name.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const <DiscoverSource>[];
    }
  }

  Future<void> saveSourceSnapshot(List<DiscoverSource> sources) async {
    final prefs = await _preferencesFuture;
    if (sources.isEmpty) {
      await prefs.remove(_sourceSnapshotKey);
      return;
    }

    final payload = <Map<String, Object?>>[
      for (final source in sources)
        <String, Object?>{
          'id': source.id,
          'name': source.name,
          'baseUrl': source.baseUrl,
          'group': source.group,
          'sourceType': source.sourceType,
        },
    ];
    await prefs.setString(_sourceSnapshotKey, jsonEncode(payload));
  }

  Future<List<ExploreCategoryItem>> loadCategorySnapshot(String sourceId) async {
    final normalizedSourceId = sourceId.trim();
    if (normalizedSourceId.isEmpty) {
      return const <ExploreCategoryItem>[];
    }

    final prefs = await _preferencesFuture;
    final raw =
        (prefs.getString('$_categorySnapshotPrefix$normalizedSourceId') ?? '')
            .trim();
    if (raw.isEmpty) {
      return const <ExploreCategoryItem>[];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <ExploreCategoryItem>[];
      }
      return decoded
          .whereType<Map>()
          .map(
            (item) => ExploreCategoryItem(
              title: (item['title']?.toString() ?? '').trim(),
              url: _optionalString(item['url']),
              style: ExploreCategoryStyle(
                layoutFlexGrow: _optionalDouble(item['layoutFlexGrow']),
                layoutFlexBasisPercent: _optionalDouble(
                  item['layoutFlexBasisPercent'],
                ),
              ),
              extra: _jsonSafeMap(item['extra']),
            ),
          )
          .where((item) => item.title.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const <ExploreCategoryItem>[];
    }
  }

  Future<void> saveCategorySnapshot(
    String sourceId,
    List<ExploreCategoryItem> categories,
  ) async {
    final normalizedSourceId = sourceId.trim();
    if (normalizedSourceId.isEmpty) {
      return;
    }

    final prefs = await _preferencesFuture;
    final key = '$_categorySnapshotPrefix$normalizedSourceId';
    if (categories.isEmpty) {
      await prefs.remove(key);
      return;
    }

    final payload = <Map<String, Object?>>[
      for (final category in categories)
        <String, Object?>{
          'title': category.title,
          'url': category.url,
          'layoutFlexGrow': category.style.layoutFlexGrow,
          'layoutFlexBasisPercent': category.style.layoutFlexBasisPercent,
          'extra': _jsonSafeMap(category.extra),
        },
    ];
    await prefs.setString(key, jsonEncode(payload));
  }

  String? _optionalString(Object? value) {
    final normalized = value?.toString().trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }

  int? _optionalInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.round();
    }
    return int.tryParse(value?.toString() ?? '');
  }

  double? _optionalDouble(Object? value) {
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '');
  }

  Map<String, dynamic> _jsonSafeMap(Object? value) {
    if (value is! Map) {
      return const <String, dynamic>{};
    }
    return value.map(
      (key, item) => MapEntry(
        key.toString(),
        _jsonSafeValue(item),
      ),
    );
  }

  Object? _jsonSafeValue(Object? value) {
    if (value == null || value is String || value is num || value is bool) {
      return value;
    }
    if (value is List) {
      return value.map(_jsonSafeValue).toList(growable: false);
    }
    if (value is Map) {
      return _jsonSafeMap(value);
    }
    return value.toString();
  }
}

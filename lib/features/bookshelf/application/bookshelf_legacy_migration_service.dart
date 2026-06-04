import 'dart:convert';
import 'dart:isolate';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../data/datasources/local/app_database.dart';
import '../../../domain/entities/bookshelf_book.dart';

final class BookshelfLegacyMigrationKeys {
  const BookshelfLegacyMigrationKeys({
    required this.books,
    required this.tagMap,
    required this.tagOrder,
    required this.tagMetadata,
    required this.categoryOrder,
    required this.categoryMetadata,
    required this.baseFilterOrder,
  });

  final String books;
  final String tagMap;
  final String tagOrder;
  final String tagMetadata;
  final String categoryOrder;
  final String categoryMetadata;
  final String baseFilterOrder;
}

/// 书架旧 SharedPreferences 快照迁移服务。
///
/// 这里只负责把旧 `bookshelf.*` 聚合 JSON 读取、归一化并写入 Drift 快照。
/// `BookshelfService` 继续负责正常业务读写；这样后续清理 legacy key、补迁移测试、
/// 或把迁移任务放到启动队列时，不需要继续扩大主服务职责。
final class BookshelfLegacyMigrationService {
  const BookshelfLegacyMigrationService({
    required SharedPreferences preferences,
    required AppDatabase database,
    required BookshelfLegacyMigrationKeys keys,
  }) : _preferences = preferences,
       _database = database,
       _keys = keys;

  final SharedPreferences _preferences;
  final AppDatabase _database;
  final BookshelfLegacyMigrationKeys _keys;

  Future<void> migrateIfNeeded() async {
    final existingBooks = await _database.listBookshelfBooks();
    final existingTags = await _database.listBookshelfTagAssignments();
    final existingTagMetadata = await _database.listBookshelfTagMetadata();
    final existingCategoryMetadata =
        await _database.listBookshelfCategoryMetadata();
    final existingBaseFilters = await _database.listBookshelfBaseFilterOrders();
    if (existingBooks.isNotEmpty ||
        existingTags.isNotEmpty ||
        existingTagMetadata.isNotEmpty ||
        existingCategoryMetadata.isNotEmpty ||
        existingBaseFilters.isNotEmpty) {
      return;
    }

    final legacyBooks = await _loadLegacyBooks();
    final legacyTagMap = await _loadLegacyTagMap();
    final legacyTagItems = _loadLegacyTaxonomyItems(
      metadataKey: _keys.tagMetadata,
      orderKey: _keys.tagOrder,
    );
    final legacyCategoryItems = _loadLegacyTaxonomyItems(
      metadataKey: _keys.categoryMetadata,
      orderKey: _keys.categoryOrder,
    );
    final legacyBaseFilterOrder = _loadLegacyStringList(_keys.baseFilterOrder);
    if (legacyBooks.isEmpty &&
        legacyTagMap.isEmpty &&
        legacyTagItems.isEmpty &&
        legacyCategoryItems.isEmpty &&
        legacyBaseFilterOrder.isEmpty) {
      return;
    }

    await _database.replaceBookshelfSnapshot(
      books: legacyBooks,
      tagMap: legacyTagMap,
      tagItems: legacyTagItems
          .map(
            (item) => BookshelfTaxonomySnapshotItem(
              name: item.name,
              colorValue: item.colorValue,
            ),
          )
          .toList(growable: false),
      categoryItems: legacyCategoryItems
          .map(
            (item) => BookshelfTaxonomySnapshotItem(
              name: item.name,
              colorValue: item.colorValue,
            ),
          )
          .toList(growable: false),
      baseFilterOrder: legacyBaseFilterOrder,
    );
    await _clearLegacyPrefs();
  }

  Future<List<BookshelfBook>> _loadLegacyBooks() async {
    final raw = _preferences.getString(_keys.books);
    if (raw == null || raw.trim().isEmpty) {
      return const <BookshelfBook>[];
    }

    try {
      final decoded = await Isolate.run<List<Map<String, Object?>>?>(
        () => _decodeBookshelfBookJsonMaps(raw),
      );
      if (decoded == null) {
        return const <BookshelfBook>[];
      }

      final items = decoded
          .map((item) => BookshelfBook.fromJson(item))
          .toList(growable: false);
      return items.reversed.toList(growable: false);
    } on FormatException {
      return const <BookshelfBook>[];
    }
  }

  Future<Map<String, List<String>>> _loadLegacyTagMap() async {
    final raw = _preferences.getString(_keys.tagMap);
    if (raw == null || raw.trim().isEmpty) {
      return const <String, List<String>>{};
    }

    try {
      return await Isolate.run<Map<String, List<String>>>(
        () => _decodeBookshelfTagMap(raw),
      );
    } catch (_) {
      return const <String, List<String>>{};
    }
  }

  List<_LegacyBookshelfTaxonomyItem> _loadLegacyTaxonomyItems({
    required String metadataKey,
    required String orderKey,
  }) {
    final raw = _preferences.getString(metadataKey);
    final byName = <String, _LegacyBookshelfTaxonomyItem>{};
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final item in decoded) {
            final parsed = _LegacyBookshelfTaxonomyItem.fromJson(item);
            if (parsed == null) {
              continue;
            }
            byName[parsed.name] = parsed;
          }
        }
      } catch (_) {
        // 旧 metadata 损坏时继续尝试 order payload，避免迁移整批失败。
      }
    }
    for (final name in _loadLegacyStringList(orderKey)) {
      byName.putIfAbsent(
        name,
        () => _LegacyBookshelfTaxonomyItem(
          name: name,
          colorValue: _defaultColorForName(name),
        ),
      );
    }
    return List<_LegacyBookshelfTaxonomyItem>.unmodifiable(byName.values);
  }

  List<String> _loadLegacyStringList(String key) {
    final raw = _preferences.getString(key);
    if (raw == null || raw.trim().isEmpty) {
      return const <String>[];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <String>[];
      }
      return _normalizeStringList(decoded.map((value) => '$value'));
    } catch (_) {
      return const <String>[];
    }
  }

  Future<void> _clearLegacyPrefs() async {
    await _preferences.remove(_keys.books);
    await _preferences.remove(_keys.tagMap);
    await _preferences.remove(_keys.tagOrder);
    await _preferences.remove(_keys.tagMetadata);
    await _preferences.remove(_keys.categoryOrder);
    await _preferences.remove(_keys.categoryMetadata);
    await _preferences.remove(_keys.baseFilterOrder);
  }
}

final class _LegacyBookshelfTaxonomyItem {
  const _LegacyBookshelfTaxonomyItem({
    required this.name,
    required this.colorValue,
  });

  final String name;
  final int colorValue;

  static _LegacyBookshelfTaxonomyItem? fromJson(Object? value) {
    if (value is String) {
      final name = value.trim();
      return name.isEmpty
          ? null
          : _LegacyBookshelfTaxonomyItem(
            name: name,
            colorValue: _defaultColorForName(name),
          );
    }
    if (value is! Map) {
      return null;
    }
    final name = value['name']?.toString().trim() ?? '';
    if (name.isEmpty) {
      return null;
    }
    final rawColor = value['colorValue'];
    final colorValue =
        rawColor is int
            ? rawColor
            : int.tryParse(rawColor?.toString() ?? '') ??
                _defaultColorForName(name);
    return _LegacyBookshelfTaxonomyItem(name: name, colorValue: colorValue);
  }
}

List<Map<String, Object?>>? _decodeBookshelfBookJsonMaps(String raw) {
  final decoded = jsonDecode(raw);
  if (decoded is! List) {
    return null;
  }
  return decoded
      .whereType<Map>()
      .map(
        (item) => <String, Object?>{
          for (final entry in item.entries) entry.key.toString(): entry.value,
        },
      )
      .toList(growable: false);
}

Map<String, List<String>> _decodeBookshelfTagMap(String raw) {
  final decoded = jsonDecode(raw);
  if (decoded is! Map) {
    return const <String, List<String>>{};
  }

  final result = <String, List<String>>{};
  for (final entry in decoded.entries) {
    final key = entry.key.toString().trim();
    if (key.isEmpty || entry.value is! List) {
      continue;
    }
    final tags = _normalizeStringList(
      (entry.value as List).map((value) => '$value'),
    );
    if (tags.isEmpty) {
      continue;
    }
    result[key] = tags;
  }
  return result;
}

List<String> _normalizeStringList(Iterable<String> values) {
  final result = <String>[];
  for (final raw in values) {
    final value = raw.trim();
    if (value.isEmpty) {
      continue;
    }
    if (!result.contains(value)) {
      result.add(value);
    }
  }
  return result;
}

int _defaultColorForName(String name) {
  const palette = <int>[
    0xFF6750A4,
    0xFF386A20,
    0xFF006A6A,
    0xFF006D3B,
    0xFF984061,
    0xFF8C5000,
    0xFF6D5E00,
    0xFF00658F,
    0xFF7D5260,
    0xFF5B5D72,
  ];
  final normalized = name.trim();
  if (normalized.isEmpty) {
    return palette.first;
  }
  var hash = 0;
  for (final codeUnit in normalized.codeUnits) {
    hash = (hash * 31 + codeUnit) & 0x7fffffff;
  }
  return palette[hash % palette.length];
}

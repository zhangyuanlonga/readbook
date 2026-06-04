import 'dart:convert';

/// 书架标签 / 分类元数据。
///
/// 这里是纯值对象，既不访问数据库也不访问偏好设置。放在独立文件后，
/// `BookshelfService` 可以继续作为编排层，后续 taxonomy service 深拆时也能复用
/// 同一套名称归一化和默认颜色规则。
class BookshelfTaxonomyItem {
  const BookshelfTaxonomyItem({required this.name, required this.colorValue});

  final String name;
  final int colorValue;

  BookshelfTaxonomyItem copyWith({String? name, int? colorValue}) {
    return BookshelfTaxonomyItem(
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'name': name,
    'colorValue': colorValue,
  };

  static BookshelfTaxonomyItem? fromJson(Object? value) {
    if (value is String) {
      final name = value.trim();
      return name.isEmpty
          ? null
          : BookshelfTaxonomyItem(
            name: name,
            colorValue: defaultColorForName(name),
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
                defaultColorForName(name);
    return BookshelfTaxonomyItem(name: name, colorValue: colorValue);
  }

  static int defaultColorForName(String name) {
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
}

/// 书架标签 / 分类旧 JSON payload 解析服务。
///
/// 旧版本把标签、分类顺序和元数据分别写在 SharedPreferences JSON 字符串里。
/// 这个服务只处理“字符串 payload -> 规范化值”的转换，方便后续继续把
/// taxonomy 的数据库写入、重命名、删除等业务从 `BookshelfService` 拆出去。
final class BookshelfTaxonomyService {
  const BookshelfTaxonomyService();

  List<BookshelfTaxonomyItem> loadItems({
    required String? metadataRaw,
    required String? orderRaw,
  }) {
    final byName = <String, BookshelfTaxonomyItem>{};
    if (metadataRaw != null && metadataRaw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(metadataRaw);
        if (decoded is List) {
          for (final item in decoded) {
            final parsed = BookshelfTaxonomyItem.fromJson(item);
            if (parsed == null) {
              continue;
            }
            byName[parsed.name] = parsed;
          }
        }
      } catch (_) {
        // 元数据损坏时继续尝试旧顺序列表，尽量保留用户已有标签 / 分类名。
      }
    }

    for (final name in decodeStringList(orderRaw)) {
      byName.putIfAbsent(
        name,
        () => BookshelfTaxonomyItem(
          name: name,
          colorValue: BookshelfTaxonomyItem.defaultColorForName(name),
        ),
      );
    }

    return List<BookshelfTaxonomyItem>.unmodifiable(byName.values);
  }

  List<String> decodeStringList(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return const <String>[];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <String>[];
      }
      return normalizeNames(decoded.map((value) => '$value'));
    } catch (_) {
      return const <String>[];
    }
  }

  static Map<String, List<String>> decodeTagMapPayload(String raw) {
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
      final tags = normalizeNames(
        (entry.value as List).map((value) => '$value'),
      );
      if (tags.isEmpty) {
        continue;
      }
      result[key] = tags;
    }
    return result;
  }

  static List<String> normalizeNames(Iterable<String> values) {
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
}

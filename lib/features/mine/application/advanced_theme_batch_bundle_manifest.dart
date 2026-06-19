import 'dart:convert';

import 'package:archive/archive_io.dart';

class AdvancedThemeBatchBundleManifest {
  const AdvancedThemeBatchBundleManifest({required this.themes});

  static const String type = 'advanced_theme_batch_bundle';
  static const int version = 1;
  static const String manifestFileName = 'manifest.json';

  final List<AdvancedThemeBatchBundleEntry> themes;

  static bool isBatchBundleArchive(Archive archive) {
    try {
      final manifestFile = archive.findFile(manifestFileName);
      if (manifestFile == null) {
        return false;
      }
      final decoded = jsonDecode(
        utf8.decode(_archiveFileBytes(manifestFile), allowMalformed: true),
      );
      if (decoded is! Map) {
        return false;
      }
      final manifest = decoded.map(
        (key, value) => MapEntry(key.toString(), value),
      );
      return manifest['type']?.toString().trim() == type;
    } catch (_) {
      return false;
    }
  }

  factory AdvancedThemeBatchBundleManifest.parseArchive(Archive archive) {
    final manifestFile = archive.findFile(manifestFileName);
    if (manifestFile == null) {
      throw const FormatException('批量主题包缺少 manifest.json。');
    }
    final decoded = jsonDecode(
      utf8.decode(_archiveFileBytes(manifestFile), allowMalformed: true),
    );
    if (decoded is! Map) {
      throw const FormatException('批量主题包配置无效。');
    }
    final manifest = decoded.map(
      (key, value) => MapEntry(key.toString(), value),
    );
    final normalizedType = manifest['type']?.toString().trim() ?? '';
    if (normalizedType != type) {
      throw const FormatException('不支持的批量主题包类型。');
    }
    final rawVersion = manifest['version'];
    final normalizedVersion =
        rawVersion is num ? rawVersion.toInt() : int.tryParse('$rawVersion');
    if (normalizedVersion != version) {
      throw const FormatException('不支持的批量主题包版本。');
    }

    final entries = manifest['themes'];
    if (entries is! List || entries.isEmpty) {
      throw const FormatException('批量主题包中没有可导入的主题。');
    }
    final themes = entries
        .whereType<Map>()
        .map((item) {
          final entry = item.map(
            (key, value) => MapEntry(key.toString(), value),
          );
          return AdvancedThemeBatchBundleEntry(
            id: entry['id']?.toString().trim() ?? '',
            name: entry['name']?.toString().trim() ?? '',
            file: entry['file']?.toString().trim() ?? '',
          );
        })
        .toList(growable: false);
    return AdvancedThemeBatchBundleManifest(themes: themes);
  }

  static List<int> encode({
    required DateTime generatedAt,
    required List<AdvancedThemeBatchBundleEntry> themes,
  }) {
    final manifest = <String, Object?>{
      'type': type,
      'version': version,
      'generatedAt': generatedAt.toIso8601String(),
      'themes': themes.map((entry) => entry.toJson()).toList(growable: false),
    };
    return utf8.encode(const JsonEncoder.withIndent('  ').convert(manifest));
  }

  static List<int> _archiveFileBytes(ArchiveFile file) {
    return List<int>.from(file.content);
  }
}

class AdvancedThemeBatchBundleEntry {
  const AdvancedThemeBatchBundleEntry({
    required this.id,
    required this.name,
    required this.file,
  });

  final String id;
  final String name;
  final String file;

  Map<String, Object?> toJson() {
    return <String, Object?>{'id': id, 'name': name, 'file': file};
  }
}

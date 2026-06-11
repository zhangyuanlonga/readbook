import 'dart:convert';

const int defaultBookSourcePreviewLineLimit = 100;

BookSourceImportPayload parseBookSourceImportPayload(String value) {
  return BookSourceImportPayload.fromJsonText(value);
}

class BookSourceImportPayload {
  const BookSourceImportPayload({
    required this.sourceJson,
    required this.previewText,
    required this.lineCount,
    required this.sizeBytes,
    required this.suggestedName,
    required this.suggestedDescription,
    required this.suggestedGroupName,
  });

  final String sourceJson;
  final String previewText;
  final int lineCount;
  final int sizeBytes;
  final String suggestedName;
  final String suggestedDescription;
  final String suggestedGroupName;

  factory BookSourceImportPayload.fromJsonText(
    String value, {
    int previewLineLimit = defaultBookSourcePreviewLineLimit,
  }) {
    final sourceJson = value.trim();
    if (sourceJson.isEmpty) {
      throw const FormatException('书源 JSON 为空');
    }
    late final Object? decoded;
    try {
      decoded = jsonDecode(sourceJson);
    } on FormatException {
      throw const FormatException('JSON 格式不正确');
    }
    final primary = _primaryJsonMap(decoded);
    return BookSourceImportPayload(
      sourceJson: sourceJson,
      previewText: buildBookSourcePreview(
        sourceJson,
        lineLimit: previewLineLimit,
      ),
      lineCount: countBookSourceLines(sourceJson),
      sizeBytes: bookSourceUtf8SizeOf(sourceJson),
      suggestedName: _firstString(primary, const <String>[
        'name',
        'bookSourceName',
        'book_source_name',
        'sourceName',
        'source_name',
        'title',
      ]),
      suggestedDescription: _firstString(primary, const <String>[
        'description',
        'desc',
        'bookSourceComment',
        'book_source_comment',
        'comment',
      ]),
      suggestedGroupName: _firstGroupName(primary),
    );
  }
}

String buildBookSourcePreview(
  String value, {
  int lineLimit = defaultBookSourcePreviewLineLimit,
}) {
  final lines = const LineSplitter().convert(value.trim());
  if (lines.isEmpty) {
    return '';
  }
  if (lines.length <= lineLimit) {
    return lines.join('\n');
  }
  final omitted = lines.length - lineLimit;
  return <String>[...lines.take(lineLimit), '... 已省略 $omitted 行'].join('\n');
}

int countBookSourceLines(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    return 0;
  }
  return const LineSplitter().convert(normalized).length;
}

int bookSourceUtf8SizeOf(String value) => utf8.encode(value.trim()).length;

String formatBookSourceSize(int bytes) {
  if (bytes < 1024) {
    return '$bytes B';
  }
  final kb = bytes / 1024;
  if (kb < 1024) {
    return '${kb.toStringAsFixed(kb >= 100 ? 0 : 1)} KB';
  }
  final mb = kb / 1024;
  return '${mb.toStringAsFixed(mb >= 100 ? 0 : 1)} MB';
}

Map<String, Object?>? _primaryJsonMap(Object? decoded) {
  if (decoded is Map) {
    return decoded.map((key, value) => MapEntry(key.toString(), value));
  }
  if (decoded is List) {
    for (final item in decoded) {
      final map = _primaryJsonMap(item);
      if (map != null) {
        return map;
      }
    }
  }
  return null;
}

String _firstString(Map<String, Object?>? map, List<String> keys) {
  if (map == null) {
    return '';
  }
  for (final key in keys) {
    final value = map[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
  }
  return '';
}

String _firstGroupName(Map<String, Object?>? map) {
  if (map == null) {
    return '';
  }
  return _firstGroupValue(map['bookSourceGroup']) ??
      _firstGroupValue(map['book_source_group']) ??
      _firstGroupValue(map['group']) ??
      _firstGroupValue(map['group_name']) ??
      '';
}

String? _firstGroupValue(Object? value) {
  if (value is String) {
    return _firstGroupSegment(value);
  }
  if (value is List) {
    for (final item in value) {
      final group = _firstGroupValue(item);
      if (group != null && group.isNotEmpty) {
        return group;
      }
    }
  }
  return null;
}

String _firstGroupSegment(String value) {
  final parts = value.split(RegExp(r'[,，;；|/\n\t]'));
  for (final part in parts) {
    final normalized = part.trim();
    if (normalized.isNotEmpty) {
      return normalized;
    }
  }
  return value.trim();
}

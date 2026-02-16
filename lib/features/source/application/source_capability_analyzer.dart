import '../../../domain/entities/source_definition.dart';

enum SourceCompatibilityLevel { full, partial, unsupported }

class SourceCapabilityProfile {
  const SourceCapabilityProfile({
    required this.sourceType,
    required this.usesJs,
    required this.usesReload,
    required this.imageContent,
  });

  final int sourceType;
  final bool usesJs;
  final bool usesReload;
  final bool imageContent;

  bool get isManga => sourceType == 2;

  SourceCompatibilityLevel get compatibilityLevel {
    if (usesReload) {
      return SourceCompatibilityLevel.unsupported;
    }

    if (usesJs) {
      return SourceCompatibilityLevel.partial;
    }

    return SourceCompatibilityLevel.full;
  }

  String get compatibilityLabel {
    return switch (compatibilityLevel) {
      SourceCompatibilityLevel.full => '完全兼容',
      SourceCompatibilityLevel.partial => '部分兼容',
      SourceCompatibilityLevel.unsupported => '暂不兼容',
    };
  }

  List<String> get reasons {
    final output = <String>[];

    if (usesReload) {
      output.add('规则依赖 Reload(...) 远程脚本，当前版本暂不支持。');
    }
    if (usesJs) {
      output.add('规则包含 JS 表达式（<js>/js:），当前为部分兼容，请优先做连通性测试。');
    }

    return output;
  }
}

class SourceCapabilityAnalyzer {
  const SourceCapabilityAnalyzer._();

  static SourceCapabilityProfile fromRawMap(Map<String, dynamic> raw) {
    final sourceType = _asInt(raw['bookSourceType']) ?? 0;
    final texts = <String>[];
    _collectStrings(raw, texts);

    final usesJs = texts.any(_containsJsPattern);
    final usesReload = texts.any(_containsReloadPattern);
    final imageContent = _resolveImageContent(raw, sourceType, texts);

    return SourceCapabilityProfile(
      sourceType: sourceType,
      usesJs: usesJs,
      usesReload: usesReload,
      imageContent: imageContent,
    );
  }

  static SourceCapabilityProfile fromSource(SourceDefinition source) {
    final payload = {
      'sourceType': source.sourceType,
      'baseUrl': source.baseUrl,
      'headers': source.headers,
      'rules': source.rules.toJson(),
      'group': source.group,
      'comment': source.comment,
    };
    final texts = <String>[];
    _collectStrings(payload, texts);

    final usesJs = texts.any(_containsJsPattern);
    final usesReload = texts.any(_containsReloadPattern);
    final imageContent = _resolveImageContent(
      {
        'ruleContent': source.rules.contentRule,
        'sourceType': source.sourceType,
      },
      source.sourceType,
      texts,
    );

    return SourceCapabilityProfile(
      sourceType: source.sourceType,
      usesJs: usesJs,
      usesReload: usesReload,
      imageContent: imageContent,
    );
  }

  static bool _resolveImageContent(
    Map<String, dynamic> raw,
    int sourceType,
    List<String> texts,
  ) {
    if (sourceType == 2) {
      return true;
    }

    final content = raw['ruleContent'];
    if (content is Map) {
      final imageStyle = content['imageStyle']?.toString().trim().toLowerCase();
      if (imageStyle != null && imageStyle.isNotEmpty) {
        return imageStyle.contains('full') || imageStyle.contains('image');
      }
    }

    return texts.any((text) {
      final normalized = text.toLowerCase();
      return normalized.contains('imagestyle') || normalized.contains('@src');
    });
  }

  static bool _containsJsPattern(String value) {
    final normalized = value.toLowerCase();
    return normalized.contains('<js>') ||
        normalized.contains('@js:') ||
        normalized.startsWith('js:') ||
        normalized.contains(' js:');
  }

  static bool _containsReloadPattern(String value) {
    return RegExp(r'reload\s*\(', caseSensitive: false).hasMatch(value);
  }

  static void _collectStrings(dynamic value, List<String> output) {
    if (value == null) {
      return;
    }

    if (value is String) {
      final normalized = value.trim();
      if (normalized.isNotEmpty) {
        output.add(normalized);
      }
      return;
    }

    if (value is Map) {
      for (final entry in value.entries) {
        _collectStrings(entry.key.toString(), output);
        _collectStrings(entry.value, output);
      }
      return;
    }

    if (value is Iterable) {
      for (final item in value) {
        _collectStrings(item, output);
      }
      return;
    }

    output.add(value.toString());
  }

  static int? _asInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value.trim());
    }
    return null;
  }
}

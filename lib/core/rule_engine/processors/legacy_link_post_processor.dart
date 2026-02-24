import 'legacy_script_rule_fallback.dart';

class LegacyLinkPostProcessor {
  const LegacyLinkPostProcessor._();

  static String apply({required String value, String? rawRule}) {
    final initial = _normalizeToken(value);
    if (initial == null) {
      return '';
    }

    var current = initial;

    final branches = _splitFallback(rawRule);
    for (final branch in branches) {
      final transformed = _applyBranch(current, branch);
      if (transformed != null && transformed.isNotEmpty) {
        current = transformed;
      }
    }

    final extractedFromOnclick = _extractUrlFromOnclickLike(current);
    if (extractedFromOnclick != null && extractedFromOnclick.isNotEmpty) {
      current = extractedFromOnclick;
    }

    return current;
  }

  static List<String> _splitFallback(String? rawRule) {
    final text = rawRule?.trim();
    if (text == null || text.isEmpty) {
      return const <String>[];
    }

    return text
        .split('||')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  static String? _applyBranch(String value, String rawBranch) {
    var current = value;

    final branchPrefix = _stripScriptSuffix(rawBranch);
    current = _applyReplaceDirective(current, branchPrefix);

    final script = _extractInlineScript(rawBranch);
    if (script != null && script.isNotEmpty) {
      current = _applyInlineScriptSubset(current, script);
    }

    return _normalizeToken(current);
  }

  static String _stripScriptSuffix(String source) {
    final trimmed = source.trim();
    if (trimmed.isEmpty) {
      return trimmed;
    }

    final jsIndex = trimmed.toLowerCase().indexOf('@js:');
    if (jsIndex >= 0) {
      return trimmed.substring(0, jsIndex).trim();
    }

    final blockIndex = trimmed.toLowerCase().indexOf('<js>');
    if (blockIndex >= 0) {
      return trimmed.substring(0, blockIndex).trim();
    }

    return trimmed;
  }

  static String _applyReplaceDirective(String value, String rawBranch) {
    final parts = rawBranch.split('##');
    if (parts.length < 2) {
      return value;
    }

    final pattern = parts[1].trim();
    if (pattern.isEmpty) {
      return value;
    }

    final replacement = parts.length >= 3 ? parts.sublist(2).join('##') : '';
    try {
      final regex = RegExp(pattern, dotAll: true);
      return value.replaceAllMapped(
        regex,
        (match) => _resolveRegexReplacement(replacement, match),
      );
    } on FormatException {
      return value;
    }
  }

  static String _resolveRegexReplacement(String replacement, Match match) {
    return replacement.replaceAllMapped(RegExp(r'\$(\d+)'), (groupMatch) {
      final index = int.tryParse(groupMatch.group(1) ?? '');
      if (index == null || index < 0 || index > match.groupCount) {
        return groupMatch.group(0) ?? '';
      }
      return match.group(index) ?? '';
    });
  }

  static String? _extractInlineScript(String source) {
    final trimmed = source.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final jsIndex = trimmed.toLowerCase().indexOf('@js:');
    if (jsIndex >= 0) {
      return trimmed.substring(jsIndex + 4).trim();
    }

    final blockMatch = RegExp(
      r'<js>([\s\S]*?)</js>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(trimmed);
    if (blockMatch == null) {
      return null;
    }

    return blockMatch.group(1)?.trim();
  }

  static String _applyInlineScriptSubset(String value, String script) {
    var normalizedScript = script.trim();
    if (normalizedScript.isEmpty) {
      return value;
    }

    normalizedScript = normalizedScript.replaceAll(RegExp(r'^return\s+'), '');
    normalizedScript = normalizedScript.trim();
    if (normalizedScript.endsWith(';')) {
      normalizedScript = normalizedScript.substring(
        0,
        normalizedScript.length - 1,
      );
    }

    if (normalizedScript == 'result') {
      return value;
    }

    final literal = _extractQuotedLiteral(normalizedScript);
    if (literal != null) {
      return literal;
    }

    final replaceMatch = RegExp(
      r'''^result\.replace\(\s*(['"])(.*?)\1\s*,\s*(['"])(.*?)\3\s*\)$''',
      dotAll: true,
    ).firstMatch(normalizedScript);
    if (replaceMatch != null) {
      final from = replaceMatch.group(2) ?? '';
      final to = replaceMatch.group(4) ?? '';
      return value.replaceAll(from, to);
    }

    final appendMatch = RegExp(
      r'''^result\s*\+\s*(['"])([\s\S]*)\1$''',
      dotAll: true,
    ).firstMatch(normalizedScript);
    if (appendMatch != null) {
      return value + (appendMatch.group(2) ?? '');
    }

    final prependMatch = RegExp(
      r'''^(['"])([\s\S]*)\1\s*\+\s*result$''',
      dotAll: true,
    ).firstMatch(normalizedScript);
    if (prependMatch != null) {
      return (prependMatch.group(2) ?? '') + value;
    }

    final ternaryReplaceMatch = RegExp(
      r'''^/.+?/[a-z]*\.test\(result\)\s*\?\s*result\.replace\(\s*(['"])(.*?)\1\s*,\s*(['"])(.*?)\3\s*\)\s*:\s*result$''',
      dotAll: true,
    ).firstMatch(normalizedScript);
    if (ternaryReplaceMatch != null) {
      final from = ternaryReplaceMatch.group(2) ?? '';
      final to = ternaryReplaceMatch.group(4) ?? '';
      if (from.isNotEmpty && value.contains(from)) {
        return value.replaceAll(from, to);
      }
      return value;
    }

    final advanced = LegacyScriptRuleFallback.evaluateFieldValue(
      content: value,
      rawRule: '@js:$normalizedScript',
    );
    if (advanced != null && advanced.trim().isNotEmpty) {
      return advanced;
    }

    return value;
  }

  static String? _extractQuotedLiteral(String text) {
    final single = RegExp(r"^'([\s\S]*)'$", dotAll: true).firstMatch(text);
    if (single != null) {
      return single.group(1);
    }

    final doubleQuoted = RegExp(
      r'^"([\s\S]*)"$',
      dotAll: true,
    ).firstMatch(text);
    if (doubleQuoted != null) {
      return doubleQuoted.group(1);
    }

    final backtick = RegExp(r'^`([\s\S]*)`$', dotAll: true).firstMatch(text);
    if (backtick != null) {
      return backtick.group(1);
    }

    return null;
  }

  static String? _extractUrlFromOnclickLike(String value) {
    final text = value.trim();
    if (text.isEmpty) {
      return null;
    }

    final requestSplit = _splitRequestOptions(text);
    final textWithoutOptions = requestSplit?.$1 ?? text;

    if (_looksLikeDirectUrl(textWithoutOptions)) {
      return text;
    }

    final quoted = RegExp(
      r'''['"]((?:https?:)?//[^'"]+|/[^'"]+)['"]''',
    ).firstMatch(textWithoutOptions);
    if (quoted != null) {
      final extracted = quoted.group(1)?.trim();
      if (extracted != null && extracted.isNotEmpty) {
        if (requestSplit == null) {
          return extracted;
        }
        return '$extracted,${requestSplit.$2}';
      }
    }

    return null;
  }

  static (String, String)? _splitRequestOptions(String value) {
    final trimmed = value.trim();
    final objectStart = _findTrailingObjectStart(trimmed);
    if (objectStart == null || objectStart <= 0) {
      return null;
    }

    var commaIndex = objectStart - 1;
    while (commaIndex >= 0 && RegExp(r'\s').hasMatch(trimmed[commaIndex])) {
      commaIndex -= 1;
    }
    if (commaIndex < 0 || trimmed[commaIndex] != ',') {
      return null;
    }

    final prefix = trimmed.substring(0, commaIndex).trim();
    final options = trimmed.substring(objectStart).trim();
    if (prefix.isEmpty || options.isEmpty) {
      return null;
    }

    return (prefix, options);
  }

  static int? _findTrailingObjectStart(String value) {
    var end = value.length - 1;
    while (end >= 0 && RegExp(r'\s').hasMatch(value[end])) {
      end -= 1;
    }
    if (end < 0 || value[end] != '}') {
      return null;
    }

    var depth = 0;
    var inString = false;
    var quote = '';
    var escaped = false;

    for (var index = end; index >= 0; index -= 1) {
      final char = value[index];

      if (inString) {
        if (escaped) {
          escaped = false;
          continue;
        }
        if (char == r'\') {
          escaped = true;
          continue;
        }
        if (char == quote) {
          inString = false;
          quote = '';
        }
        continue;
      }

      if (char == '"' || char == "'") {
        inString = true;
        quote = char;
        continue;
      }

      if (char == '}') {
        depth += 1;
        continue;
      }

      if (char == '{') {
        depth -= 1;
        if (depth == 0) {
          return index;
        }
      }
    }

    return null;
  }

  static bool _looksLikeDirectUrl(String source) {
    final text = source.trim().toLowerCase();
    if (text.isEmpty) {
      return false;
    }

    return text.startsWith('http://') ||
        text.startsWith('https://') ||
        text.startsWith('//') ||
        text.startsWith('/');
  }

  static String? _normalizeToken(String value) {
    var normalized = value.trim();
    if (normalized.isEmpty) {
      return null;
    }

    if ((normalized.startsWith('"') && normalized.endsWith('"')) ||
        (normalized.startsWith("'") && normalized.endsWith("'"))) {
      normalized = normalized.substring(1, normalized.length - 1).trim();
    }

    return normalized.isEmpty ? null : normalized;
  }
}

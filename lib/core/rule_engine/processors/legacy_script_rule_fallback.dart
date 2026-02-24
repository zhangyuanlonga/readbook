import 'dart:convert';

import 'legacy_rule_compat.dart';

class LegacyScriptRuleFallback {
  const LegacyScriptRuleFallback._();

  static const String fieldExpression = '__legacy_js_field_fallback__';
  static const String listExpression = '__legacy_js_list_fallback__';

  static bool isScriptOnlyRule(String? rawRule) {
    final text = rawRule?.trim();
    if (text == null || text.isEmpty) {
      return false;
    }

    final staticRule = LegacyRuleCompat.extractStaticRuleExpression(text);
    if (staticRule != null && staticRule.isNotEmpty) {
      return false;
    }

    return _extractInlineScript(text) != null;
  }

  static List<String> evaluateListChunks({
    required String content,
    String? rawRule,
  }) {
    final script = _extractInlineScript(rawRule ?? '');
    if (script == null || script.isEmpty) {
      return const <String>[];
    }

    final value = _evaluateScript(script: script, result: content);
    return _toChunkList(value);
  }

  static String? evaluateFieldValue({
    required String content,
    String? rawRule,
  }) {
    final script = _extractInlineScript(rawRule ?? '');
    if (script == null || script.isEmpty) {
      return null;
    }

    final resolvedScript = _resolveJsonPlaceholders(script, content);
    final value = _evaluateScript(script: resolvedScript, result: content);

    if (value == null) {
      return null;
    }

    if (value is String) {
      final normalized = value.trim();
      return normalized.isEmpty ? null : normalized;
    }

    final encoded =
        value is num || value is bool ? '$value' : jsonEncode(value);
    final normalized = encoded.trim();
    return normalized.isEmpty ? null : normalized;
  }

  static String? _extractInlineScript(String source) {
    final trimmed = source.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final normalizedLower = trimmed.toLowerCase();
    if (normalizedLower.startsWith('js:')) {
      return trimmed.substring(3).trim();
    }

    final jsIndex = normalizedLower.indexOf('@js:');
    if (jsIndex >= 0) {
      return trimmed.substring(jsIndex + 4).trim();
    }

    final blockMatch = RegExp(
      r'<js>([\s\S]*?)</js>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(trimmed);
    if (blockMatch != null) {
      return blockMatch.group(1)?.trim();
    }

    return null;
  }

  static dynamic _evaluateScript({
    required String script,
    required String result,
  }) {
    final variables = _collectScriptVariables(script: script, result: result);

    final candidates = _collectExpressionCandidates(script);
    for (final candidate in candidates) {
      final evaluated = _evaluateExpression(
        candidate: candidate,
        result: result,
        variables: variables,
      );
      if (evaluated != null) {
        return evaluated;
      }
    }

    final fallback = variables['result'];
    if (fallback != null) {
      return fallback;
    }

    return null;
  }

  static List<String> _collectExpressionCandidates(String script) {
    final normalized = script.trim();
    if (normalized.isEmpty) {
      return const <String>[];
    }

    final candidates = <String>{};
    candidates.add(normalized);

    final resultAssignMatches = RegExp(
      r'result\s*=\s*([\s\S]*?);',
      caseSensitive: false,
    ).allMatches(normalized);
    for (final match in resultAssignMatches) {
      final expression = match.group(1)?.trim();
      if (expression != null && expression.isNotEmpty) {
        candidates.add(expression);
      }
    }

    final statements = normalized
        .split(RegExp(r';|\n'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);

    for (var index = statements.length - 1; index >= 0; index -= 1) {
      final statement = statements[index];
      final lower = statement.toLowerCase();
      if (lower.startsWith('//') ||
          lower.startsWith('var ') ||
          lower.startsWith('let ') ||
          lower.startsWith('const ') ||
          lower.startsWith('function ') ||
          lower.startsWith('if(') ||
          lower.startsWith('if (') ||
          lower.startsWith('for(') ||
          lower.startsWith('for (') ||
          lower.startsWith('while(') ||
          lower.startsWith('while (')) {
        continue;
      }

      final assignIndex = statement.indexOf('=');
      if (assignIndex > 0 && !statement.contains('==')) {
        final right = statement.substring(assignIndex + 1).trim();
        if (right.isNotEmpty) {
          candidates.add(right);
        }
      }

      candidates.add(statement);
      break;
    }

    return candidates.toList(growable: false);
  }

  static dynamic _evaluateExpression({
    required String candidate,
    required String result,
    Map<String, dynamic>? variables,
  }) {
    var expression = candidate.trim();
    if (expression.isEmpty) {
      return null;
    }

    expression = expression.replaceAll(RegExp(r'^return\s+'), '').trim();
    if (expression.endsWith(';')) {
      expression = expression.substring(0, expression.length - 1).trim();
    }

    if (expression.isEmpty) {
      return null;
    }

    final variableEvaluated = _evaluateExpressionWithVariables(
      expression: expression,
      variables: variables,
      fallbackResult: result,
    );
    if (variableEvaluated != null) {
      return variableEvaluated;
    }

    if (expression == 'result' || expression == 'String(result)') {
      return result;
    }

    final literal = _extractQuotedLiteral(expression);
    if (literal != null) {
      return literal;
    }

    final replaceMatch = RegExp(
      r'''^result\.replace\(\s*(['"])(.*?)\1\s*,\s*(['"])(.*?)\3\s*\)$''',
      dotAll: true,
    ).firstMatch(expression);
    if (replaceMatch != null) {
      final from = replaceMatch.group(2) ?? '';
      final to = replaceMatch.group(4) ?? '';
      return result.replaceAll(from, to);
    }

    final appendMatch = RegExp(
      r'''^result\s*\+\s*(['"])([\s\S]*)\1$''',
      dotAll: true,
    ).firstMatch(expression);
    if (appendMatch != null) {
      return result + (appendMatch.group(2) ?? '');
    }

    final prependMatch = RegExp(
      r'''^(['"])([\s\S]*)\1\s*\+\s*result$''',
      dotAll: true,
    ).firstMatch(expression);
    if (prependMatch != null) {
      return (prependMatch.group(2) ?? '') + result;
    }

    final jsonParseMatch = RegExp(
      r'^JSON\.parse\(result\)(?:\.([a-zA-Z0-9_\[\]\.\-]+))?$',
    ).firstMatch(expression);
    if (jsonParseMatch != null) {
      final decoded = _tryDecodeJsonLike(result);
      if (decoded == null) {
        return null;
      }

      final path = jsonParseMatch.group(1);
      if (path == null || path.isEmpty) {
        return decoded;
      }

      return _readPath(decoded, path);
    }

    final stringifyMatch = RegExp(
      r'^JSON\.stringify\(([\s\S]+)\)$',
      dotAll: true,
    ).firstMatch(expression);
    if (stringifyMatch != null) {
      final inner = stringifyMatch.group(1)?.trim();
      if (inner == null || inner.isEmpty) {
        return null;
      }
      final decoded = _tryDecodeJsonLike(inner);
      if (decoded == null) {
        return null;
      }
      return jsonEncode(decoded);
    }

    final prefixJsonMatch = RegExp(
      r'''^(['"])([\s\S]*)\1\s*\+\s*JSON\.stringify\(([\s\S]+)\)$''',
      dotAll: true,
    ).firstMatch(expression);
    if (prefixJsonMatch != null) {
      final prefix = prefixJsonMatch.group(2) ?? '';
      final objectExpression = prefixJsonMatch.group(3)?.trim() ?? '';
      final decoded = _tryDecodeJsonLike(objectExpression);
      if (decoded == null) {
        return null;
      }
      return '$prefix${jsonEncode(decoded)}';
    }

    final jsonSuffixMatch = RegExp(
      r'''^JSON\.stringify\(([\s\S]+)\)\s*\+\s*(['"])([\s\S]*)\2$''',
      dotAll: true,
    ).firstMatch(expression);
    if (jsonSuffixMatch != null) {
      final objectExpression = jsonSuffixMatch.group(1)?.trim() ?? '';
      final suffix = jsonSuffixMatch.group(3) ?? '';
      final decoded = _tryDecodeJsonLike(objectExpression);
      if (decoded == null) {
        return null;
      }
      return '${jsonEncode(decoded)}$suffix';
    }

    if (_looksLikeJsonLiteral(expression)) {
      return _tryDecodeJsonLike(expression);
    }

    return null;
  }

  static Map<String, dynamic> _collectScriptVariables({
    required String script,
    required String result,
  }) {
    final variables = <String, dynamic>{'result': result};
    final statements = script
        .split(RegExp(r';|\n'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);

    for (final statement in statements) {
      final match = RegExp(
        r'^(?:var\s+|let\s+|const\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=\s*([\s\S]+)$',
      ).firstMatch(statement);
      if (match == null) {
        continue;
      }

      final name = match.group(1)!;
      final expression = match.group(2)?.trim();
      if (expression == null || expression.isEmpty) {
        continue;
      }

      final value = _evaluateExpressionWithVariables(
        expression: expression,
        variables: variables,
        fallbackResult: variables['result']?.toString() ?? result,
      );
      if (value != null) {
        variables[name] = value;
      }
    }

    return variables;
  }

  static dynamic _evaluateExpressionWithVariables({
    required String expression,
    Map<String, dynamic>? variables,
    required String fallbackResult,
  }) {
    final vars = variables ?? const <String, dynamic>{};
    var candidate = expression.trim();
    if (candidate.isEmpty) {
      return null;
    }

    if (candidate.startsWith('(') && candidate.endsWith(')')) {
      final inner = candidate.substring(1, candidate.length - 1).trim();
      if (inner.isNotEmpty && inner.length < candidate.length) {
        final wrapped = _evaluateExpressionWithVariables(
          expression: inner,
          variables: vars,
          fallbackResult: fallbackResult,
        );
        if (wrapped != null) {
          return wrapped;
        }
      }
    }

    if (vars.containsKey(candidate)) {
      return vars[candidate];
    }

    if (candidate == 'result') {
      return vars['result'] ?? fallbackResult;
    }

    if (candidate == 'String(result)') {
      return (vars['result'] ?? fallbackResult).toString();
    }

    final number = num.tryParse(candidate);
    if (number != null) {
      return number;
    }

    final ternary = _splitTopLevelTernary(candidate);
    if (ternary != null) {
      final condition = _evaluateScriptCondition(
        ternary.$1,
        vars,
        fallbackResult,
      );
      return _evaluateExpressionWithVariables(
        expression: condition ? ternary.$2 : ternary.$3,
        variables: vars,
        fallbackResult: fallbackResult,
      );
    }

    final parseIntMatch = RegExp(
      r'^parseInt\(([^\)]+)\)$',
      caseSensitive: false,
    ).firstMatch(candidate);
    if (parseIntMatch != null) {
      final inner = parseIntMatch.group(1)!.trim();
      final evaluated = _evaluateExpressionWithVariables(
        expression: inner,
        variables: vars,
        fallbackResult: fallbackResult,
      );
      final numberValue = num.tryParse(evaluated?.toString() ?? '');
      if (numberValue != null) {
        return numberValue.toInt();
      }
      return null;
    }

    final stringMatch = RegExp(
      r'^String\(([^\)]+)\)$',
      caseSensitive: false,
    ).firstMatch(candidate);
    if (stringMatch != null) {
      final inner = stringMatch.group(1)!.trim();
      final evaluated = _evaluateExpressionWithVariables(
        expression: inner,
        variables: vars,
        fallbackResult: fallbackResult,
      );
      return evaluated?.toString();
    }

    final splitMatch = RegExp(
      r'''^(.+?)\.split\((['"])(.*?)\2\)\[(\d+)\]$''',
      dotAll: true,
    ).firstMatch(candidate);
    if (splitMatch != null) {
      final subject =
          _evaluateExpressionWithVariables(
            expression: splitMatch.group(1)!,
            variables: vars,
            fallbackResult: fallbackResult,
          )?.toString();
      if (subject == null) {
        return null;
      }
      final delimiter = splitMatch.group(3) ?? '';
      final index = int.tryParse(splitMatch.group(4) ?? '');
      if (index == null) {
        return null;
      }
      final parts = subject.split(delimiter);
      if (index < 0 || index >= parts.length) {
        return null;
      }
      return parts[index];
    }

    final matchGroup = RegExp(
      r'^(.+?)\.match\(/(.+?)/([a-z]*)\)\[(\d+)\]$',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(candidate);
    if (matchGroup != null) {
      final subject =
          _evaluateExpressionWithVariables(
            expression: matchGroup.group(1)!,
            variables: vars,
            fallbackResult: fallbackResult,
          )?.toString();
      if (subject == null) {
        return null;
      }

      final regex = _buildJsRegex(
        pattern: matchGroup.group(2) ?? '',
        flags: matchGroup.group(3) ?? '',
      );
      final match = regex.firstMatch(subject);
      if (match == null) {
        return null;
      }

      final groupIndex = int.tryParse(matchGroup.group(4) ?? '0') ?? 0;
      if (groupIndex < 0 || groupIndex > match.groupCount) {
        return null;
      }

      return match.group(groupIndex);
    }

    final matchOnly = RegExp(
      r'^(.+?)\.match\(/(.+?)/([a-z]*)\)$',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(candidate);
    if (matchOnly != null) {
      final subject =
          _evaluateExpressionWithVariables(
            expression: matchOnly.group(1)!,
            variables: vars,
            fallbackResult: fallbackResult,
          )?.toString();
      if (subject == null) {
        return null;
      }

      final regex = _buildJsRegex(
        pattern: matchOnly.group(2) ?? '',
        flags: matchOnly.group(3) ?? '',
      );
      final match = regex.firstMatch(subject);
      return match?.group(0);
    }

    final replaceRegex = RegExp(
      r'''^(.+?)\.replace\(/(.+?)/([a-z]*)\s*,\s*(['"])(.*?)\4\)$''',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(candidate);
    if (replaceRegex != null) {
      final subject =
          _evaluateExpressionWithVariables(
            expression: replaceRegex.group(1)!,
            variables: vars,
            fallbackResult: fallbackResult,
          )?.toString();
      if (subject == null) {
        return null;
      }

      final regex = _buildJsRegex(
        pattern: replaceRegex.group(2) ?? '',
        flags: replaceRegex.group(3) ?? '',
      );
      final replacement = replaceRegex.group(5) ?? '';
      return subject.replaceAll(regex, replacement);
    }

    final replaceString = RegExp(
      r'''^(.+?)\.replace\(\s*(['"])(.*?)\2\s*,\s*(['"])(.*?)\4\s*\)$''',
      dotAll: true,
    ).firstMatch(candidate);
    if (replaceString != null) {
      final subject =
          _evaluateExpressionWithVariables(
            expression: replaceString.group(1)!,
            variables: vars,
            fallbackResult: fallbackResult,
          )?.toString();
      if (subject == null) {
        return null;
      }
      final from = replaceString.group(3) ?? '';
      final to = replaceString.group(5) ?? '';
      return subject.replaceAll(from, to);
    }

    final ratioMatch = RegExp(
      r'^([A-Za-z_][A-Za-z0-9_]*)\s*/\s*(\d+)$',
      caseSensitive: false,
    ).firstMatch(candidate);
    if (ratioMatch != null) {
      final left = vars[ratioMatch.group(1)!];
      final right = num.tryParse(ratioMatch.group(2) ?? '');
      final leftNumber = num.tryParse(left?.toString() ?? '');
      if (leftNumber != null && right != null && right != 0) {
        return leftNumber / right;
      }
      return null;
    }

    final concat = _splitTopLevel(candidate, '+');
    if (concat.length > 1) {
      final resolved = <String>[];
      for (final token in concat) {
        final value = _evaluateExpressionWithVariables(
          expression: token,
          variables: vars,
          fallbackResult: fallbackResult,
        );
        if (value == null) {
          return null;
        }
        resolved.add(value.toString());
      }
      return resolved.join();
    }

    final literal = _extractQuotedLiteral(candidate);
    if (literal != null) {
      return _resolveScriptTemplateLiteral(literal, vars, fallbackResult);
    }

    return null;
  }

  static bool _evaluateScriptCondition(
    String expression,
    Map<String, dynamic> variables,
    String fallbackResult,
  ) {
    var normalized = expression.trim();
    var negate = false;

    if (normalized.startsWith('!')) {
      negate = true;
      normalized = normalized.substring(1).trim();
    }

    final testMatch = RegExp(
      r'^/(.+?)/([a-z]*)\.test\((.+)\)$',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(normalized);

    bool value;
    if (testMatch != null) {
      final subject =
          _evaluateExpressionWithVariables(
            expression: testMatch.group(3)!,
            variables: variables,
            fallbackResult: fallbackResult,
          )?.toString();
      if (subject == null) {
        value = false;
      } else {
        final regex = _buildJsRegex(
          pattern: testMatch.group(1) ?? '',
          flags: testMatch.group(2) ?? '',
        );
        value = regex.hasMatch(subject);
      }
    } else {
      final evaluated = _evaluateExpressionWithVariables(
        expression: normalized,
        variables: variables,
        fallbackResult: fallbackResult,
      );
      value = _toBoolean(evaluated);
    }

    return negate ? !value : value;
  }

  static bool _toBoolean(dynamic value) {
    if (value == null) {
      return false;
    }
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }

    final text = value.toString().trim().toLowerCase();
    if (text.isEmpty || text == 'false' || text == 'null') {
      return false;
    }
    return true;
  }

  static RegExp _buildJsRegex({
    required String pattern,
    required String flags,
  }) {
    final normalizedFlags = flags.toLowerCase();
    return RegExp(
      pattern,
      caseSensitive: !normalizedFlags.contains('i'),
      multiLine: normalizedFlags.contains('m'),
      dotAll: normalizedFlags.contains('s'),
    );
  }

  static (String, String, String)? _splitTopLevelTernary(String expression) {
    final question = _findTopLevelChar(expression, '?');
    if (question < 0) {
      return null;
    }

    final colon = _findTopLevelChar(expression, ':', start: question + 1);
    if (colon < 0) {
      return null;
    }

    final condition = expression.substring(0, question).trim();
    final yes = expression.substring(question + 1, colon).trim();
    final no = expression.substring(colon + 1).trim();
    if (condition.isEmpty || yes.isEmpty || no.isEmpty) {
      return null;
    }

    return (condition, yes, no);
  }

  static List<String> _splitTopLevel(String expression, String delimiter) {
    final output = <String>[];
    var buffer = StringBuffer();
    var depthParen = 0;
    var depthBrace = 0;
    var depthBracket = 0;
    var inString = false;
    var quote = '';
    var escaped = false;

    for (var index = 0; index < expression.length; index += 1) {
      final char = expression[index];

      if (inString) {
        buffer.write(char);
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

      if (char == '"' || char == "'" || char == '`') {
        inString = true;
        quote = char;
        buffer.write(char);
        continue;
      }

      if (char == '(') {
        depthParen += 1;
        buffer.write(char);
        continue;
      }
      if (char == ')' && depthParen > 0) {
        depthParen -= 1;
        buffer.write(char);
        continue;
      }
      if (char == '{') {
        depthBrace += 1;
        buffer.write(char);
        continue;
      }
      if (char == '}' && depthBrace > 0) {
        depthBrace -= 1;
        buffer.write(char);
        continue;
      }
      if (char == '[') {
        depthBracket += 1;
        buffer.write(char);
        continue;
      }
      if (char == ']' && depthBracket > 0) {
        depthBracket -= 1;
        buffer.write(char);
        continue;
      }

      if (char == delimiter &&
          depthParen == 0 &&
          depthBrace == 0 &&
          depthBracket == 0) {
        final token = buffer.toString().trim();
        if (token.isNotEmpty) {
          output.add(token);
        }
        buffer = StringBuffer();
        continue;
      }

      buffer.write(char);
    }

    final tail = buffer.toString().trim();
    if (tail.isNotEmpty) {
      output.add(tail);
    }

    return output;
  }

  static int _findTopLevelChar(
    String expression,
    String token, {
    int start = 0,
  }) {
    var depthParen = 0;
    var depthBrace = 0;
    var depthBracket = 0;
    var inString = false;
    var quote = '';
    var escaped = false;

    for (var index = start; index < expression.length; index += 1) {
      final char = expression[index];

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

      if (char == '"' || char == "'" || char == '`') {
        inString = true;
        quote = char;
        continue;
      }

      if (char == '(') {
        depthParen += 1;
        continue;
      }
      if (char == ')' && depthParen > 0) {
        depthParen -= 1;
        continue;
      }
      if (char == '{') {
        depthBrace += 1;
        continue;
      }
      if (char == '}' && depthBrace > 0) {
        depthBrace -= 1;
        continue;
      }
      if (char == '[') {
        depthBracket += 1;
        continue;
      }
      if (char == ']' && depthBracket > 0) {
        depthBracket -= 1;
        continue;
      }

      if (depthParen == 0 &&
          depthBrace == 0 &&
          depthBracket == 0 &&
          char == token) {
        return index;
      }
    }

    return -1;
  }

  static String _resolveScriptTemplateLiteral(
    String literal,
    Map<String, dynamic> variables,
    String fallbackResult,
  ) {
    return literal.replaceAllMapped(RegExp(r'\$\{([^}]+)\}'), (match) {
      final expression = match.group(1)?.trim() ?? '';
      if (expression.isEmpty) {
        return '';
      }
      final evaluated = _evaluateExpressionWithVariables(
        expression: expression,
        variables: variables,
        fallbackResult: fallbackResult,
      );
      return evaluated?.toString() ?? '';
    });
  }

  static String? _extractQuotedLiteral(String expression) {
    final single = RegExp(
      r"^'([\s\S]*)'$",
      dotAll: true,
    ).firstMatch(expression);
    if (single != null) {
      return single.group(1);
    }

    final doubleQuoted = RegExp(
      r'^"([\s\S]*)"$',
      dotAll: true,
    ).firstMatch(expression);
    if (doubleQuoted != null) {
      return doubleQuoted.group(1);
    }

    final backtick = RegExp(
      r'^`([\s\S]*)`$',
      dotAll: true,
    ).firstMatch(expression);
    if (backtick != null) {
      return backtick.group(1);
    }

    return null;
  }

  static List<String> _toChunkList(dynamic value) {
    if (value == null) {
      return const <String>[];
    }

    if (value is List) {
      return value
          .map(_normalizeChunk)
          .whereType<String>()
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }

    if (value is Map) {
      return <String>[jsonEncode(value)];
    }

    final normalized = _normalizeChunk(value);
    if (normalized == null || normalized.isEmpty) {
      return const <String>[];
    }

    final decoded = _tryDecodeJsonLike(normalized);
    if (decoded is List) {
      return decoded
          .map(_normalizeChunk)
          .whereType<String>()
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }

    if (decoded is Map) {
      return <String>[jsonEncode(decoded)];
    }

    return <String>[normalized];
  }

  static String? _normalizeChunk(dynamic item) {
    if (item == null) {
      return null;
    }

    if (item is String) {
      return item.trim();
    }

    if (item is num || item is bool) {
      return '$item';
    }

    return jsonEncode(item);
  }

  static bool _looksLikeJsonLiteral(String source) {
    final text = source.trim();
    return (text.startsWith('{') && text.endsWith('}')) ||
        (text.startsWith('[') && text.endsWith(']'));
  }

  static dynamic _tryDecodeJsonLike(String source) {
    final text = source.trim();
    if (text.isEmpty) {
      return null;
    }

    try {
      return jsonDecode(text);
    } on FormatException {
      final normalized = _normalizePseudoJson(text);
      try {
        return jsonDecode(normalized);
      } on FormatException {
        return null;
      }
    }
  }

  static String _normalizePseudoJson(String source) {
    return source.replaceAllMapped(RegExp(r"'([^'\\]*(?:\\.[^'\\]*)*)'"), (
      match,
    ) {
      final inner = match.group(1) ?? '';
      final escaped = inner
          .replaceAll(r'\\', r'\\\\')
          .replaceAll('"', r'\"')
          .replaceAll('\n', r'\n');
      return '"$escaped"';
    });
  }

  static String _resolveJsonPlaceholders(String expression, String result) {
    final decoded = _tryDecodeJsonLike(result);
    if (decoded == null) {
      return expression;
    }

    return expression.replaceAllMapped(RegExp(r'\{\{\s*\$\.?([^}]+?)\s*\}\}'), (
      match,
    ) {
      final path = match.group(1)?.trim() ?? '';
      if (path.isEmpty) {
        return '';
      }

      final value = _readPath(decoded, path);
      if (value == null) {
        return '';
      }

      if (value is num || value is bool) {
        return '$value';
      }

      if (value is String) {
        return value;
      }

      return jsonEncode(value);
    });
  }

  static dynamic _readPath(dynamic source, String rawPath) {
    var path = rawPath.trim();
    if (path.isEmpty) {
      return null;
    }

    if (path.startsWith(r'$.')) {
      path = path.substring(2);
    } else if (path.startsWith(r'$')) {
      path = path.substring(1);
    }

    if (path.startsWith('.')) {
      path = path.substring(1);
    }

    if (path.isEmpty) {
      return source;
    }

    final tokens = _tokenizePath(path);
    if (tokens.isEmpty) {
      return null;
    }

    dynamic current = source;
    for (final token in tokens) {
      if (token is int) {
        if (current is List && token >= 0 && token < current.length) {
          current = current[token];
          continue;
        }
        return null;
      }

      if (token is String) {
        if (current is Map && current.containsKey(token)) {
          current = current[token];
          continue;
        }

        if (current is Map) {
          final matchedKey = current.keys
              .map((item) => item.toString())
              .firstWhere((item) => item == token, orElse: () => '');
          if (matchedKey.isNotEmpty) {
            current = current[matchedKey];
            continue;
          }
        }

        return null;
      }
    }

    return current;
  }

  static List<Object> _tokenizePath(String path) {
    final output = <Object>[];
    for (final part in path.split('.')) {
      final segment = part.trim();
      if (segment.isEmpty) {
        continue;
      }

      final matches = RegExp(
        r'([a-zA-Z0-9_-]+)|\[(\d+)\]',
      ).allMatches(segment).toList(growable: false);
      if (matches.isEmpty) {
        return const <Object>[];
      }

      for (final match in matches) {
        final key = match.group(1);
        if (key != null && key.isNotEmpty) {
          output.add(key);
          continue;
        }

        final indexText = match.group(2);
        final index = int.tryParse(indexText ?? '');
        if (index == null) {
          return const <Object>[];
        }
        output.add(index);
      }
    }

    return output;
  }
}

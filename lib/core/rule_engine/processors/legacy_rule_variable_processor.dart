import 'dart:async';

typedef LegacyPutValueResolver = String? Function(String valueExpression);
typedef AsyncLegacyPutValueResolver =
    FutureOr<String?> Function(String valueExpression);

class LegacyRuleVariableProcessor {
  const LegacyRuleVariableProcessor._();

  static final RegExp _getPattern = RegExp(r'@get:\{\s*([^{}]+?)\s*\}');

  static bool containsVariableSyntax(String? expression) {
    final text = expression?.trim();
    if (text == null || text.isEmpty) {
      return false;
    }

    return text.contains('@put:') || text.contains('@get:{');
  }

  static String resolveExpression({
    required String expression,
    required Map<String, String> variables,
    required LegacyPutValueResolver resolvePutValue,
  }) {
    final extraction = _extractPutAssignments(expression);

    for (final assignment in extraction.assignments) {
      final valueExpression = replaceGetTokens(
        assignment.valueExpression,
        variables,
      );
      final resolved = resolvePutValue(valueExpression)?.trim();
      if (resolved == null || resolved.isEmpty) {
        continue;
      }

      variables[assignment.key] = resolved;
      variables[r'$.' + assignment.key] = resolved;
    }

    return replaceGetTokens(extraction.remainingExpression, variables).trim();
  }

  static Future<String> resolveExpressionAsync({
    required String expression,
    required Map<String, String> variables,
    required AsyncLegacyPutValueResolver resolvePutValue,
  }) async {
    final extraction = _extractPutAssignments(expression);

    for (final assignment in extraction.assignments) {
      final valueExpression = replaceGetTokens(
        assignment.valueExpression,
        variables,
      );
      final resolved = (await resolvePutValue(valueExpression))?.trim();
      if (resolved == null || resolved.isEmpty) {
        continue;
      }

      variables[assignment.key] = resolved;
      variables[r'$.' + assignment.key] = resolved;
    }

    return replaceGetTokens(extraction.remainingExpression, variables).trim();
  }

  static String replaceGetTokens(
    String expression,
    Map<String, String> variables,
  ) {
    return expression.replaceAllMapped(_getPattern, (match) {
      final rawKey = match.group(1) ?? '';
      final key = _stripWrappingQuotes(rawKey.trim());
      if (key.isEmpty) {
        return '';
      }

      return variables[key] ?? variables[r'$.' + key] ?? '';
    });
  }

  static _PutExtraction _extractPutAssignments(String expression) {
    final assignments = <_PutAssignment>[];
    final buffer = StringBuffer();

    var index = 0;
    while (index < expression.length) {
      final marker = expression.indexOf('@put:', index);
      if (marker < 0) {
        buffer.write(expression.substring(index));
        break;
      }

      buffer.write(expression.substring(index, marker));

      var objectStart = marker + 5;
      while (objectStart < expression.length &&
          _isWhitespace(expression.codeUnitAt(objectStart))) {
        objectStart += 1;
      }

      if (objectStart >= expression.length || expression[objectStart] != '{') {
        buffer.write('@put:');
        index = marker + 5;
        continue;
      }

      final objectEnd = _findMatchingBrace(expression, objectStart);
      if (objectEnd < 0) {
        buffer.write(expression.substring(marker));
        break;
      }

      final objectText = expression.substring(objectStart + 1, objectEnd);
      assignments.addAll(_parsePutObject(objectText));
      index = objectEnd + 1;
    }

    return _PutExtraction(
      remainingExpression: buffer.toString(),
      assignments: assignments,
    );
  }

  static int _findMatchingBrace(String source, int startIndex) {
    var depth = 0;
    var inSingle = false;
    var inDouble = false;
    var inBacktick = false;
    var escaped = false;

    for (var index = startIndex; index < source.length; index += 1) {
      final char = source[index];

      if (escaped) {
        escaped = false;
        continue;
      }

      if ((inSingle || inDouble || inBacktick) && char == r'\') {
        escaped = true;
        continue;
      }

      if (inSingle) {
        if (char == "'") {
          inSingle = false;
        }
        continue;
      }

      if (inDouble) {
        if (char == '"') {
          inDouble = false;
        }
        continue;
      }

      if (inBacktick) {
        if (char == '`') {
          inBacktick = false;
        }
        continue;
      }

      if (char == "'") {
        inSingle = true;
        continue;
      }

      if (char == '"') {
        inDouble = true;
        continue;
      }

      if (char == '`') {
        inBacktick = true;
        continue;
      }

      if (char == '{') {
        depth += 1;
        continue;
      }

      if (char == '}') {
        depth -= 1;
        if (depth == 0) {
          return index;
        }
      }
    }

    return -1;
  }

  static List<_PutAssignment> _parsePutObject(String source) {
    final output = <_PutAssignment>[];
    for (final pair in _splitTopLevel(source, ',')) {
      final separator = _findTopLevelSeparator(pair, ':');
      if (separator <= 0 || separator >= pair.length - 1) {
        continue;
      }

      final rawKey = pair.substring(0, separator).trim();
      final rawValue = pair.substring(separator + 1).trim();
      if (rawKey.isEmpty || rawValue.isEmpty) {
        continue;
      }

      final key = _stripWrappingQuotes(rawKey);
      if (key.isEmpty) {
        continue;
      }

      output.add(
        _PutAssignment(
          key: key,
          valueExpression: _stripWrappingQuotes(rawValue),
        ),
      );
    }

    return output;
  }

  static List<String> _splitTopLevel(String source, String delimiter) {
    final output = <String>[];
    final buffer = StringBuffer();

    var braceDepth = 0;
    var bracketDepth = 0;
    var parenDepth = 0;
    var inSingle = false;
    var inDouble = false;
    var inBacktick = false;
    var escaped = false;

    for (var index = 0; index < source.length; index += 1) {
      final char = source[index];

      if (escaped) {
        buffer.write(char);
        escaped = false;
        continue;
      }

      if ((inSingle || inDouble || inBacktick) && char == r'\') {
        buffer.write(char);
        escaped = true;
        continue;
      }

      if (inSingle) {
        buffer.write(char);
        if (char == "'") {
          inSingle = false;
        }
        continue;
      }

      if (inDouble) {
        buffer.write(char);
        if (char == '"') {
          inDouble = false;
        }
        continue;
      }

      if (inBacktick) {
        buffer.write(char);
        if (char == '`') {
          inBacktick = false;
        }
        continue;
      }

      if (char == "'") {
        inSingle = true;
        buffer.write(char);
        continue;
      }

      if (char == '"') {
        inDouble = true;
        buffer.write(char);
        continue;
      }

      if (char == '`') {
        inBacktick = true;
        buffer.write(char);
        continue;
      }

      if (char == '{') {
        braceDepth += 1;
        buffer.write(char);
        continue;
      }
      if (char == '}') {
        if (braceDepth > 0) {
          braceDepth -= 1;
        }
        buffer.write(char);
        continue;
      }
      if (char == '[') {
        bracketDepth += 1;
        buffer.write(char);
        continue;
      }
      if (char == ']') {
        if (bracketDepth > 0) {
          bracketDepth -= 1;
        }
        buffer.write(char);
        continue;
      }
      if (char == '(') {
        parenDepth += 1;
        buffer.write(char);
        continue;
      }
      if (char == ')') {
        if (parenDepth > 0) {
          parenDepth -= 1;
        }
        buffer.write(char);
        continue;
      }

      if (char == delimiter &&
          braceDepth == 0 &&
          bracketDepth == 0 &&
          parenDepth == 0) {
        final segment = buffer.toString().trim();
        if (segment.isNotEmpty) {
          output.add(segment);
        }
        buffer.clear();
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

  static int _findTopLevelSeparator(String source, String separator) {
    var braceDepth = 0;
    var bracketDepth = 0;
    var parenDepth = 0;
    var inSingle = false;
    var inDouble = false;
    var inBacktick = false;
    var escaped = false;

    for (var index = 0; index < source.length; index += 1) {
      final char = source[index];

      if (escaped) {
        escaped = false;
        continue;
      }

      if ((inSingle || inDouble || inBacktick) && char == r'\') {
        escaped = true;
        continue;
      }

      if (inSingle) {
        if (char == "'") {
          inSingle = false;
        }
        continue;
      }
      if (inDouble) {
        if (char == '"') {
          inDouble = false;
        }
        continue;
      }
      if (inBacktick) {
        if (char == '`') {
          inBacktick = false;
        }
        continue;
      }

      if (char == "'") {
        inSingle = true;
        continue;
      }
      if (char == '"') {
        inDouble = true;
        continue;
      }
      if (char == '`') {
        inBacktick = true;
        continue;
      }

      if (char == '{') {
        braceDepth += 1;
        continue;
      }
      if (char == '}') {
        if (braceDepth > 0) {
          braceDepth -= 1;
        }
        continue;
      }
      if (char == '[') {
        bracketDepth += 1;
        continue;
      }
      if (char == ']') {
        if (bracketDepth > 0) {
          bracketDepth -= 1;
        }
        continue;
      }
      if (char == '(') {
        parenDepth += 1;
        continue;
      }
      if (char == ')') {
        if (parenDepth > 0) {
          parenDepth -= 1;
        }
        continue;
      }

      if (char == separator &&
          braceDepth == 0 &&
          bracketDepth == 0 &&
          parenDepth == 0) {
        return index;
      }
    }

    return -1;
  }

  static String _stripWrappingQuotes(String text) {
    final value = text.trim();
    if (value.length < 2) {
      return value;
    }

    final first = value[0];
    final last = value[value.length - 1];
    if ((first == '"' && last == '"') ||
        (first == "'" && last == "'") ||
        (first == '`' && last == '`')) {
      return value.substring(1, value.length - 1);
    }

    return value;
  }

  static bool _isWhitespace(int codeUnit) {
    return codeUnit == 32 || codeUnit == 10 || codeUnit == 13 || codeUnit == 9;
  }
}

class _PutExtraction {
  const _PutExtraction({
    required this.remainingExpression,
    required this.assignments,
  });

  final String remainingExpression;
  final List<_PutAssignment> assignments;
}

class _PutAssignment {
  const _PutAssignment({required this.key, required this.valueExpression});

  final String key;
  final String valueExpression;
}

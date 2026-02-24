class LegacyXPathCompat {
  const LegacyXPathCompat._();

  static bool looksLikeXPathExpression(String? expression) {
    final text = expression?.trim();
    if (text == null || text.isEmpty) {
      return false;
    }

    if (text.startsWith('xpath:') || text.startsWith('@xpath:')) {
      return true;
    }

    return text.startsWith('//') || text.startsWith('./');
  }

  static String? buildRuleExpression({
    required String expression,
    required String fallbackExtractor,
    String? preferredAttribute,
  }) {
    final candidates = expression
        .split('||')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    if (candidates.isEmpty) {
      return null;
    }

    final normalized = <String>[];
    for (final candidate in candidates) {
      final mapped = _buildSingleRule(
        candidate,
        fallbackExtractor: fallbackExtractor,
        preferredAttribute: preferredAttribute,
      );
      if (mapped == null || mapped.isEmpty) {
        return null;
      }
      normalized.add(mapped);
    }

    if (normalized.isEmpty) {
      return null;
    }

    return normalized.toSet().join('||');
  }

  static String? _buildSingleRule(
    String expression, {
    required String fallbackExtractor,
    String? preferredAttribute,
  }) {
    var text = expression.trim();
    if (text.isEmpty) {
      return null;
    }

    if (text.startsWith('@xpath:')) {
      text = text.substring(7).trim();
    } else if (text.startsWith('xpath:')) {
      text = text.substring(6).trim();
    }

    if (!looksLikeXPathExpression(text)) {
      return null;
    }

    final extraction = _extractTrailingAccessor(text);
    final css = _convertPathToCss(extraction.path);
    if (css == null || css.isEmpty) {
      return null;
    }

    final extractor =
        extraction.extractor ??
        _normalizeFallbackExtractor(
          fallbackExtractor,
          preferredAttribute: preferredAttribute,
        );

    return 'html:$css@$extractor';
  }

  static _XPathExtraction _extractTrailingAccessor(String path) {
    var normalized = path.trim();

    if (normalized.endsWith('/text()')) {
      return _XPathExtraction(
        path: normalized.substring(0, normalized.length - 7),
        extractor: 'text',
      );
    }

    final attrMatch = RegExp(r'/@([a-zA-Z0-9_:-]+)$').firstMatch(normalized);
    if (attrMatch != null) {
      final attr = attrMatch.group(1)!;
      final trimmed = normalized.substring(0, attrMatch.start).trim();
      return _XPathExtraction(path: trimmed, extractor: 'attr($attr)');
    }

    return _XPathExtraction(path: normalized);
  }

  static String _normalizeFallbackExtractor(
    String fallbackExtractor, {
    String? preferredAttribute,
  }) {
    final normalized = fallbackExtractor.trim();
    if (normalized.startsWith('attr(') && normalized.endsWith(')')) {
      return normalized;
    }

    if (preferredAttribute != null && preferredAttribute.trim().isNotEmpty) {
      return 'attr(${preferredAttribute.trim()})';
    }

    if (normalized == 'html' ||
        normalized == 'outerhtml' ||
        normalized == 'text') {
      return normalized;
    }

    return 'text';
  }

  static String? _convertPathToCss(String xpath) {
    final steps = _tokenizeSteps(xpath);
    if (steps.isEmpty) {
      return null;
    }

    final output = <String>[];
    for (final step in steps) {
      final selector = _stepToCss(step);
      if (selector == null || selector.isEmpty) {
        continue;
      }
      output.add(selector);
    }

    if (output.isEmpty) {
      return null;
    }

    return output.join(' ');
  }

  static List<String> _tokenizeSteps(String source) {
    final text = source.trim();
    if (text.isEmpty) {
      return const <String>[];
    }

    final output = <String>[];
    final buffer = StringBuffer();
    var bracketDepth = 0;
    var inSingle = false;
    var inDouble = false;

    for (var i = 0; i < text.length; i += 1) {
      final char = text[i];

      if (char == "'" && !inDouble) {
        inSingle = !inSingle;
        buffer.write(char);
        continue;
      }

      if (char == '"' && !inSingle) {
        inDouble = !inDouble;
        buffer.write(char);
        continue;
      }

      if (!inSingle && !inDouble) {
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

        if (char == '/' && bracketDepth == 0) {
          final part = buffer.toString().trim();
          if (part.isNotEmpty) {
            output.add(part);
          }
          buffer.clear();
          continue;
        }
      }

      buffer.write(char);
    }

    final tail = buffer.toString().trim();
    if (tail.isNotEmpty) {
      output.add(tail);
    }

    return output
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty && item != '.' && item != '..')
        .toList(growable: false);
  }

  static String? _stepToCss(String step) {
    var normalized = step.trim();
    if (normalized.isEmpty || normalized == '*') {
      return '*';
    }

    final firstPredicate = normalized.indexOf('[');
    var tag =
        firstPredicate < 0
            ? normalized
            : normalized.substring(0, firstPredicate);
    var predicates =
        firstPredicate < 0 ? '' : normalized.substring(firstPredicate);

    tag = tag.trim();
    if (tag.isEmpty) {
      tag = '*';
    }

    final buffers = StringBuffer(tag == '*' ? '*' : tag);

    for (final predicate in _extractPredicates(predicates)) {
      final css = _predicateToCss(predicate.trim());
      if (css != null && css.isNotEmpty) {
        buffers.write(css);
      }
    }

    final output = buffers.toString().trim();
    return output.isEmpty ? null : output;
  }

  static List<String> _extractPredicates(String source) {
    if (source.trim().isEmpty) {
      return const <String>[];
    }

    final output = <String>[];
    var depth = 0;
    var inSingle = false;
    var inDouble = false;
    var start = -1;

    for (var i = 0; i < source.length; i += 1) {
      final char = source[i];

      if (char == "'" && !inDouble) {
        inSingle = !inSingle;
        continue;
      }

      if (char == '"' && !inSingle) {
        inDouble = !inDouble;
        continue;
      }

      if (inSingle || inDouble) {
        continue;
      }

      if (char == '[') {
        if (depth == 0) {
          start = i + 1;
        }
        depth += 1;
        continue;
      }

      if (char == ']') {
        depth -= 1;
        if (depth == 0 && start >= 0 && start <= i) {
          output.add(source.substring(start, i));
          start = -1;
        }
      }
    }

    return output;
  }

  static String? _predicateToCss(String predicate) {
    final text = predicate.trim();
    if (text.isEmpty) {
      return null;
    }

    final index = int.tryParse(text);
    if (index != null && index > 0) {
      return ':nth-of-type($index)';
    }

    if (text == 'last()') {
      return ':last-of-type';
    }

    final exists = RegExp(r'^@([a-zA-Z0-9_:-]+)$').firstMatch(text);
    if (exists != null) {
      final attr = exists.group(1)!;
      return '[$attr]';
    }

    final equal = RegExp(
      r'''^@([a-zA-Z0-9_:-]+)\s*=\s*['"](.+?)['"]$''',
    ).firstMatch(text);
    if (equal != null) {
      final key = equal.group(1)!;
      final value = equal.group(2)!;
      if (key == 'id') {
        return '#$value';
      }
      if (key == 'class') {
        return value
            .split(RegExp(r'\s+'))
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .map((item) => '.$item')
            .join();
      }
      return '[$key="$value"]';
    }

    final containsClass = RegExp(
      r'''^contains\(\s*@class\s*,\s*['"](.+?)['"]\s*\)$''',
    ).firstMatch(text);
    if (containsClass != null) {
      final value = containsClass.group(1)!;
      if (value.trim().isEmpty) {
        return null;
      }
      return '.$value';
    }

    final containsAttr = RegExp(
      r'''^contains\(\s*@([a-zA-Z0-9_:-]+)\s*,\s*['"](.+?)['"]\s*\)$''',
    ).firstMatch(text);
    if (containsAttr != null) {
      final key = containsAttr.group(1)!;
      final value = containsAttr.group(2)!;
      return '[$key*="$value"]';
    }

    return null;
  }
}

class _XPathExtraction {
  const _XPathExtraction({required this.path, this.extractor});

  final String path;
  final String? extractor;
}

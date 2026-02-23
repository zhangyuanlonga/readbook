class LegacyRuleCompat {
  const LegacyRuleCompat._();

  static String? buildHtmlRuleCandidate({
    required String stage,
    required String fallbackExtractor,
    String? preferredAttribute,
  }) {
    final normalizedStage = stage.trim();
    if (normalizedStage.isEmpty || normalizedStage.startsWith('js:')) {
      return null;
    }

    final segments = normalizedStage
        .split('@')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: true);
    if (segments.isEmpty) {
      return null;
    }

    if (segments.length == 1 &&
        _looksLikeStandaloneExtractorToken(segments[0])) {
      final token = segments[0];
      final extractor = _normalizeExtractorToken(
        token,
        fallbackExtractor: fallbackExtractor,
        preferredAttribute: preferredAttribute,
      );
      final selector = _isChildrenExtractorToken(token) ? '* > *' : '*';
      return 'html:$selector@$extractor';
    }

    var extractorToken = fallbackExtractor;
    if (segments.length > 1 && _looksLikeExtractorToken(segments.last)) {
      extractorToken = segments.removeLast();
    }

    var selector = sanitizeSelector(
      segments
          .map(_normalizeLegacySelectorToken)
          .where((item) => item.isNotEmpty)
          .join(' '),
    );

    if (selector.isEmpty) {
      if (!_looksLikeStandaloneExtractorToken(extractorToken)) {
        return null;
      }
      selector = '*';
    }

    if (_isChildrenExtractorToken(extractorToken)) {
      selector = '$selector > *';
    }

    final extractor = _normalizeExtractorToken(
      extractorToken,
      fallbackExtractor: fallbackExtractor,
      preferredAttribute: preferredAttribute,
    );

    return 'html:$selector@$extractor';
  }

  static String? buildHtmlRuleExpression({
    required String expression,
    required String fallbackExtractor,
    String? preferredAttribute,
  }) {
    final candidates = expression
        .split('||')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .map(
          (item) => buildHtmlRuleCandidate(
            stage: item,
            fallbackExtractor: fallbackExtractor,
            preferredAttribute: preferredAttribute,
          ),
        )
        .whereType<String>()
        .toSet()
        .toList(growable: false);

    if (candidates.isEmpty) {
      return null;
    }

    return candidates.join('||');
  }

  static String sanitizeSelector(String selector) {
    final value = selector.trim();
    if (value.isEmpty) {
      return value;
    }

    final normalized = value
        .replaceAll('@', ' ')
        .replaceAll('&&', ' ')
        .replaceAll(RegExp(r':nth-child\([^\)]*\)'), '')
        .replaceAll(RegExp(r':nth-last-child\([^\)]*\)'), '')
        .replaceAllMapped(
          RegExp(r'(^|\s)//+'),
          (match) => match.group(1) ?? '',
        );

    final cleaned =
        normalized
            .split(RegExp(r'\s+'))
            .map(_normalizeLegacySelectorToken)
            .where((item) => item.isNotEmpty)
            .join(' ')
            .replaceAll(RegExp(r'\[[^\]]*$'), '')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();

    return cleaned;
  }

  static String _normalizeLegacySelectorToken(String token) {
    var value = _stripLegacySelectorDecorations(token);
    if (value.isEmpty) {
      return '';
    }

    if (_looksLikeExtractorToken(value)) {
      return '';
    }

    if (value.startsWith('tag.')) {
      value = value.substring(4).trim();
      if (value.isEmpty) {
        return '';
      }

      final parts = value
          .split('.')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
      if (parts.isEmpty) {
        return '';
      }

      final tagName = parts.first;
      final classes = parts.skip(1);
      if (classes.isEmpty) {
        return tagName;
      }

      final classSuffix = classes.map((item) => '.$item').join();
      return '$tagName$classSuffix';
    }

    if (value.startsWith('class.')) {
      value = value.substring(6).trim();
      if (value.isEmpty) {
        return '';
      }

      final classes = value
          .replaceAll('.', ' ')
          .split(RegExp(r'\s+'))
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
      if (classes.isEmpty) {
        return '';
      }

      return classes.map((item) => '.$item').join();
    }

    if (value.startsWith('id.')) {
      value = value.substring(3).trim();
      if (value.isEmpty) {
        return '';
      }

      final segments = value
          .replaceAll('.', ' ')
          .split(RegExp(r'\s+'))
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
      if (segments.isEmpty) {
        return '';
      }

      final idName = segments.first;
      final classes = segments.skip(1).map((item) => '.$item').join();
      return '#$idName$classes';
    }

    return value;
  }

  static String _stripLegacySelectorDecorations(String token) {
    var value = token.trim();
    if (value.isEmpty) {
      return value;
    }

    final replaceIndex = value.indexOf('##');
    if (replaceIndex >= 0) {
      value = value.substring(0, replaceIndex).trim();
    }

    value =
        value
            .replaceAll(RegExp(r'\[[!?-]?\d+\]'), '')
            .replaceAll(RegExp(r'!\s*-?\d+(?::-?\d+)*'), '')
            .replaceAll(RegExp(r'\.-?\d+\b'), '')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();

    return value;
  }

  static bool _looksLikeExtractorToken(String token) {
    var value = token.trim();
    if (value.isEmpty) {
      return false;
    }

    final replaceIndex = value.indexOf('##');
    if (replaceIndex >= 0) {
      value = value.substring(0, replaceIndex).trim();
    }

    final normalized = value.toLowerCase();
    if (normalized == 'text' ||
        normalized == 'html' ||
        normalized == 'url' ||
        normalized == 'href' ||
        normalized == 'src' ||
        normalized == 'textnodes' ||
        normalized == 'innerhtml' ||
        normalized == 'outerhtml' ||
        normalized == 'content' ||
        normalized == 'children' ||
        normalized == 'child') {
      return true;
    }

    if (normalized.startsWith('attr(') && normalized.endsWith(')')) {
      return true;
    }

    return normalized.startsWith('data-') || normalized.startsWith('aria-');
  }

  static bool _looksLikeStandaloneExtractorToken(String token) {
    final normalized = token.trim().toLowerCase();
    if (_looksLikeExtractorToken(normalized)) {
      return true;
    }
    return normalized == 'title' || normalized == 'alt';
  }

  static bool _isChildrenExtractorToken(String token) {
    final normalized = token.trim().toLowerCase();
    return normalized == 'children' || normalized == 'child';
  }

  static String _normalizeExtractorToken(
    String extractorToken, {
    required String fallbackExtractor,
    String? preferredAttribute,
  }) {
    var token = extractorToken.trim();
    if (token.isEmpty) {
      return fallbackExtractor;
    }

    final replaceIndex = token.indexOf('##');
    if (replaceIndex >= 0) {
      token = token.substring(0, replaceIndex).trim();
    }

    if (token.isEmpty) {
      return fallbackExtractor;
    }

    final normalized = token.toLowerCase();
    if (normalized == 'text' || normalized == 'html') {
      return normalized;
    }

    if (normalized == 'textnodes') {
      return 'text';
    }

    if (normalized == 'innerhtml') {
      return 'html';
    }

    if (normalized == 'outerhtml' ||
        normalized == 'children' ||
        normalized == 'child') {
      return 'outerhtml';
    }

    if (normalized.startsWith('attr(') && normalized.endsWith(')')) {
      return normalized;
    }

    final attrName = switch (normalized) {
      'url' => preferredAttribute ?? 'href',
      _ => normalized,
    };

    final isSimpleAttr = RegExp(r'^[a-zA-Z][a-zA-Z0-9_-]*$').hasMatch(attrName);
    if (isSimpleAttr) {
      return 'attr($attrName)';
    }

    return fallbackExtractor;
  }
}

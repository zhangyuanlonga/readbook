import 'dart:convert';

String normalizeWebViewCookieResult(Object? value) {
  var text = value?.toString().trim() ?? '';
  if (text.isEmpty || text == 'null' || text == 'undefined') {
    return '';
  }

  if (_looksLikeQuotedJson(text)) {
    try {
      final decoded = jsonDecode(text);
      if (decoded is String) {
        text = decoded.trim();
      }
    } catch (_) {
      text = _stripMatchingQuotes(text);
    }
  }

  return text
      .split(';')
      .map((part) => part.trim())
      .where(_isCookiePair)
      .join('; ');
}

bool hasUsableCookieHeader(String value) {
  return value.split(';').map((part) => part.trim()).any(_isCookiePair);
}

Map<String, String> normalizeWebViewStringMapResult(Object? value) {
  Object? decoded = value?.toString().trim() ?? '';
  for (var index = 0; index < 2; index += 1) {
    if (decoded is! String) {
      break;
    }
    final text = decoded.trim();
    if (text.isEmpty || text == 'null' || text == 'undefined') {
      return const <String, String>{};
    }
    try {
      decoded = jsonDecode(text);
    } catch (_) {
      decoded = _stripMatchingQuotes(text);
      break;
    }
  }
  if (decoded is! Map) {
    return const <String, String>{};
  }
  final normalized = <String, String>{};
  for (final entry in decoded.entries) {
    final key = entry.key?.toString().trim() ?? '';
    final itemValue = entry.value?.toString().trim() ?? '';
    if (key.isNotEmpty && itemValue.isNotEmpty) {
      normalized[key] = itemValue;
    }
  }
  return Map.unmodifiable(normalized);
}

bool _looksLikeQuotedJson(String value) {
  if (value.length < 2) {
    return false;
  }
  return (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"));
}

String _stripMatchingQuotes(String value) {
  if (!_looksLikeQuotedJson(value)) {
    return value;
  }
  return value.substring(1, value.length - 1).trim();
}

bool _isCookiePair(String part) {
  final separator = part.indexOf('=');
  if (separator <= 0) {
    return false;
  }
  final name = part.substring(0, separator).trim();
  return name.isNotEmpty && !name.contains('\n') && !name.contains('\r');
}

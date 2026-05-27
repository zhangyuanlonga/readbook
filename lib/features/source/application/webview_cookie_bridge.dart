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

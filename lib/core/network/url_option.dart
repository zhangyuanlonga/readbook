import 'dart:convert';

import 'request_context.dart';

class UrlOption {
  const UrlOption({
    this.method = HttpRequestMethod.get,
    this.responseCharset,
    this.headers = const <String, String>{},
    this.body,
    this.contentType,
    this.retry,
    this.enabledCookieJar,
    this.sourceRegex,
  });

  final HttpRequestMethod method;
  final String? responseCharset;
  final Map<String, String> headers;
  final Object? body;
  final String? contentType;
  final int? retry;
  final bool? enabledCookieJar;
  final String? sourceRegex;

  factory UrlOption.fromMap(Map<String, dynamic> options) {
    final methodText =
        (options['method'] ?? '').toString().trim().toUpperCase();
    final method = switch (methodText) {
      'POST' => HttpRequestMethod.post,
      'HEAD' => HttpRequestMethod.head,
      _ => HttpRequestMethod.get,
    };

    final responseCharset = _asNullableString(
      options['responseCharset'] ??
          options['response-charset'] ??
          options['charset'],
    );
    final contentType = _asNullableString(
      options['contentType'] ?? options['content-type'] ?? options['type'],
    );
    final retry = _asNullableInt(options['retry']);
    final enabledCookieJar = _asNullableBool(
      options['enabledCookieJar'] ??
          options['enabledcookiejar'] ??
          options['enabled_cookie_jar'],
    );
    final sourceRegex = _asNullableString(
      options['sourceRegex'] ?? options['source_regex'],
    );

    return UrlOption(
      method: method,
      responseCharset: responseCharset,
      headers: UrlOptionParser.parseHeaders(
        options['headers'] ?? options['header'],
      ),
      body: _normalizeBodyTemplate(options['body']),
      contentType: contentType,
      retry: retry,
      enabledCookieJar: enabledCookieJar,
      sourceRegex: sourceRegex,
    );
  }

  static Object? _normalizeBodyTemplate(Object? value) {
    if (value is String) {
      final text = value.trim();
      if (text.isEmpty) {
        return null;
      }
      return text;
    }
    return value;
  }

  static String? _asNullableString(Object? value) {
    if (value == null) {
      return null;
    }
    final text = value.toString().trim();
    if (text.isEmpty) {
      return null;
    }
    return text;
  }

  static bool? _asNullableBool(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is bool) {
      return value;
    }
    final text = value.toString().trim().toLowerCase();
    if (text.isEmpty) {
      return null;
    }
    if (text == 'true' || text == '1' || text == 'yes') {
      return true;
    }
    if (text == 'false' || text == '0' || text == 'no') {
      return false;
    }
    return null;
  }

  static int? _asNullableInt(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    final text = value.toString().trim();
    if (text.isEmpty) {
      return null;
    }
    return int.tryParse(text);
  }
}

class ParsedUrlOptionRule {
  const ParsedUrlOptionRule({
    required this.urlTemplate,
    required this.optionsText,
    required this.options,
  });

  final String urlTemplate;
  final String optionsText;
  final UrlOption options;
}

class UrlOptionParser {
  const UrlOptionParser._();

  static ParsedUrlOptionRule? parseRule(String rawRule) {
    final normalized = rawRule.trim();
    final split = splitRule(normalized);
    if (split == null) {
      return null;
    }

    final optionsMap = decodeOptionsMap(split.optionsText);
    final option = UrlOption.fromMap(optionsMap);
    return ParsedUrlOptionRule(
      urlTemplate: split.urlTemplate,
      optionsText: split.optionsText,
      options: option,
    );
  }

  static UrlOptionSplitResult? splitRule(String rawRule) {
    final normalized = rawRule.trim();
    final objectStart = _findTrailingObjectStart(normalized);
    if (objectStart == null || objectStart <= 0) {
      return null;
    }

    var commaIndex = objectStart - 1;
    while (commaIndex >= 0 && RegExp(r'\s').hasMatch(normalized[commaIndex])) {
      commaIndex -= 1;
    }

    if (commaIndex < 0 || normalized[commaIndex] != ',') {
      return null;
    }

    final urlTemplate = normalized.substring(0, commaIndex).trim();
    if (urlTemplate.isEmpty) {
      return null;
    }

    final optionsText = normalized.substring(objectStart).trim();
    if (optionsText.isEmpty) {
      return null;
    }

    return UrlOptionSplitResult(
      urlTemplate: urlTemplate,
      optionsText: optionsText,
    );
  }

  static Map<String, dynamic> decodeOptionsMap(String source) {
    try {
      final decoded = jsonDecode(source);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
      }
    } on FormatException {
      // fall through
    }

    final normalized = _normalizePseudoJson(source);
    try {
      final decoded = jsonDecode(normalized);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
      }
    } on FormatException {
      return const <String, dynamic>{};
    }

    return const <String, dynamic>{};
  }

  static Map<String, String> parseHeaders(Object? source) {
    if (source == null) {
      return const <String, String>{};
    }

    final rawHeaders = source is String ? decodeOptionsMap(source) : source;
    if (rawHeaders is! Map) {
      return const <String, String>{};
    }

    final headers = <String, String>{};
    for (final entry in rawHeaders.entries) {
      final key = entry.key.toString().trim();
      final value = entry.value.toString().trim();
      if (key.isNotEmpty && value.isNotEmpty) {
        headers[key] = value;
      }
    }
    return headers;
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

  static String _normalizePseudoJson(String source) {
    return source.replaceAllMapped(RegExp(r"'([^'\\]*(?:\\.[^'\\]*)*)'"), (
      match,
    ) {
      final inner = match.group(1) ?? '';
      final escaped = inner
          .replaceAll(r'\', r'\\')
          .replaceAll('"', r'\"')
          .replaceAll('\n', r'\n');
      return '"$escaped"';
    });
  }
}

class UrlOptionSplitResult {
  const UrlOptionSplitResult({
    required this.urlTemplate,
    required this.optionsText,
  });

  final String urlTemplate;
  final String optionsText;
}

import 'dart:convert';

class SourceLoginCapability {
  const SourceLoginCapability({
    this.hasLoginUrl = false,
    this.hasLoginUi = false,
    this.hasLoginCheckJs = false,
    this.enabledCookieJar = false,
  });

  final bool hasLoginUrl;
  final bool hasLoginUi;
  final bool hasLoginCheckJs;
  final bool enabledCookieJar;

  bool get canOpenLogin => hasLoginUrl || hasLoginUi;
  bool get hasAnyLoginSignal =>
      hasLoginUrl || hasLoginUi || hasLoginCheckJs || enabledCookieJar;

  SourceLoginCapability merge(SourceLoginCapability other) {
    return SourceLoginCapability(
      hasLoginUrl: hasLoginUrl || other.hasLoginUrl,
      hasLoginUi: hasLoginUi || other.hasLoginUi,
      hasLoginCheckJs: hasLoginCheckJs || other.hasLoginCheckJs,
      enabledCookieJar: enabledCookieJar || other.enabledCookieJar,
    );
  }

  factory SourceLoginCapability.fromMap(Map<String, Object?> map) {
    return SourceLoginCapability(
      hasLoginUrl: _boolAt(map, const <String>[
        'hasLoginUrl',
        'has_login_url',
        'hasLogin',
        'has_login',
      ]),
      hasLoginUi: _boolAt(map, const <String>['hasLoginUi', 'has_login_ui']),
      hasLoginCheckJs: _boolAt(map, const <String>[
        'hasLoginCheckJs',
        'has_login_check_js',
        'hasLoginCheck',
        'has_login_check',
      ]),
      enabledCookieJar: _boolAt(map, const <String>[
        'enabledCookieJar',
        'enabled_cookie_jar',
        'enabledCookiejar',
      ]),
    ).merge(_fromRawFields(map));
  }

  factory SourceLoginCapability.fromSourceJson(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return const SourceLoginCapability();
    }
    try {
      final decoded = jsonDecode(normalized);
      if (decoded is Map) {
        return SourceLoginCapability.fromMap(
          decoded.map((key, value) => MapEntry(key.toString(), value)),
        );
      }
    } catch (_) {
      // Keep import/list pages resilient to malformed source JSON.
    }
    return SourceLoginCapability(
      hasLoginUrl: _containsNonEmptyJsonField(normalized, 'loginUrl'),
      hasLoginUi: _containsNonEmptyJsonField(normalized, 'loginUi'),
      hasLoginCheckJs: _containsNonEmptyJsonField(normalized, 'loginCheckJs'),
      enabledCookieJar:
          normalized.contains('"enabledCookieJar":true') ||
          normalized.contains('"enabled_cookie_jar":true'),
    );
  }

  static SourceLoginCapability _fromRawFields(Map<String, Object?> map) {
    return SourceLoginCapability(
      hasLoginUrl: _nonEmptyAt(map, const <String>['loginUrl', 'login_url']),
      hasLoginUi: _nonEmptyAt(map, const <String>['loginUi', 'login_ui']),
      hasLoginCheckJs: _nonEmptyAt(map, const <String>[
        'loginCheckJs',
        'login_check_js',
      ]),
      enabledCookieJar: _boolAt(map, const <String>[
        'enabledCookieJar',
        'enabled_cookie_jar',
        'enabledCookiejar',
      ]),
    );
  }
}

bool _boolAt(Map<String, Object?> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value is bool) return value;
    final text = value?.toString().trim().toLowerCase() ?? '';
    if (text == 'true' || text == '1' || text == 'yes') return true;
  }
  return false;
}

bool _nonEmptyAt(Map<String, Object?> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if ((value?.toString().trim() ?? '').isNotEmpty) {
      return true;
    }
  }
  return false;
}

bool _containsNonEmptyJsonField(String source, String field) {
  final pattern = RegExp(
    '"${RegExp.escape(field)}"\\s*:\\s*"([^"]+)"',
    caseSensitive: false,
  );
  final match = pattern.firstMatch(source);
  return (match?.group(1)?.trim() ?? '').isNotEmpty;
}

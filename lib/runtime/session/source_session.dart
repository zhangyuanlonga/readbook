const String sessionCancellationHandleKey = '__session_cancellation_handle__';

class SessionCancellationHandle {
  const SessionCancellationHandle({required bool Function() isCancelled})
    : _isCancelled = isCancelled;

  final bool Function() _isCancelled;

  bool get isCancelled => _isCancelled();
}

class SessionTaskCancelledException implements Exception {
  const SessionTaskCancelledException([
    this.message = 'Session-bound task was cancelled.',
  ]);

  final String message;

  @override
  String toString() => 'SessionTaskCancelledException: $message';
}

class SourceCookie {
  const SourceCookie({
    required this.name,
    required this.value,
    this.domain,
    this.path = '/',
    this.expiresAt,
    this.isSecure,
    this.isHttpOnly,
    this.hostOnly = false,
  });

  final String name;
  final String value;
  final String? domain;
  final String path;
  final DateTime? expiresAt;
  final bool? isSecure;
  final bool? isHttpOnly;
  final bool hostOnly;

  String? get normalizedDomain {
    final raw = domain?.trim().toLowerCase();
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return raw.startsWith('.') ? raw.substring(1) : raw;
  }

  String get normalizedPath {
    final raw = path.trim();
    if (raw.isEmpty || raw == '/') {
      return '/';
    }
    return raw.startsWith('/') ? raw : '/$raw';
  }

  bool isExpired([DateTime? now]) {
    final expiresAt = this.expiresAt;
    if (expiresAt == null) {
      return false;
    }
    final current = (now ?? DateTime.now()).toUtc();
    return !expiresAt.toUtc().isAfter(current);
  }

  bool matchesUri(Uri uri, {DateTime? now}) {
    if (isExpired(now)) {
      return false;
    }

    final host = uri.host.trim().toLowerCase();
    final domain = normalizedDomain;
    if (domain != null) {
      if (hostOnly) {
        if (host != domain) {
          return false;
        }
      } else if (host != domain && !host.endsWith('.$domain')) {
        return false;
      }
    }

    if ((isSecure ?? false) && uri.scheme.toLowerCase() != 'https') {
      return false;
    }

    return _pathMatches(uri.path, normalizedPath);
  }

  bool hasDomain(String domain) {
    final normalizedTarget = _normalizeCookieDomain(domain);
    if (normalizedTarget == null) {
      return false;
    }
    return normalizedDomain == normalizedTarget;
  }
}

class SourceSession {
  SourceSession({
    required this.sourceId,
    Map<String, Object?>? values,
    Map<String, String>? cookies,
    Map<String, String>? defaultHeaders,
    Iterable<SourceCookie>? cookieEntries,
  }) : _values = values ?? <String, Object?>{},
       _cookieEntries = <SourceCookie>[],
       _defaultHeaders = defaultHeaders ?? <String, String>{} {
    if (cookies != null && cookies.isNotEmpty) {
      mergeCookies(cookies);
    }
    if (cookieEntries != null) {
      mergeCookieEntries(cookieEntries);
    }
  }

  final String sourceId;
  final Map<String, Object?> _values;
  final List<SourceCookie> _cookieEntries;
  final Map<String, String> _defaultHeaders;

  SessionCancellationHandle? get cancellationHandle =>
      get<SessionCancellationHandle>(sessionCancellationHandleKey);

  bool get isCancelled => cancellationHandle?.isCancelled ?? false;

  T? get<T>(String key) {
    final value = _values[key];
    if (value is T) {
      return value;
    }
    return null;
  }

  void set(String key, Object? value) {
    _values[key] = value;
  }

  void clear([String? key]) {
    if (key == null) {
      _values.clear();
      return;
    }
    _values.remove(key);
  }

  void setCookie(
    String name,
    String value, {
    Uri? uri,
    String? domain,
    String path = '/',
    DateTime? expiresAt,
    bool? isSecure,
    bool? isHttpOnly,
    bool? hostOnly,
  }) {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      return;
    }

    final normalizedDomain = _normalizeCookieDomain(
      domain ?? (uri != null && hostOnly != false ? uri.host : null),
    );
    final normalizedPath = _normalizeCookiePath(path);
    final resolvedHostOnly =
        hostOnly ??
        (normalizedDomain != null && domain == null && uri != null
            ? true
            : false);

    final cookie = SourceCookie(
      name: normalizedName,
      value: value,
      domain: normalizedDomain,
      path: normalizedPath,
      expiresAt: expiresAt?.toUtc(),
      isSecure: isSecure,
      isHttpOnly: isHttpOnly,
      hostOnly: resolvedHostOnly,
    );
    _storeCookie(cookie);
  }

  void setCookieEntry(SourceCookie cookie) {
    final normalizedName = cookie.name.trim();
    if (normalizedName.isEmpty) {
      return;
    }

    _storeCookie(
      SourceCookie(
        name: normalizedName,
        value: cookie.value,
        domain: _normalizeCookieDomain(cookie.domain),
        path: _normalizeCookiePath(cookie.path),
        expiresAt: cookie.expiresAt?.toUtc(),
        isSecure: cookie.isSecure,
        isHttpOnly: cookie.isHttpOnly,
        hostOnly: cookie.normalizedDomain != null ? cookie.hostOnly : false,
      ),
    );
  }

  void removeCookie(String name, {String? domain, String? path}) {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      return;
    }
    final normalizedDomain = _normalizeCookieDomain(domain);
    final normalizedPath = path == null ? null : _normalizeCookiePath(path);
    _cookieEntries.removeWhere((SourceCookie cookie) {
      if (cookie.name != normalizedName) {
        return false;
      }
      if (normalizedDomain != null &&
          cookie.normalizedDomain != normalizedDomain) {
        return false;
      }
      if (normalizedPath != null && cookie.normalizedPath != normalizedPath) {
        return false;
      }
      return true;
    });
  }

  Map<String, Object?> get values => Map<String, Object?>.unmodifiable(_values);

  void mergeCookies(Map<String, String> cookies, {Uri? uri}) {
    cookies.forEach((String name, String value) {
      setCookie(name, value, uri: uri);
    });
  }

  void mergeCookieEntries(Iterable<SourceCookie> cookies) {
    for (final cookie in cookies) {
      setCookieEntry(cookie);
    }
  }

  void clearCookies() {
    _cookieEntries.clear();
  }

  void clearCookiesForDomain(String domain) {
    final normalizedDomain = _normalizeCookieDomain(domain);
    if (normalizedDomain == null) {
      return;
    }
    _cookieEntries.removeWhere(
      (SourceCookie cookie) => cookie.normalizedDomain == normalizedDomain,
    );
  }

  Map<String, String> get cookies => Map<String, String>.unmodifiable(
    _toLegacyCookieMap(_activeCookieEntries()),
  );

  List<SourceCookie> get cookieEntries =>
      List<SourceCookie>.unmodifiable(_activeCookieEntries());

  Map<String, String> cookiesForUri(Uri uri) =>
      Map<String, String>.unmodifiable(
        _toLegacyCookieMap(_matchingCookieEntries(uri)),
      );

  List<SourceCookie> cookieEntriesForUri(Uri uri) =>
      List<SourceCookie>.unmodifiable(_matchingCookieEntries(uri));

  String? cookieValueForUri(Uri uri, String name) {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      return null;
    }

    for (final cookie in _matchingCookieEntries(uri)) {
      if (cookie.name == normalizedName) {
        return cookie.value;
      }
    }
    return null;
  }

  String? get cookieHeader => _buildCookieHeader(_activeCookieEntries());

  String? cookieHeaderForUri(Uri uri) {
    return _buildCookieHeader(_matchingCookieEntries(uri));
  }

  void setHeader(String name, String value) {
    _defaultHeaders[name] = value;
  }

  Map<String, String> get defaultHeaders =>
      Map<String, String>.unmodifiable(_defaultHeaders);

  void _storeCookie(SourceCookie cookie) {
    _purgeExpiredCookies();
    _cookieEntries.removeWhere(
      (SourceCookie existing) =>
          existing.name == cookie.name &&
          existing.normalizedDomain == cookie.normalizedDomain &&
          existing.normalizedPath == cookie.normalizedPath &&
          existing.hostOnly == cookie.hostOnly,
    );

    if (cookie.isExpired()) {
      return;
    }
    _cookieEntries.add(cookie);
  }

  List<SourceCookie> _activeCookieEntries() {
    _purgeExpiredCookies();
    return List<SourceCookie>.from(_cookieEntries);
  }

  List<SourceCookie> _matchingCookieEntries(Uri uri) {
    final entries = _activeCookieEntries()
        .where((SourceCookie cookie) => cookie.matchesUri(uri))
        .toList(growable: false);
    entries.sort((SourceCookie left, SourceCookie right) {
      final byPath = right.normalizedPath.length.compareTo(
        left.normalizedPath.length,
      );
      if (byPath != 0) {
        return byPath;
      }

      final leftDomainLength = left.normalizedDomain?.length ?? 0;
      final rightDomainLength = right.normalizedDomain?.length ?? 0;
      return rightDomainLength.compareTo(leftDomainLength);
    });
    return entries;
  }

  void _purgeExpiredCookies() {
    final now = DateTime.now().toUtc();
    _cookieEntries.removeWhere((SourceCookie cookie) => cookie.isExpired(now));
  }

  Map<String, String> _toLegacyCookieMap(Iterable<SourceCookie> cookies) {
    final result = <String, String>{};
    for (final cookie in cookies) {
      result[cookie.name] = cookie.value;
    }
    return result;
  }

  String? _buildCookieHeader(Iterable<SourceCookie> cookies) {
    final parts = cookies
        .map((SourceCookie cookie) => '${cookie.name}=${cookie.value}')
        .toList(growable: false);
    if (parts.isEmpty) {
      return null;
    }
    return parts.join('; ');
  }
}

bool _pathMatches(String requestPath, String cookiePath) {
  final normalizedRequestPath =
      requestPath.trim().isEmpty ? '/' : requestPath.trim();
  if (cookiePath == '/') {
    return true;
  }
  if (normalizedRequestPath == cookiePath) {
    return true;
  }
  if (!normalizedRequestPath.startsWith(cookiePath)) {
    return false;
  }
  if (cookiePath.endsWith('/')) {
    return true;
  }
  return normalizedRequestPath.length > cookiePath.length &&
      normalizedRequestPath[cookiePath.length] == '/';
}

String? _normalizeCookieDomain(String? domain) {
  final raw = domain?.trim().toLowerCase();
  if (raw == null || raw.isEmpty) {
    return null;
  }
  return raw.startsWith('.') ? raw.substring(1) : raw;
}

String _normalizeCookiePath(String path) {
  final raw = path.trim();
  if (raw.isEmpty || raw == '/') {
    return '/';
  }
  return raw.startsWith('/') ? raw : '/$raw';
}

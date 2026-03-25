class SourceSession {
  SourceSession({
    required this.sourceId,
    Map<String, Object?>? values,
    Map<String, String>? cookies,
    Map<String, String>? defaultHeaders,
  }) : _values = values ?? <String, Object?>{},
       _cookies = cookies ?? <String, String>{},
       _defaultHeaders = defaultHeaders ?? <String, String>{};

  final String sourceId;
  final Map<String, Object?> _values;
  final Map<String, String> _cookies;
  final Map<String, String> _defaultHeaders;

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

  void setCookie(String name, String value) {
    _cookies[name] = value;
  }

  void removeCookie(String name) {
    _cookies.remove(name);
  }

  Map<String, Object?> get values => Map<String, Object?>.unmodifiable(_values);

  void mergeCookies(Map<String, String> cookies) {
    _cookies.addAll(cookies);
  }

  void clearCookies() {
    _cookies.clear();
  }

  Map<String, String> get cookies => Map<String, String>.unmodifiable(_cookies);

  String? get cookieHeader {
    if (_cookies.isEmpty) {
      return null;
    }

    return _cookies.entries
        .map((MapEntry<String, String> entry) => '${entry.key}=${entry.value}')
        .join('; ');
  }

  void setHeader(String name, String value) {
    _defaultHeaders[name] = value;
  }

  Map<String, String> get defaultHeaders =>
      Map<String, String>.unmodifiable(_defaultHeaders);
}

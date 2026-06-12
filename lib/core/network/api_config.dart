class AppApiConfig {
  const AppApiConfig._();

  static const String _primaryBaseUrl = String.fromEnvironment(
    'APPREAD_API_BASE_URL',
    defaultValue: '',
  );

  static const String _legacyBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static String get baseUrl {
    final primary = _primaryBaseUrl.trim();
    if (primary.isNotEmpty) {
      return _withTrailingSlash(primary);
    }
    final legacy = _legacyBaseUrl.trim();
    if (legacy.isNotEmpty) {
      return _withTrailingSlash(legacy);
    }
    return 'https://www.sxyd.lltask.top/api/';
  }

  static const String defaultReaderGatewayBaseUrl =
      'https://rust.lltask.top/api/';

  static const String _primaryReaderGatewayBaseUrl = String.fromEnvironment(
    'APPREAD_READER_GATEWAY_BASE_URL',
    defaultValue: '',
  );

  static const String _legacyReaderGatewayBaseUrl = String.fromEnvironment(
    'SERVER_READER_BASE_URL',
    defaultValue: '',
  );

  static String get effectiveReaderGatewayBaseUrl {
    final configured = _primaryReaderGatewayBaseUrl.trim();
    if (configured.isNotEmpty) {
      return _withTrailingSlash(configured);
    }
    final legacy = _legacyReaderGatewayBaseUrl.trim();
    if (legacy.isNotEmpty) {
      return _withTrailingSlash(legacy);
    }
    return defaultReaderGatewayBaseUrl;
  }

  static String _withTrailingSlash(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty || normalized.endsWith('/')) {
      return normalized;
    }
    return '$normalized/';
  }

  static String normalizeBaseUrl(String value) {
    return _withTrailingSlash(value);
  }

  static String readerGatewayApiPath(String baseUrl, String path) {
    final normalized = path.trim();
    if (normalized.startsWith('http://') || normalized.startsWith('https://')) {
      return normalized;
    }
    final relative = normalized.replaceFirst(RegExp(r'^/+'), '');
    final baseHasApi = _baseUrlEndsWithApi(baseUrl);
    if (relative.startsWith('api/')) {
      return baseHasApi ? relative.substring(4) : relative;
    }
    return baseHasApi ? relative : 'api/$relative';
  }

  static bool _baseUrlEndsWithApi(String value) {
    final uri = Uri.tryParse(value.trim());
    final segments =
        uri?.path
            .split('/')
            .map((segment) => segment.trim().toLowerCase())
            .where((segment) => segment.isNotEmpty)
            .toList(growable: false) ??
        const <String>[];
    return segments.isNotEmpty && segments.last == 'api';
  }

  static const String appName = String.fromEnvironment(
    'APPREAD_APP_NAME',
    defaultValue: 'selune',
  );
}

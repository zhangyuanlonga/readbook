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
      return primary;
    }
    final legacy = _legacyBaseUrl.trim();
    if (legacy.isNotEmpty) {
      return legacy;
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
      return configured;
    }
    final legacy = _legacyReaderGatewayBaseUrl.trim();
    if (legacy.isNotEmpty) {
      return legacy;
    }
    return defaultReaderGatewayBaseUrl;
  }

  static const String appName = String.fromEnvironment(
    'APPREAD_APP_NAME',
    defaultValue: 'selune',
  );
}

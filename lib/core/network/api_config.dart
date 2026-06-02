class AppApiConfig {
  const AppApiConfig._();

  static const String baseUrl = String.fromEnvironment(
    'APPREAD_API_BASE_URL',
    defaultValue: 'https://www.sxyd.lltask.top/api/',
  );

  static const String defaultReaderGatewayBaseUrl =
      'https://rust.lltask.top/api/';

  static const String readerGatewayBaseUrl = String.fromEnvironment(
    'APPREAD_READER_GATEWAY_BASE_URL',
    defaultValue: '',
  );

  static String get effectiveReaderGatewayBaseUrl {
    final configured = readerGatewayBaseUrl.trim();
    if (configured.isNotEmpty) {
      return configured;
    }
    return defaultReaderGatewayBaseUrl;
  }

  static const String appName = String.fromEnvironment(
    'APPREAD_APP_NAME',
    defaultValue: 'selune',
  );
}

class AppApiConfig {
  const AppApiConfig._();

  static const String baseUrl = String.fromEnvironment(
    'APPREAD_API_BASE_URL',
    defaultValue: 'https://www.sxyd.lltask.top/api/',
  );

  static const String appName = String.fromEnvironment(
    'APPREAD_APP_NAME',
    defaultValue: 'selune',
  );
}

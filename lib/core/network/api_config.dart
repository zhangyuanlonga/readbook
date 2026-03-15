class AppApiConfig {
  const AppApiConfig._();

  static const String baseUrl = String.fromEnvironment(
    'APPREAD_API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );

  static const String appName = String.fromEnvironment(
    'APPREAD_APP_NAME',
    defaultValue: 'reader-app',
  );
}

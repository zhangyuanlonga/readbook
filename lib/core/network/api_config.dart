class AppApiConfig {
  const AppApiConfig._();

  static const String baseUrl = String.fromEnvironment(
    'APPREAD_API_BASE_URL',
    //  请求正式地址
    defaultValue: 'https://www.sxyd.lltask.top/api/',
    // defaultValue: 'http://localhost:8080',
  );

  static const String appName = String.fromEnvironment(
    'APPREAD_APP_NAME',
    defaultValue: 'reader-app',
  );
}

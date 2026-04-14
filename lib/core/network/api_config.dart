class AppApiConfig {
  const AppApiConfig._();

  static const String baseUrl = String.fromEnvironment(
    'APPREAD_API_BASE_URL',
    // 测试环境
    defaultValue: 'http://localhost:8080',
    // 正式环境
    // defaultValue: 'https://www.sxyd.lltask.top/api/',
  );

  static const String appName = String.fromEnvironment(
    'APPREAD_APP_NAME',
    defaultValue: 'reader-app',
  );
}

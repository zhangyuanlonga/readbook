import 'package:flutter/foundation.dart';

class AppApiConfig {
  const AppApiConfig._();

  static const String baseUrl = String.fromEnvironment(
    'APPREAD_API_BASE_URL',
    defaultValue: 'https://www.sxyd.lltask.top/api/',
  );

  static const String readerGatewayBaseUrl = String.fromEnvironment(
    'APPREAD_READER_GATEWAY_BASE_URL',
    defaultValue: '',
  );

  static String get effectiveReaderGatewayBaseUrl {
    final configured = readerGatewayBaseUrl.trim();
    if (configured.isNotEmpty) {
      return configured;
    }
    if (kDebugMode) {
      if (defaultTargetPlatform == TargetPlatform.android) {
        return 'http://10.0.2.2:8080/api/';
      }
      return 'http://127.0.0.1:8080/api/';
    }
    return baseUrl;
  }

  static const String appName = String.fromEnvironment(
    'APPREAD_APP_NAME',
    defaultValue: 'selune',
  );
}

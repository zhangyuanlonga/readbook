import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/core/network/api_config.dart';

void main() {
  group('AppApiConfig', () {
    test('uses Rust reader gateway as the default online source endpoint', () {
      expect(
        AppApiConfig.effectiveReaderGatewayBaseUrl,
        'https://rust.lltask.top/api/',
      );
    });
  });
}

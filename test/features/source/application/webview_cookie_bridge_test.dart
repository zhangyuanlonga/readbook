import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/source/application/webview_cookie_bridge.dart';

void main() {
  group('normalizeWebViewCookieResult', () {
    test('decodes quoted JavaScript result and trims cookie pairs', () {
      final cookie = normalizeWebViewCookieResult('" sid=abc ; token=def "');

      expect(cookie, 'sid=abc; token=def');
      expect(hasUsableCookieHeader(cookie), isTrue);
    });

    test('filters invalid fragments and empty results', () {
      expect(normalizeWebViewCookieResult('sid=abc; broken; =skip'), 'sid=abc');
      expect(normalizeWebViewCookieResult('undefined'), isEmpty);
      expect(hasUsableCookieHeader('broken; =skip'), isFalse);
    });
  });
}

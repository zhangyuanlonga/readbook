import 'package:shuxiang_reading_next/core/network/request_context.dart';
import 'package:shuxiang_reading_next/core/network/url_option.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UrlOptionParser', () {
    test('parses url with option object', () {
      final parsed = UrlOptionParser.parseRule(
        'https://example.com/search,{"method":"POST","body":"k=v","charset":"GBK","retry":2,"webView":true,"webViewDelay":1800,"enabledCookieJar":true}',
      );

      expect(parsed, isNotNull);
      expect(parsed!.urlTemplate, 'https://example.com/search');
      expect(parsed.options.method, HttpRequestMethod.post);
      expect(parsed.options.body, 'k=v');
      expect(parsed.options.responseCharset, 'GBK');
      expect(parsed.options.retry, 2);
      expect(parsed.options.webView, isTrue);
      expect(parsed.options.webViewDelay, const Duration(milliseconds: 1800));
      expect(parsed.options.enabledCookieJar, isTrue);
    });

    test('supports pseudo json single quotes', () {
      final parsed = UrlOptionParser.parseRule(
        "https://example.com/a,{'method':'GET','headers':{'X-Test':'1'}}",
      );

      expect(parsed, isNotNull);
      expect(parsed!.options.method, HttpRequestMethod.get);
      expect(parsed.options.headers['X-Test'], '1');
    });
  });
}

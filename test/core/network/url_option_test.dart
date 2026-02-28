import 'package:flutter_appread/core/network/request_context.dart';
import 'package:flutter_appread/core/network/url_option.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UrlOptionParser', () {
    test('parses url with option object', () {
      final parsed = UrlOptionParser.parseRule(
        'https://example.com/search,{"method":"POST","body":"k=v","charset":"GBK","retry":2,"webView":true}',
      );

      expect(parsed, isNotNull);
      expect(parsed!.urlTemplate, 'https://example.com/search');
      expect(parsed.options.method, HttpRequestMethod.post);
      expect(parsed.options.body, 'k=v');
      expect(parsed.options.responseCharset, 'GBK');
      expect(parsed.options.retry, 2);
      expect(parsed.options.webView, isTrue);
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

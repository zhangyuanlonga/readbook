import 'package:flutter_appread/core/rule_engine/processors/legacy_link_post_processor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LegacyLinkPostProcessor', () {
    test('applies regex replace and js append suffix', () {
      final value = LegacyLinkPostProcessor.apply(
        value: "openChapter('/c1')",
        rawRule:
            r'.link@onclick##.*\((.*)\).*##$1@js:result+",{"webView":true}"',
      );

      expect(value, '/c1,{"webView":true}');
    });

    test('applies js replace suffix', () {
      final value = LegacyLinkPostProcessor.apply(
        value: '/go/123',
        rawRule: '.name@href@js:result.replace("go/", "book_")',
      );

      expect(value, '/book_123');
    });

    test('supports js suffix with match and parseInt composition', () {
      final value = LegacyLinkPostProcessor.apply(
        value: '/book/12345.html',
        rawRule: r'''
a@href@js:
var id = result.match(/(\d+).html\/?$/)[1];
var iid = parseInt(id/1000);
'https://www.00shu.la/'+iid+'/'+id+'/';
''',
      );

      expect(value, 'https://www.00shu.la/12/12345/');
    });

    test('extracts url from onclick-like script text', () {
      final value = LegacyLinkPostProcessor.apply(
        value: "javascript:open('/chapter/9')",
      );

      expect(value, '/chapter/9');
    });
  });
}

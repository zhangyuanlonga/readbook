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

    test('extracts url from onclick-like script text', () {
      final value = LegacyLinkPostProcessor.apply(
        value: "javascript:open('/chapter/9')",
      );

      expect(value, '/chapter/9');
    });
  });
}

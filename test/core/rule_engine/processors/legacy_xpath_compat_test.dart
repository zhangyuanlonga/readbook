import 'package:flutter_appread/core/rule_engine/processors/legacy_xpath_compat.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LegacyXPathCompat', () {
    test('detects xpath expressions', () {
      expect(LegacyXPathCompat.looksLikeXPathExpression('//div/a'), isTrue);
      expect(
        LegacyXPathCompat.looksLikeXPathExpression('@xpath://div/a'),
        isTrue,
      );
      expect(LegacyXPathCompat.looksLikeXPathExpression('.item@html'), isFalse);
    });

    test('builds html rule with xpath attribute accessor', () {
      final expression = LegacyXPathCompat.buildRuleExpression(
        expression: '//div[@class="item"]/a/@href',
        fallbackExtractor: 'text',
      );

      expect(expression, 'html:div.item a@attr(href)');
    });

    test('builds native xpath expression with legacy fallback', () {
      final expression = LegacyXPathCompat.buildNativeRuleExpression(
        expression: '//div[@class="item"]/a/@href',
        fallbackExtractor: 'text',
      );

      expect(
        expression,
        'xpath://div[@class="item"]/a/@href@attr(href)||html:div.item a@attr(href)',
      );
    });

    test('keeps explicit xpath extractor suffix', () {
      final expression = LegacyXPathCompat.buildNativeRuleExpression(
        expression: '//div[@class="item"]@outerhtml',
        fallbackExtractor: 'text',
      );

      expect(
        expression,
        'xpath://div[@class="item"]@outerhtml||html:div.item@outerhtml',
      );
    });
  });
}

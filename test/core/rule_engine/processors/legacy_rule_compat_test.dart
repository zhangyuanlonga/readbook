import 'package:flutter_appread/core/rule_engine/processors/legacy_rule_compat.dart';
import 'package:flutter_appread/core/rule_engine/rule_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LegacyRuleCompat', () {
    test('builds html rule from legacy chain selector', () {
      final expression = LegacyRuleCompat.buildHtmlRuleCandidate(
        stage: 'tag.td.0@a@href',
        fallbackExtractor: 'text',
      );

      expect(expression, 'html:td a@attr(href)');
    });

    test('builds html list rule without explicit extractor', () {
      final expression = LegacyRuleCompat.buildHtmlRuleCandidate(
        stage: 'class.main-wrap@class.sort-list search_words@tag.li[!0]',
        fallbackExtractor: 'html',
      );

      expect(expression, 'html:.main-wrap .sort-list.search_words li@html');
    });

    test('keeps legacy && chain in selector path', () {
      final expression = LegacyRuleCompat.buildHtmlRuleExpression(
        expression: '.search&&li!0&&a',
        fallbackExtractor: 'html',
      );

      expect(expression, 'html:.search li a@html');
    });

    test('supports bare extractor as current node rule', () {
      final titleRule = LegacyRuleCompat.buildHtmlRuleExpression(
        expression: 'text',
        fallbackExtractor: 'text',
      );
      final hrefRule = LegacyRuleCompat.buildHtmlRuleExpression(
        expression: 'href',
        fallbackExtractor: 'attr(href)',
      );

      expect(titleRule, 'html:*@text');
      expect(hrefRule, 'html:*@attr(href)');
    });

    test('supports children extractor for list chunks', () {
      final expression = LegacyRuleCompat.buildHtmlRuleExpression(
        expression: 'class.list@children',
        fallbackExtractor: 'html',
      );

      expect(expression, 'html:.list > *@outerhtml');
    });

    test('builds expression with legacy fallback branches', () {
      final expression = LegacyRuleCompat.buildHtmlRuleExpression(
        expression: 'id.main@tag.a||class.recommend mybook@tag.a',
        fallbackExtractor: 'html',
      );

      expect(expression, 'html:#main a@html||html:.recommend.mybook a@html');
    });

    test('sanitizes unsupported selector suffix', () {
      final selector = LegacyRuleCompat.sanitizeSelector(
        '.s2 a.0:nth-child(1)',
      );

      expect(selector, '.s2 a');
    });

    test('rule engine retries with compatibility selector', () {
      final engine = RuleEngine();
      const html = '<div class="s2"><a href="/book/1">Book</a></div>';

      final values = engine.executeAll(
        content: html,
        expression: 'html:.s2 a.0@attr(href)',
      );

      expect(values, ['/book/1']);
    });

    test('normalizes selectors extracted from source104 diagnostics', () {
      final cases = <String, String>{
        'li.1': 'li',
        'p.0': 'p',
        '.s2 a.0': '.s2 a',
        'div.author.0': 'div.author',
        'tag.a.0': 'a',
        '//div[': 'div',
        'tag.a!0:1:2:3': 'a',
      };

      for (final entry in cases.entries) {
        expect(
          LegacyRuleCompat.sanitizeSelector(entry.key),
          entry.value,
          reason: 'selector: ${entry.key}',
        );
      }
    });

    test('sanitizes @css selector with regex attr and jquery pseudo', () {
      final selector = LegacyRuleCompat.sanitizeSelector(
        r'@css:.listmain a[href~=/[^/]+/\d+.htm]:eq(0)[1:3]',
      );

      expect(selector, '.listmain a[href]:nth-child(1)');
    });

    test('rule engine supports jquery pseudo selector via compat fallback', () {
      final engine = RuleEngine();
      const html = '''
        <ul class="list">
          <li>第一章</li>
          <li>第二章</li>
          <li>第三章</li>
        </ul>
      ''';

      final values = engine.executeAll(
        content: html,
        expression: 'html:.list li:eq(1)@text',
      );

      expect(values, ['第二章']);
    });
  });
}

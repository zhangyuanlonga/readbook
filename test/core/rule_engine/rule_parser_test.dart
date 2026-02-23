import 'package:flutter_appread/core/errors/app_exception.dart';
import 'package:flutter_appread/core/rule_engine/rule_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RuleParser', () {
    const parser = RuleParser();

    test('parses html rule with attr extractor', () {
      final parsed = parser.parse('html:.book > a@attr(href)');

      expect(parsed, isA<ParsedHtmlRule>());
      final rule = parsed as ParsedHtmlRule;
      expect(rule.selector, '.book > a');
      expect(rule.extractor.type, HtmlExtractorType.attr);
      expect(rule.extractor.attributeName, 'href');
    });

    test('parses html rule with outerhtml extractor', () {
      final parsed = parser.parse('html:.book@outerhtml');

      expect(parsed, isA<ParsedHtmlRule>());
      final rule = parsed as ParsedHtmlRule;
      expect(rule.selector, '.book');
      expect(rule.extractor.type, HtmlExtractorType.outerHtml);
      expect(rule.extractor.attributeName, isNull);
    });

    test('parses regex rule with group and flags', () {
      final parsed = parser.parse(r'regex:book/(\d+)::group=1::flags=im');

      expect(parsed, isA<ParsedRegexRule>());
      final rule = parsed as ParsedRegexRule;
      expect(rule.pattern, r'book/(\d+)');
      expect(rule.group, 1);
      expect(rule.caseSensitive, isFalse);
      expect(rule.multiLine, isTrue);
      expect(rule.dotAll, isFalse);
    });

    test('parses json rule', () {
      final parsed = parser.parse(r'json:$.booklist[*]');

      expect(parsed, isA<ParsedJsonRule>());
      final rule = parsed as ParsedJsonRule;
      expect(rule.expression, r'$.booklist[*]');
    });

    test('throws on unsupported prefix', () {
      expect(() => parser.parse('css:.item'), throwsA(isA<AppException>()));
    });
  });
}

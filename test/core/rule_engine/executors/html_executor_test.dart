import 'package:flutter_appread/core/errors/app_exception.dart';
import 'package:flutter_appread/core/rule_engine/executors/html_executor.dart';
import 'package:flutter_appread/core/rule_engine/rule_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HtmlExecutor', () {
    const executor = HtmlExecutor();

    const html = '''
    <div class="book">
      <a href="/book/1">Book A</a>
      <a href="/book/2">Book B</a>
    </div>
    ''';

    test('extracts text values', () {
      const rule = ParsedHtmlRule(
        selector: '.book a',
        extractor: HtmlExtractor.text(),
      );

      final values = executor.execute(content: html, rule: rule);
      expect(values, ['Book A', 'Book B']);
    });

    test('extracts attribute values', () {
      const rule = ParsedHtmlRule(
        selector: '.book a',
        extractor: HtmlExtractor.attr('href'),
      );

      final values = executor.execute(content: html, rule: rule);
      expect(values, ['/book/1', '/book/2']);
    });

    test('throws on no matches', () {
      const rule = ParsedHtmlRule(
        selector: '.missing',
        extractor: HtmlExtractor.text(),
      );

      expect(
        () => executor.execute(content: html, rule: rule),
        throwsA(isA<RuleMatchEmptyException>()),
      );
    });

    test('supports td/tr selectors for table row fragments', () {
      const rowFragment =
          '<tr><td><a href="/book/1">Book A</a></td><td>作者</td></tr>';
      const rule = ParsedHtmlRule(
        selector: 'td a',
        extractor: HtmlExtractor.attr('href'),
      );

      final values = executor.execute(content: rowFragment, rule: rule);
      expect(values, ['/book/1']);
    });
  });
}

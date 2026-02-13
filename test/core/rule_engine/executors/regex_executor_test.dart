import 'package:flutter_appread/core/errors/app_exception.dart';
import 'package:flutter_appread/core/rule_engine/executors/regex_executor.dart';
import 'package:flutter_appread/core/rule_engine/rule_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RegexExecutor', () {
    const executor = RegexExecutor();

    const content = 'book/1001 title=Alpha\nbook/1002 title=Beta';

    test('extracts values by group', () {
      const rule = ParsedRegexRule(
        pattern: r'book/(\d+)',
        group: 1,
        caseSensitive: true,
        multiLine: true,
        dotAll: false,
      );

      final values = executor.execute(content: content, rule: rule);
      expect(values, ['1001', '1002']);
    });

    test('throws when group is out of range', () {
      const rule = ParsedRegexRule(
        pattern: r'book/(\d+)',
        group: 2,
        caseSensitive: true,
        multiLine: false,
        dotAll: false,
      );

      expect(
        () => executor.execute(content: content, rule: rule),
        throwsA(isA<AppException>()),
      );
    });

    test('throws when no match', () {
      const rule = ParsedRegexRule(
        pattern: r'chapter/(\d+)',
        group: 1,
        caseSensitive: true,
        multiLine: false,
        dotAll: false,
      );

      expect(
        () => executor.execute(content: content, rule: rule),
        throwsA(isA<RuleMatchEmptyException>()),
      );
    });
  });
}

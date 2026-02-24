import 'package:flutter_appread/core/rule_engine/processors/legacy_rule_variable_processor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LegacyRuleVariableProcessor', () {
    test('extracts @put values and replaces @get placeholders', () {
      final variables = <String, String>{};
      final expression = LegacyRuleVariableProcessor.resolveExpression(
        expression: '@put:{bid:\$.id,url:"a@href"}\nhttps://a.com/@get:{bid}',
        variables: variables,
        resolvePutValue: (valueExpression) {
          if (valueExpression == r'$.id') {
            return '1001';
          }
          if (valueExpression == 'a@href') {
            return '/book/1001';
          }
          return null;
        },
      );

      expect(expression, 'https://a.com/1001');
      expect(variables['bid'], '1001');
      expect(variables[r'$.bid'], '1001');
      expect(variables['url'], '/book/1001');
    });

    test('supports quoted @get keys and leaves unresolved keys empty', () {
      final variables = <String, String>{'token': 'abc'};
      final expression = LegacyRuleVariableProcessor.replaceGetTokens(
        'header=@get:{"token"}&miss=@get:{none}',
        variables,
      );

      expect(expression, 'header=abc&miss=');
    });

    test('detects variable syntax tokens', () {
      expect(
        LegacyRuleVariableProcessor.containsVariableSyntax('@put:{a:1}'),
        isTrue,
      );
      expect(
        LegacyRuleVariableProcessor.containsVariableSyntax(
          'https://a.com/@get:{a}',
        ),
        isTrue,
      );
      expect(
        LegacyRuleVariableProcessor.containsVariableSyntax('.item@html'),
        isFalse,
      );
    });
  });
}

import 'package:flutter_appread/core/errors/app_exception.dart';
import 'package:flutter_appread/features/source/application/source_validator.dart';
import 'package:flutter_appread/domain/entities/source_definition.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SourceValidator', () {
    const validator = SourceValidator();

    test('passes for valid source', () {
      final source = SourceDefinition(
        id: 'id-1',
        name: '测试源',
        baseUrl: 'https://example.com',
        rules: const SourceRuleSet(searchRule: '/search?key={{key}}'),
      );

      expect(() => validator.validate(source), returnsNormally);
    });

    test(
      'allows non-http base url when search rule already has absolute url',
      () {
        final source = SourceDefinition(
          id: 'id-2',
          name: '测试源2',
          baseUrl: 'DQuestQBall',
          rules: const SourceRuleSet(
            searchRule:
                'https://bookshelf.html5.qq.com/qbread/api/search?key={{key}}',
          ),
        );

        expect(() => validator.validate(source), returnsNormally);
      },
    );

    test('fails for invalid base url', () {
      final source = SourceDefinition(
        id: 'id-1',
        name: '测试源',
        baseUrl: 'example.com',
        rules: const SourceRuleSet(searchRule: '/search?key={{key}}'),
      );

      expect(() => validator.validate(source), throwsA(isA<AppException>()));
    });

    test('fails for missing search rule', () {
      final source = SourceDefinition(
        id: 'id-1',
        name: '测试源',
        baseUrl: 'https://example.com',
      );

      expect(() => validator.validate(source), throwsA(isA<AppException>()));
    });
  });
}

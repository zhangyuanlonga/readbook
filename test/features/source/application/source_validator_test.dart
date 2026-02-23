import 'package:flutter_appread/core/errors/app_exception.dart';
import 'package:flutter_appread/domain/entities/source_definition.dart';
import 'package:flutter_appread/features/source/application/source_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SourceValidator', () {
    const validator = SourceValidator();

    test('passes for valid source', () {
      final source = SourceDefinition(
        id: 'id-1',
        name: '测试源',
        baseUrl: 'https://example.com',
        rules: const SourceRuleSet(
          searchRule: '/search?key={{key}}',
          searchListRule: '.item@html',
          searchTitleRule: '.name@text',
          searchDetailUrlRule: '.name@href',
          tocListRule: '.chapter@html',
          tocTitleRule: 'a@text',
          tocChapterUrlRule: 'a@href',
          contentRule: '#content@html',
        ),
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
            searchListRule: r'$.booklist[*]',
            searchTitleRule: r'$.title',
            searchDetailUrlRule: r'$.url',
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
        rules: const SourceRuleSet(
          searchRule: '/search?key={{key}}',
          searchListRule: '.item@html',
          searchTitleRule: '.name@text',
          searchDetailUrlRule: '.name@href',
        ),
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

    test('fails for missing search parse rules', () {
      final source = SourceDefinition(
        id: 'id-3',
        name: '解析缺失源',
        baseUrl: 'https://example.com',
        rules: const SourceRuleSet(searchRule: '/search?key={{key}}'),
      );

      expect(
        () => validator.validate(source),
        throwsA(
          isA<AppException>().having(
            (error) => error.briefMessage,
            'briefMessage',
            contains('缺少搜索解析规则'),
          ),
        ),
      );
    });

    test('collects toc/content warnings for partial source', () {
      final source = SourceDefinition(
        id: 'id-4',
        name: '部分源',
        baseUrl: 'https://example.com',
        rules: const SourceRuleSet(
          searchRule: '/search?key={{key}}',
          searchListRule: '.item@html',
          searchTitleRule: '.name@text',
          searchDetailUrlRule: '.name@href',
        ),
      );

      final warnings = validator.collectCompatibilityWarnings(source);

      expect(warnings, hasLength(2));
      expect(warnings.first, contains('目录规则不完整'));
      expect(warnings.last, contains('缺少正文规则'));
    });

    test(
      'collects baseUrl warning when only absolute search url is available',
      () {
        final source = SourceDefinition(
          id: 'id-5',
          name: '绝对搜索源',
          baseUrl: 'not-a-url',
          rules: const SourceRuleSet(
            searchRule: 'https://example.com/search?key={{key}}',
            searchListRule: '.item@html',
            searchTitleRule: '.name@text',
            searchDetailUrlRule: '.name@href',
          ),
        );

        final warnings = validator.collectCompatibilityWarnings(source);

        expect(warnings.any((item) => item.contains('baseUrl 非法')), isTrue);
      },
    );
  });
}

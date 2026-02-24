import 'package:flutter_appread/core/errors/app_exception.dart';
import 'package:flutter_appread/core/rule_engine/processors/url_template_resolver.dart';
import 'package:flutter_appread/domain/entities/search_request_context.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UrlTemplateResolver', () {
    const resolver = UrlTemplateResolver();

    test('replaces key/page and encodes keyword by default', () {
      final context = SearchRequestContext(keyword: '凡人 修仙', page: 2);

      final resolved = resolver.resolve(
        template: 'https://example.com/search?wd={{key}}&page={{page}}',
        context: context,
      );

      expect(
        resolved,
        'https://example.com/search?wd=%E5%87%A1%E4%BA%BA+%E4%BF%AE%E4%BB%99&page=2',
      );
    });

    test('supports raw and encode modifiers', () {
      final context = SearchRequestContext(keyword: '凡人 修仙');

      final resolved = resolver.resolve(
        template: 'https://example.com?q={{key|raw}}&encoded={{key|encode}}',
        context: context,
      );

      expect(
        resolved,
        'https://example.com?q=凡人 修仙&encoded=%E5%87%A1%E4%BA%BA+%E4%BF%AE%E4%BB%99',
      );
    });

    test('supports disabling default keyword encoding', () {
      final context = SearchRequestContext(keyword: '凡人 修仙');

      final resolved = resolver.resolve(
        template: 'https://example.com?q={{key}}&next={{page+1}}',
        context: context.copyWith(page: 2),
        encodeKeywordByDefault: false,
      );

      expect(resolved, 'https://example.com?q=凡人 修仙&next=3');
    });

    test('resolves relative path against baseUrl', () {
      final context = SearchRequestContext(keyword: 'abc');

      final resolved = resolver.resolve(
        template: '/api/search?kw={{keyword}}',
        context: context,
        baseUrl: 'https://example.com/book/',
      );

      expect(resolved, 'https://example.com/api/search?kw=abc');
    });

    test('keeps html-like fragments unchanged when baseUrl resolve fails', () {
      final context = SearchRequestContext(keyword: 'abc');

      final resolved = resolver.resolve(
        template: '<div class="content" id="chaptercontent">',
        context: context,
        baseUrl: 'https://example.com',
      );

      expect(resolved, '<div class="content" id="chaptercontent">');
    });

    test('supports arithmetic offset placeholders', () {
      final context = SearchRequestContext(keyword: '凡人 修仙', page: 3);

      final resolved = resolver.resolve(
        template:
            'https://example.com/search?keyword={{key}}&start={{page-1}}&next={{page + 2}}',
        context: context,
      );

      expect(
        resolved,
        'https://example.com/search?keyword=%E5%87%A1%E4%BA%BA+%E4%BF%AE%E4%BB%99&start=2&next=5',
      );
    });

    test('throws when arithmetic placeholder uses non-number variable', () {
      final context = SearchRequestContext(keyword: 'abc');

      expect(
        () => resolver.resolve(
          template: 'https://example.com?q={{keyword-1}}',
          context: context,
        ),
        throwsA(isA<AppException>()),
      );
    });

    test('falls back to empty string when variable is missing', () {
      final context = SearchRequestContext(keyword: 'abc');

      final resolved = resolver.resolve(
        template: 'https://example.com?q={{missing}}&kw={{keyword}}',
        context: context,
      );

      expect(resolved, 'https://example.com?q=&kw=abc');
    });

    test('throws when modifier is unsupported', () {
      final context = SearchRequestContext(keyword: 'abc');

      expect(
        () => resolver.resolve(
          template: 'https://example.com?q={{key|hex}}',
          context: context,
        ),
        throwsA(isA<AppException>()),
      );
    });
  });
}

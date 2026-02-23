import 'package:flutter_appread/domain/entities/source_definition.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SourceDefinition', () {
    test('uses defaults for optional fields', () {
      final source = SourceDefinition(
        id: 'source-1',
        name: 'Source A',
        baseUrl: 'https://example.com',
      );

      expect(source.enabled, isTrue);
      expect(source.sourceType, 0);
      expect(source.isMangaSource, isFalse);
      expect(source.requiresServerTokenAuth, isFalse);
      expect(source.group, isNull);
      expect(source.headers, isEmpty);
      expect(source.lastCheckStatus, SourceHealthStatus.unknown);
      expect(source.rules.searchRule, isNull);
      expect(source.rules.tocReversed, isFalse);
      expect(source.lastCheckMessage, isNull);
      expect(source.originalSource, isNull);
    });

    test('supports toJson and fromJson roundtrip', () {
      final source = SourceDefinition(
        id: 'source-1',
        name: 'Source A',
        baseUrl: 'https://example.com',
        group: 'group-a',
        enabled: false,
        sourceType: 2,
        rules: const SourceRuleSet(
          searchRule: '.book-list',
          searchInitRule: '/search/init',
          detailRule: '.book-detail',
          detailInitRule: '/detail/init',
          detailIntroRule: '.intro@text',
          tocRule: '.toc-item',
          tocInitRule: '/toc/init',
          tocListRule: '.chapter-item@html',
          tocTitleRule: '.chapter-title@text',
          tocChapterUrlRule: '.chapter-title@href',
          tocReversed: true,
          contentRule: '#content',
          contentInitRule: '/content/init',
        ),
        headers: const {'User-Agent': 'AppRead'},
        lastCheckStatus: SourceHealthStatus.healthy,
        lastCheckedAt: DateTime.parse('2026-01-01T12:00:00.000Z'),
        lastCheckMessage: '连通性测试通过',
        comment: 'sample',
        originalSource: const {
          'bookSourceName': 'Legacy Source A',
          'searchUrl': '/search?key={{key}}',
          'ruleSearch': {'name': 'a@text'},
        },
      );

      final restored = SourceDefinition.fromJson(source.toJson());

      expect(restored.id, source.id);
      expect(restored.name, source.name);
      expect(restored.baseUrl, source.baseUrl);
      expect(restored.group, source.group);
      expect(restored.enabled, isFalse);
      expect(restored.sourceType, 2);
      expect(restored.isMangaSource, isTrue);
      expect(restored.rules.contentRule, '#content');
      expect(restored.rules.contentInitRule, '/content/init');
      expect(restored.rules.searchInitRule, '/search/init');
      expect(restored.rules.detailInitRule, '/detail/init');
      expect(restored.rules.tocInitRule, '/toc/init');
      expect(restored.rules.detailIntroRule, '.intro@text');
      expect(restored.rules.tocChapterUrlRule, '.chapter-title@href');
      expect(restored.rules.tocReversed, isTrue);
      expect(restored.headers['User-Agent'], 'AppRead');
      expect(restored.lastCheckStatus, SourceHealthStatus.healthy);
      expect(
        restored.lastCheckedAt?.toUtc().toIso8601String(),
        '2026-01-01T12:00:00.000Z',
      );
      expect(restored.lastCheckMessage, '连通性测试通过');
      expect(restored.comment, 'sample');
      expect(restored.originalSource?['bookSourceName'], 'Legacy Source A');
      expect(restored.originalSource?['searchUrl'], '/search?key={{key}}');
    });

    test('detects server token auth placeholder from headers', () {
      final source = SourceDefinition(
        id: 'source-1',
        name: 'Server Source',
        baseUrl: 'https://example.com',
        headers: const {'x-sec-token': '{{sourceToken}}'},
      );

      expect(source.requiresServerTokenAuth, isTrue);
    });

    test('copyWith can clear nullable fields', () {
      final source = SourceDefinition(
        id: 'source-1',
        name: 'Source A',
        baseUrl: 'https://example.com',
        lastCheckedAt: DateTime.parse('2026-01-01T12:00:00.000Z'),
        lastCheckMessage: '上次失败：超时',
        comment: 'keep',
      );

      final updated = source.copyWith(
        name: 'Source B',
        clearLastCheckedAt: true,
        clearLastCheckMessage: true,
        clearComment: true,
      );

      expect(updated.name, 'Source B');
      expect(updated.lastCheckedAt, isNull);
      expect(updated.lastCheckMessage, isNull);
      expect(updated.comment, isNull);
      expect(updated.baseUrl, source.baseUrl);
    });

    test('headers are immutable and isolated from source map', () {
      final headers = {'User-Agent': 'A'};
      final source = SourceDefinition(
        id: 'source-1',
        name: 'Source A',
        baseUrl: 'https://example.com',
        headers: headers,
      );

      headers['User-Agent'] = 'B';

      expect(source.headers['User-Agent'], 'A');
      expect(() => source.headers['New'] = 'X', throwsUnsupportedError);
    });

    test(
      'original source snapshot is immutable and supports clear via copyWith',
      () {
        final original = <String, dynamic>{
          'bookSourceName': '旧源',
          'ruleSearch': {'name': 'a@text'},
        };

        final source = SourceDefinition(
          id: 'source-1',
          name: 'Source A',
          baseUrl: 'https://example.com',
          originalSource: original,
        );

        original['bookSourceName'] = '被修改';

        expect(source.originalSource?['bookSourceName'], '旧源');
        expect(() => source.originalSource?['new'] = 1, throwsUnsupportedError);

        final cleared = source.copyWith(clearOriginalSource: true);
        expect(cleared.originalSource, isNull);
      },
    );
  });
}

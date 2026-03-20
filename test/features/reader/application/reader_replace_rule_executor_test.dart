import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_appread/domain/entities/reader_replace_rule.dart';
import 'package:flutter_appread/features/reader/application/reader_replace_rule_executor.dart';

void main() {
  group('ReaderReplaceRule', () {
    test('matches content rules by book title scope', () {
      final rule = ReaderReplaceRule(
        name: '去广告',
        pattern: '广告',
        scopeMode: ReaderReplaceRuleScopeMode.bookTitle,
        scope: '三体',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

      expect(
        rule.matchesForContent(bookTitle: '三体Ⅱ：黑暗森林', sourceId: 'src-1'),
        isTrue,
      );
      expect(
        rule.matchesForContent(bookTitle: '银河帝国', sourceId: 'src-1'),
        isFalse,
      );
    });

    test('exclude scope wins over include scope', () {
      final rule = ReaderReplaceRule(
        name: '测试',
        pattern: '广告',
        scopeMode: ReaderReplaceRuleScopeMode.mixed,
        scope: '起点',
        excludeScope: '特殊版',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

      expect(
        rule.matchesForContent(bookTitle: '特殊版', sourceId: 'qidian-source'),
        isFalse,
      );
    });
  });

  group('ReaderReplaceRuleExecutor', () {
    final executor = ReaderReplaceRuleExecutor();

    test('applies string replace rule and records effective rules', () async {
      final rule = ReaderReplaceRule(
        name: '去广告',
        pattern: '广告',
        replacement: '',
        isRegex: false,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

      final result = await executor.execute(
        content: '正文 广告 内容',
        rules: [rule],
        bookTitle: '测试书',
        sourceId: 'src-1',
      );

      expect(result.content, '正文  内容');
      expect(result.effectiveRules.map((item) => item.name), ['去广告']);
    });

    test('supports regex replacement groups', () async {
      final rule = ReaderReplaceRule(
        name: '章节修正',
        pattern: r'第(\d+)章',
        replacement: r'第$1节',
        isRegex: true,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

      final result = await executor.execute(
        content: '第12章 正文',
        rules: [rule],
        bookTitle: '测试书',
        sourceId: 'src-1',
      );

      expect(result.content, '第12节 正文');
      expect(result.effectiveRules, hasLength(1));
    });
  });
}

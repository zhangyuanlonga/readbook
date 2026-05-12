import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuxiang_reading_next/features/reader/application/local/txt_chapter_rule_service.dart';

void main() {
  group('TxtChapterRuleService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('persists rules and merges enabled patterns', () async {
      final service = TxtChapterRuleService();
      final rule = TxtChapterRule(
        id: 'rule_1',
        name: '自定义章节',
        pattern: r'^自定义第\d+章.*$',
        enabled: true,
        example: '自定义第1章 开头',
      );

      await service.upsertRule(rule);

      final stored = await service.loadRules();
      expect(stored.any((item) => item.id == 'rule_1'), isTrue);
      expect(stored.firstWhere((item) => item.id == 'rule_1').name, '自定义章节');

      final enabledPatterns = await service.loadEnabledPatterns();
      expect(
        enabledPatterns.any((pattern) => pattern.pattern == rule.pattern),
        isTrue,
      );
    });

    test('deleteRule removes stored item', () async {
      final service = TxtChapterRuleService();
      await service.saveRules([
        const TxtChapterRule(
          id: 'rule_1',
          name: '规则一',
          pattern: r'^规则一$',
          enabled: true,
        ),
        const TxtChapterRule(
          id: 'rule_2',
          name: '规则二',
          pattern: r'^规则二$',
          enabled: false,
        ),
      ]);

      await service.deleteRule('rule_1');

      final stored = await service.loadRules();
      expect(stored, hasLength(1));
      expect(stored.first.id, 'rule_2');
    });
  });
}

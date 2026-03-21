import 'package:flutter_appread/features/reader/application/local/txt_toc_rule_settings_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('TxtTocRuleSettingsService', () {
    late TxtTocRuleSettingsService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      service = TxtTocRuleSettingsService();
    });

    test('loads default rules on first launch', () async {
      final rules = await service.loadRules();

      expect(rules, isNotEmpty);
      expect(rules.first.name, isNotEmpty);
    });

    test('supports add, update and delete', () async {
      final initial = await service.loadRules();
      final nextRule = TxtTocRuleState(
        id: 'custom_1',
        name: '测试规则',
        pattern: r'^第\d+章.*$',
        example: '第1章 开始',
        serialNumber: initial.length,
        enabled: true,
      );

      await service.saveRule(nextRule);
      var rules = await service.loadRules();
      expect(rules.any((item) => item.id == 'custom_1'), isTrue);

      await service.saveRule(nextRule.copyWith(name: '测试规则2', enabled: false));
      rules = await service.loadRules();
      final updated = rules.firstWhere((item) => item.id == 'custom_1');
      expect(updated.name, '测试规则2');
      expect(updated.enabled, isFalse);

      await service.deleteRule('custom_1');
      rules = await service.loadRules();
      expect(rules.any((item) => item.id == 'custom_1'), isFalse);
    });

    test('imports and exports json rules', () async {
      final count = await service.importRulesFromJson('''
[
  {
    "name": "导入规则",
    "pattern": "^第\\\\d+章.*\$",
    "example": "第1章 开始",
    "enabled": true
  }
]
''');

      expect(count, 1);

      final rules = await service.loadRules();
      expect(rules.any((item) => item.name == '导入规则'), isTrue);

      final exported = await service.exportRulesToJson();
      expect(exported, contains('导入规则'));
    });

    test('resetRules restores defaults and preserves custom rules', () async {
      final initial = await service.loadRules();
      final firstDefault = initial.first;

      await service.saveRule(
        firstDefault.copyWith(
          name: '被修改的默认规则',
          pattern: r'^修改后的默认规则$',
          enabled: !firstDefault.enabled,
        ),
      );
      await service.saveRule(
        TxtTocRuleState(
          id: 'custom_keep_1',
          name: '保留的自定义规则',
          pattern: r'^第\d+章.*$',
          example: '第1章 开始',
          serialNumber: initial.length,
          enabled: true,
        ),
      );

      await service.resetRules();

      final restored = await service.loadRules();
      final restoredDefault = restored.firstWhere(
        (item) => item.id == firstDefault.id,
      );
      expect(restoredDefault.name, firstDefault.name);
      expect(restoredDefault.pattern, firstDefault.pattern);
      expect(restoredDefault.enabled, firstDefault.enabled);
      expect(restored.any((item) => item.id == 'custom_keep_1'), isTrue);
    });

    test('reorderRules persists manual order', () async {
      final initial = await service.loadRules();
      expect(initial.length, greaterThanOrEqualTo(3));

      final reorderedIds = <String>[
        initial[1].id,
        initial[2].id,
        initial[0].id,
        ...initial.skip(3).map((item) => item.id),
      ];

      await service.reorderRules(reorderedIds);

      final reordered = await service.loadRules();
      expect(reordered[0].id, initial[1].id);
      expect(reordered[1].id, initial[2].id);
      expect(reordered[2].id, initial[0].id);
    });
  });
}

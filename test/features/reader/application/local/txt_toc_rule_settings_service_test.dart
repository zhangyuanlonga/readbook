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
  });
}

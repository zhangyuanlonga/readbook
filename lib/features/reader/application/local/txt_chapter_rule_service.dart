import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'txt_auto_chapter_patterns.dart';

class TxtChapterRule {
  const TxtChapterRule({
    required this.id,
    required this.name,
    required this.pattern,
    required this.enabled,
    this.example,
  });

  final String id;
  final String name;
  final String pattern;
  final bool enabled;
  final String? example;

  TxtChapterRule copyWith({
    String? id,
    String? name,
    String? pattern,
    bool? enabled,
    String? example,
    bool clearExample = false,
  }) {
    return TxtChapterRule(
      id: id ?? this.id,
      name: name ?? this.name,
      pattern: pattern ?? this.pattern,
      enabled: enabled ?? this.enabled,
      example: clearExample ? null : (example ?? this.example),
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'name': name,
      'pattern': pattern,
      'enabled': enabled,
      'example': example,
    };
  }

  factory TxtChapterRule.fromJson(Map<String, Object?> json) {
    return TxtChapterRule(
      id: (json['id'] ?? '').toString().trim(),
      name: (json['name'] ?? '').toString().trim(),
      pattern: (json['pattern'] ?? '').toString(),
      enabled: json['enabled'] == true,
      example: _optionalString(json['example']),
    );
  }

  TxtAutoChapterPattern toPattern({required int serialNumber}) {
    return TxtAutoChapterPattern(
      name: name,
      pattern: pattern,
      serialNumber: serialNumber,
      enabled: enabled,
      example: example,
    );
  }

  static String? _optionalString(Object? value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) {
      return null;
    }
    return text;
  }
}

class TxtChapterRuleService {
  TxtChapterRuleService({SharedPreferences? preferences})
    : _preferencesFuture =
          preferences == null
              ? SharedPreferences.getInstance()
              : Future.value(preferences);

  final Future<SharedPreferences> _preferencesFuture;

  static const String _ruleStorageKey = 'reader.local.txt.chapterRules';

  Future<List<TxtChapterRule>> loadRules() async {
    final prefs = await _preferencesFuture;
    final raw = prefs.getString(_ruleStorageKey);
    if (raw == null || raw.trim().isEmpty) {
      return _defaultRules();
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return _defaultRules();
      }
      final rules = <TxtChapterRule>[];
      for (final item in decoded) {
        if (item is! Map) {
          continue;
        }
        final rule = TxtChapterRule.fromJson(<String, Object?>{
          for (final entry in item.entries) entry.key.toString(): entry.value,
        });
        if (rule.id.isEmpty ||
            rule.name.isEmpty ||
            rule.pattern.trim().isEmpty) {
          continue;
        }
        rules.add(rule);
      }
      return rules;
    } catch (_) {
      return _defaultRules();
    }
  }

  Future<void> saveRules(List<TxtChapterRule> rules) async {
    final prefs = await _preferencesFuture;
    final payload = rules.map((rule) => rule.toJson()).toList(growable: false);
    await prefs.setString(_ruleStorageKey, jsonEncode(payload));
  }

  Future<void> upsertRule(TxtChapterRule rule) async {
    final rules = (await loadRules()).toList(growable: true);
    final index = rules.indexWhere((item) => item.id == rule.id);
    if (index >= 0) {
      rules[index] = rule;
    } else {
      rules.add(rule);
    }
    await saveRules(rules);
  }

  Future<void> deleteRule(String ruleId) async {
    final normalized = ruleId.trim();
    if (normalized.isEmpty) {
      return;
    }
    final rules = (await loadRules())
        .where((rule) => rule.id != normalized)
        .toList(growable: false);
    await saveRules(rules);
  }

  Future<List<TxtAutoChapterPattern>> loadEnabledPatterns() async {
    final rules = await loadRules();
    final patterns = <TxtAutoChapterPattern>[];
    for (var index = 0; index < rules.length; index += 1) {
      final rule = rules[index];
      if (!rule.enabled || rule.pattern.trim().isEmpty) {
        continue;
      }
      patterns.add(rule.toPattern(serialNumber: 1000 + index));
    }
    return patterns;
  }

  String buildRuleId() => DateTime.now().microsecondsSinceEpoch.toString();

  List<TxtChapterRule> _defaultRules() {
    return defaultTxtAutoChapterPatterns
        .where((rule) => rule.pattern.trim().isNotEmpty)
        .map(
          (rule) => TxtChapterRule(
            id: 'rule_${rule.serialNumber}',
            name: rule.name,
            pattern: rule.pattern,
            enabled: rule.enabled,
            example: rule.example,
          ),
        )
        .toList(growable: false);
  }
}

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'txt_toc_rules.dart';

class TxtTocRuleState {
  const TxtTocRuleState({
    required this.id,
    required this.name,
    required this.pattern,
    this.example,
    required this.serialNumber,
    required this.enabled,
  });

  final String id;
  final String name;
  final String pattern;
  final String? example;
  final int serialNumber;
  final bool enabled;

  TxtTocRuleState copyWith({
    String? id,
    String? name,
    String? pattern,
    String? example,
    bool clearExample = false,
    int? serialNumber,
    bool? enabled,
  }) {
    return TxtTocRuleState(
      id: id ?? this.id,
      name: name ?? this.name,
      pattern: pattern ?? this.pattern,
      example: clearExample ? null : (example ?? this.example),
      serialNumber: serialNumber ?? this.serialNumber,
      enabled: enabled ?? this.enabled,
    );
  }

  TxtTocRuleDefinition toDefinition() {
    return TxtTocRuleDefinition(
      name: name,
      pattern: pattern,
      example: example,
      serialNumber: serialNumber,
      enabled: enabled,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'pattern': pattern,
      'example': example,
      'serialNumber': serialNumber,
      'enabled': enabled,
    };
  }

  factory TxtTocRuleState.fromJson(Map<String, dynamic> json) {
    return TxtTocRuleState(
      id:
          (json['id']?.toString().trim().isNotEmpty ?? false)
              ? json['id'].toString().trim()
              : 'rule_${DateTime.now().microsecondsSinceEpoch}',
      name: json['name']?.toString().trim() ?? '',
      pattern: json['pattern']?.toString().trim() ?? '',
      example: _optionalString(json['example']),
      serialNumber: _optionalInt(json['serialNumber']) ?? 0,
      enabled: _optionalBool(json['enabled']) ?? true,
    );
  }

  static String? _optionalString(Object? value) {
    if (value == null) {
      return null;
    }
    final normalized = value.toString().trim();
    return normalized.isEmpty ? null : normalized;
  }

  static int? _optionalInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value.trim());
    }
    return null;
  }

  static bool? _optionalBool(Object? value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1') {
        return true;
      }
      if (normalized == 'false' || normalized == '0') {
        return false;
      }
    }
    return null;
  }
}

class TxtBookTocRuleSelection {
  const TxtBookTocRuleSelection({
    required this.ruleName,
    required this.pattern,
  });

  final String ruleName;
  final String pattern;
}

class TxtTocRuleSettingsService {
  TxtTocRuleSettingsService({SharedPreferences? preferences})
    : _preferencesFuture =
          preferences == null
              ? SharedPreferences.getInstance()
              : Future.value(preferences);

  final Future<SharedPreferences> _preferencesFuture;

  static const String _rulesKey = 'reader.local.txtToc.rules';
  static const String _legacyEnabledOverridesKey =
      'reader.local.txtToc.enabled';

  Future<List<TxtTocRuleState>> loadRules() async {
    final prefs = await _preferencesFuture;
    final raw = prefs.getString(_rulesKey);
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          return _normalizeRuleList(
            decoded
                .whereType<Map>()
                .map(
                  (item) => TxtTocRuleState.fromJson(
                    item.map((key, value) => MapEntry(key.toString(), value)),
                  ),
                )
                .toList(growable: false),
          );
        }
      } catch (_) {
        // Fall through to default migration below.
      }
    }

    final migrated = _buildInitialRules(prefs);
    await _saveRules(prefs, migrated);
    await prefs.remove(_legacyEnabledOverridesKey);
    return migrated;
  }

  Future<List<TxtTocRuleDefinition>> loadEnabledRules() async {
    final rules = await loadRules();
    return rules
        .where((rule) => rule.enabled && rule.pattern.trim().isNotEmpty)
        .map((rule) => rule.toDefinition())
        .toList(growable: false);
  }

  Future<void> setRuleEnabled({
    required String ruleId,
    required bool enabled,
  }) async {
    final rules = await loadRules();
    final updated = rules
        .map(
          (rule) => rule.id == ruleId ? rule.copyWith(enabled: enabled) : rule,
        )
        .toList(growable: false);
    await saveRules(updated);
  }

  Future<void> saveRule(TxtTocRuleState rule) async {
    final rules = await loadRules();
    final normalizedName = rule.name.trim();
    final normalizedPattern = rule.pattern.trim();
    if (normalizedName.isEmpty || normalizedPattern.isEmpty) {
      return;
    }

    final existingIndex = rules.indexWhere((item) => item.id == rule.id);
    final nextRule = rule.copyWith(
      name: normalizedName,
      pattern: normalizedPattern,
      serialNumber:
          existingIndex >= 0 ? rules[existingIndex].serialNumber : rules.length,
    );

    final updated = List<TxtTocRuleState>.from(rules);
    if (existingIndex >= 0) {
      updated[existingIndex] = nextRule;
    } else {
      updated.add(nextRule);
    }
    await saveRules(updated);
  }

  Future<void> deleteRule(String ruleId) async {
    final rules = await loadRules();
    final updated = rules
        .where((rule) => rule.id != ruleId)
        .toList(growable: false);
    await saveRules(updated);
  }

  Future<void> saveRules(List<TxtTocRuleState> rules) async {
    final prefs = await _preferencesFuture;
    await _saveRules(prefs, _normalizeRuleList(rules));
  }

  Future<void> resetRules() async {
    final prefs = await _preferencesFuture;
    await prefs.remove(_rulesKey);
    await prefs.remove(_legacyEnabledOverridesKey);
  }

  Future<int> importRulesFromJson(
    String jsonText, {
    bool replaceExisting = false,
  }) async {
    final normalized = jsonText.trim();
    if (normalized.isEmpty) {
      return 0;
    }

    final decoded = jsonDecode(normalized);
    final imported = <TxtTocRuleState>[];
    if (decoded is List) {
      for (final item in decoded.whereType<Map>()) {
        imported.add(
          TxtTocRuleState.fromJson(
            item.map((key, value) => MapEntry(key.toString(), value)),
          ),
        );
      }
    } else if (decoded is Map) {
      imported.add(
        TxtTocRuleState.fromJson(
          decoded.map((key, value) => MapEntry(key.toString(), value)),
        ),
      );
    }

    if (imported.isEmpty) {
      return 0;
    }

    final current = replaceExisting ? <TxtTocRuleState>[] : await loadRules();
    final merged = List<TxtTocRuleState>.from(current);

    for (final importedRule in imported) {
      final normalizedImported = importedRule.copyWith(
        id:
            importedRule.id.trim().isEmpty
                ? _buildRuleId()
                : importedRule.id.trim(),
        name: importedRule.name.trim(),
        pattern: importedRule.pattern.trim(),
      );
      if (normalizedImported.name.isEmpty ||
          normalizedImported.pattern.isEmpty) {
        continue;
      }

      final duplicateIndex = merged.indexWhere(
        (item) =>
            item.name.trim().toLowerCase() ==
                normalizedImported.name.trim().toLowerCase() &&
            item.pattern.trim() == normalizedImported.pattern.trim(),
      );
      if (duplicateIndex >= 0) {
        merged[duplicateIndex] = normalizedImported.copyWith(
          id: merged[duplicateIndex].id,
          serialNumber: merged[duplicateIndex].serialNumber,
        );
      } else {
        merged.add(
          normalizedImported.copyWith(
            id: _buildRuleId(),
            serialNumber: merged.length,
          ),
        );
      }
    }

    await saveRules(merged);
    return imported.length;
  }

  Future<String> exportRulesToJson() async {
    final rules = await loadRules();
    return const JsonEncoder.withIndent(
      '  ',
    ).convert(rules.map((rule) => rule.toJson()).toList(growable: false));
  }

  List<TxtTocRuleState> _buildInitialRules(SharedPreferences prefs) {
    final overrides = _readLegacyEnabledOverrides(prefs);
    return _normalizeRuleList(
      defaultTxtTocRules
          .map(
            (rule) => TxtTocRuleState(
              id: 'default_${rule.serialNumber}',
              name: rule.name,
              pattern: rule.pattern,
              example: rule.example,
              serialNumber: rule.serialNumber,
              enabled: overrides[rule.name] ?? rule.enabled,
            ),
          )
          .toList(growable: false),
    );
  }

  List<TxtTocRuleState> _normalizeRuleList(List<TxtTocRuleState> rules) {
    final normalized = <TxtTocRuleState>[];
    final seenIds = <String>{};

    for (final rule in rules) {
      final normalizedName = rule.name.trim();
      final normalizedPattern = rule.pattern.trim();
      if (normalizedName.isEmpty) {
        continue;
      }
      final normalizedId =
          rule.id.trim().isEmpty ? _buildRuleId() : rule.id.trim();
      if (!seenIds.add(normalizedId)) {
        continue;
      }
      normalized.add(
        rule.copyWith(
          id: normalizedId,
          name: normalizedName,
          pattern: normalizedPattern,
        ),
      );
    }

    normalized.sort((a, b) => a.serialNumber.compareTo(b.serialNumber));
    return normalized
        .asMap()
        .entries
        .map((entry) => entry.value.copyWith(serialNumber: entry.key))
        .toList(growable: false);
  }

  Future<void> _saveRules(
    SharedPreferences prefs,
    List<TxtTocRuleState> rules,
  ) async {
    await prefs.setString(
      _rulesKey,
      jsonEncode(rules.map((rule) => rule.toJson()).toList(growable: false)),
    );
  }

  Map<String, bool> _readLegacyEnabledOverrides(SharedPreferences prefs) {
    final raw = prefs.getString(_legacyEnabledOverridesKey);
    if (raw == null || raw.trim().isEmpty) {
      return <String, bool>{};
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return <String, bool>{};
      }
      return decoded.map(
        (key, value) => MapEntry(
          key.toString().trim(),
          value == true || value.toString().trim() == 'true',
        ),
      )..removeWhere((key, _) => key.isEmpty);
    } catch (_) {
      return <String, bool>{};
    }
  }

  String _buildRuleId() => 'rule_${DateTime.now().microsecondsSinceEpoch}';
}

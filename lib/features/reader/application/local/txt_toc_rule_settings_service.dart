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

class TxtTocRuleImportResult {
  const TxtTocRuleImportResult({
    required this.importedCount,
    required this.invalidCount,
    required this.emptyCount,
  });

  final int importedCount;
  final int invalidCount;
  final int emptyCount;
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
    final current = await loadRules();
    final restoredDefaults = _defaultRuleStates();
    final customRules = current
        .where((rule) => !_isDefaultRuleId(rule.id))
        .map(
          (rule) => rule.copyWith(
            id: rule.id.trim(),
            name: rule.name.trim(),
            pattern: rule.pattern.trim(),
          ),
        )
        .where((rule) => rule.name.isNotEmpty)
        .toList(growable: false);

    final merged = <TxtTocRuleState>[
      ...restoredDefaults,
      ...customRules.asMap().entries.map(
        (entry) => entry.value.copyWith(
          serialNumber: restoredDefaults.length + entry.key,
        ),
      ),
    ];

    await _saveRules(prefs, _normalizeRuleList(merged));
    await prefs.remove(_legacyEnabledOverridesKey);
  }

  Future<void> reorderRules(List<String> orderedRuleIds) async {
    final current = await loadRules();
    if (current.length <= 1) {
      return;
    }

    final normalizedIds = orderedRuleIds
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    if (normalizedIds.isEmpty) {
      return;
    }

    final remaining = <String, TxtTocRuleState>{
      for (final rule in current) rule.id: rule,
    };
    final reordered = <TxtTocRuleState>[];
    for (final id in normalizedIds) {
      final rule = remaining.remove(id);
      if (rule != null) {
        reordered.add(rule);
      }
    }

    final trailing = remaining.values.toList(growable: false)
      ..sort((a, b) => a.serialNumber.compareTo(b.serialNumber));
    reordered.addAll(trailing);
    await saveRules(
      reordered
          .asMap()
          .entries
          .map((entry) => entry.value.copyWith(serialNumber: entry.key))
          .toList(growable: false),
    );
  }

  Future<TxtTocRuleImportResult> importRulesFromJson(
    String jsonText, {
    bool replaceExisting = false,
  }) async {
    final normalized = jsonText.trim();
    if (normalized.isEmpty) {
      return const TxtTocRuleImportResult(
        importedCount: 0,
        invalidCount: 0,
        emptyCount: 0,
      );
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
      return const TxtTocRuleImportResult(
        importedCount: 0,
        invalidCount: 0,
        emptyCount: 0,
      );
    }

    final current = replaceExisting ? <TxtTocRuleState>[] : await loadRules();
    final merged = List<TxtTocRuleState>.from(current);
    var importedCount = 0;
    var invalidCount = 0;
    var emptyCount = 0;

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
        emptyCount += 1;
        continue;
      }

      if (!_isValidPattern(normalizedImported.pattern)) {
        invalidCount += 1;
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
        importedCount += 1;
      } else {
        merged.add(
          normalizedImported.copyWith(
            id: _buildRuleId(),
            serialNumber: merged.length,
          ),
        );
        importedCount += 1;
      }
    }

    await saveRules(merged);
    return TxtTocRuleImportResult(
      importedCount: importedCount,
      invalidCount: invalidCount,
      emptyCount: emptyCount,
    );
  }

  Future<int> clearCustomRules() async {
    final current = await loadRules();
    final defaults = current
        .where((rule) => _isDefaultRuleId(rule.id))
        .toList(growable: false);
    final removedCount = current.length - defaults.length;
    await saveRules(defaults);
    return removedCount;
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
      _defaultRuleStates(enabledOverrides: overrides).toList(growable: false),
    );
  }

  List<TxtTocRuleState> _defaultRuleStates({
    Map<String, bool>? enabledOverrides,
  }) {
    return defaultTxtTocRules
        .map(
          (rule) => TxtTocRuleState(
            id: 'default_${rule.serialNumber}',
            name: rule.name,
            pattern: rule.pattern,
            example: rule.example,
            serialNumber: rule.serialNumber,
            enabled: enabledOverrides?[rule.name] ?? rule.enabled,
          ),
        )
        .toList(growable: false);
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

  bool _isValidPattern(String pattern) {
    try {
      RegExp(pattern, multiLine: true, caseSensitive: false);
      return true;
    } catch (_) {
      return false;
    }
  }

  bool _isDefaultRuleId(String ruleId) {
    final normalized = ruleId.trim();
    return normalized.startsWith('default_');
  }
}

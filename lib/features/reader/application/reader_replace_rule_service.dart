import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../data/datasources/local/app_database.dart';
import '../../../domain/entities/reader_replace_preference.dart';
import '../../../domain/entities/reader_replace_rule.dart';
import 'reader_replace_rule_executor.dart';

class ReaderReplaceRuleService {
  ReaderReplaceRuleService({
    AppDatabase? database,
    ReaderReplaceRuleExecutor? executor,
    SharedPreferences? preferences,
  }) : _database = database ?? AppDatabase.instance,
       _executor = executor ?? ReaderReplaceRuleExecutor(),
       _preferencesFuture =
           preferences == null
               ? SharedPreferences.getInstance()
               : Future.value(preferences);

  final AppDatabase _database;
  final ReaderReplaceRuleExecutor _executor;
  final Future<SharedPreferences> _preferencesFuture;

  static const String _enabledByDefaultKey =
      'reader.replace_rules.enabledByDefault';

  Future<List<ReaderReplaceRule>> listAll() {
    return _database.getAllReaderReplaceRules();
  }

  Stream<List<ReaderReplaceRule>> watchAll() {
    return _database.watchAllReaderReplaceRules();
  }

  Future<ReaderReplaceRule?> getById(int id) {
    return _database.getReaderReplaceRuleById(id);
  }

  Future<void> saveRule(ReaderReplaceRule rule) {
    return _database.upsertReaderReplaceRule(rule);
  }

  Future<void> deleteRule(int id) {
    return _database.deleteReaderReplaceRuleById(id);
  }

  Future<bool> loadEnabledByDefault() async {
    final prefs = await _preferencesFuture;
    return prefs.getBool(_enabledByDefaultKey) ?? true;
  }

  Future<void> saveEnabledByDefault(bool enabled) async {
    final prefs = await _preferencesFuture;
    await prefs.setBool(_enabledByDefaultKey, enabled);
  }

  Future<ReaderReplacePreference?> getBookPreference({
    required String bookId,
    required String sourceId,
    required String detailUrl,
  }) {
    return _database.getReaderReplacePreference(
      bookId: bookId,
      sourceId: sourceId,
      detailUrl: detailUrl,
    );
  }

  Future<void> saveBookPreference(ReaderReplacePreference preference) {
    return _database.upsertReaderReplacePreference(preference);
  }

  Future<ReaderReplaceRuleMode> resolveEffectiveMode({
    required String bookId,
    required String sourceId,
    required String detailUrl,
  }) async {
    final preference = await getBookPreference(
      bookId: bookId,
      sourceId: sourceId,
      detailUrl: detailUrl,
    );
    if (preference != null &&
        preference.mode != ReaderReplaceRuleMode.inherit) {
      return preference.mode;
    }
    final enabledByDefault = await loadEnabledByDefault();
    return enabledByDefault
        ? ReaderReplaceRuleMode.enabled
        : ReaderReplaceRuleMode.disabled;
  }

  Future<List<ReaderReplaceRule>> loadEnabledContentRules({
    required String bookTitle,
    required String sourceId,
  }) async {
    final rules = await listAll();
    return rules
        .where(
          (rule) =>
              rule.matchesForContent(
                bookTitle: bookTitle,
                sourceId: sourceId,
              ) &&
              rule.isValid,
        )
        .toList(growable: false);
  }

  Future<List<ReaderReplaceRule>> loadEnabledTitleRules({
    required String bookTitle,
    required String sourceId,
  }) async {
    final rules = await listAll();
    return rules
        .where(
          (rule) =>
              rule.matchesForTitle(bookTitle: bookTitle, sourceId: sourceId) &&
              rule.isValid,
        )
        .toList(growable: false);
  }

  Future<ReaderReplaceExecutionResult> applyContentRules({
    required String content,
    required String bookTitle,
    required String sourceId,
    String? bookId,
    String? detailUrl,
  }) async {
    if (bookId != null &&
        detailUrl != null &&
        bookId.trim().isNotEmpty &&
        detailUrl.trim().isNotEmpty) {
      final mode = await resolveEffectiveMode(
        bookId: bookId,
        sourceId: sourceId,
        detailUrl: detailUrl,
      );
      if (mode == ReaderReplaceRuleMode.disabled) {
        return ReaderReplaceExecutionResult(
          content: content,
          effectiveRules: const <ReaderReplaceRule>[],
        );
      }
    }

    final rules = await loadEnabledContentRules(
      bookTitle: bookTitle,
      sourceId: sourceId,
    );
    return _executor.execute(
      content: content,
      rules: rules,
      bookTitle: bookTitle,
      sourceId: sourceId,
    );
  }

  Future<ReaderReplaceExecutionResult> applyTitleRules({
    required String title,
    required String bookTitle,
    required String sourceId,
    String? bookId,
    String? detailUrl,
  }) async {
    if (bookId != null &&
        detailUrl != null &&
        bookId.trim().isNotEmpty &&
        detailUrl.trim().isNotEmpty) {
      final mode = await resolveEffectiveMode(
        bookId: bookId,
        sourceId: sourceId,
        detailUrl: detailUrl,
      );
      if (mode == ReaderReplaceRuleMode.disabled) {
        return ReaderReplaceExecutionResult(
          content: title,
          effectiveRules: const <ReaderReplaceRule>[],
        );
      }
    }

    final rules = await loadEnabledTitleRules(
      bookTitle: bookTitle,
      sourceId: sourceId,
    );
    return _executor.execute(
      content: title,
      rules: rules,
      bookTitle: bookTitle,
      sourceId: sourceId,
    );
  }

  Future<String> testRule({
    required ReaderReplaceRule rule,
    required String text,
  }) {
    return _executor.test(rule: rule, text: text);
  }

  Future<ReaderReplaceRuleTestResult> testRuleDetailed({
    required ReaderReplaceRule rule,
    required String text,
  }) {
    return _executor.testDetailed(rule: rule, text: text);
  }

  List<ReaderReplaceRule> parseImportPayload(String raw) {
    final decoded = jsonDecode(raw);
    final rules = <ReaderReplaceRule>[];

    void addRule(Map<String, dynamic> item) {
      final rule = ReaderReplaceRule.fromJson(item);
      if (rule.isValid) {
        rules.add(rule);
      }
    }

    if (decoded is List) {
      for (final item in decoded.whereType<Map>()) {
        addRule(item.map((key, value) => MapEntry(key.toString(), value)));
      }
    } else if (decoded is Map) {
      final normalized = decoded.map(
        (key, value) => MapEntry(key.toString(), value),
      );
      final nestedList = normalized['rules'] ?? normalized['replaceRules'];
      if (nestedList is List) {
        for (final item in nestedList.whereType<Map>()) {
          addRule(item.map((key, value) => MapEntry(key.toString(), value)));
        }
      } else {
        addRule(normalized);
      }
    } else {
      throw const FormatException('不支持的规则 JSON 格式');
    }

    return rules;
  }

  String exportPayload(List<ReaderReplaceRule> rules) {
    return jsonEncode(
      rules.map((rule) => rule.toJson()).toList(growable: false),
    );
  }
}

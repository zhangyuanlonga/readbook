import '../../../data/datasources/local/app_database.dart';
import '../../../domain/entities/reader_replace_rule.dart';
import 'reader_replace_rule_executor.dart';

class ReaderReplaceRuleService {
  ReaderReplaceRuleService({
    AppDatabase? database,
    ReaderReplaceRuleExecutor? executor,
  }) : _database = database ?? AppDatabase.instance,
       _executor = executor ?? ReaderReplaceRuleExecutor();

  final AppDatabase _database;
  final ReaderReplaceRuleExecutor _executor;

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

  Future<ReaderReplaceExecutionResult> applyContentRules({
    required String content,
    required String bookTitle,
    required String sourceId,
  }) async {
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

  Future<String> testRule({
    required ReaderReplaceRule rule,
    required String text,
  }) {
    return _executor.test(rule: rule, text: text);
  }
}
